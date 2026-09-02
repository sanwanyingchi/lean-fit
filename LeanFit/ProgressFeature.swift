import SwiftUI
import SwiftData
import Charts

struct ProgressDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.recordedAt) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]
    @Query private var exercises: [Exercise]

    let onStartWorkout: (WorkoutSession) -> Void
    let onShowRecords: () -> Void
    @State private var metric: TrendMetric = .weight
    @State private var range: TrendRange = .fourWeeks
    @State private var strengthExerciseID: String?
    @State private var showBodySheet = false
    @State private var showProfile = false
    @State private var showTrendDetail = false
    @State private var showManualCheckIn = false

    private var completedSessions: [WorkoutSession] { sessions.filter { $0.status == .completed } }
    private var profile: UserProfile? { profiles.first }
    private var selectedExercise: Exercise? {
        if let strengthExerciseID { return exercises.first { $0.stableID == strengthExerciseID } }
        return exercises.filter { !$0.isArchived }.sorted {
            ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
        }.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    trendSection
                    weekSection
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(LeanFitTheme.background)
            .navigationTitle("进展")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 17, weight: .light))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(LeanFitTheme.surface, in: Circle())
                    }
                    .accessibilityLabel("打开个人档案")
                    .accessibilityIdentifier("progress.profile")
                }
            }
        }
        .sheet(isPresented: $showBodySheet) {
            BodyMeasurementSheet(existing: measurements)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showTrendDetail) {
            TrendDetailView(metric: metric, range: range, exercise: selectedExercise)
        }
        .sheet(isPresented: $showManualCheckIn) {
            ManualCheckInSheet(existing: checkIns.filter { $0.source == .manual })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            metric = profile?.lastTrendMetric ?? .weight
            if strengthExerciseID == nil { strengthExerciseID = selectedExercise?.stableID }
        }
        .onChange(of: metric) { _, newValue in
            profile?.lastTrendMetric = newValue
            profile?.updatedAt = .now
            try? modelContext.save()
        }
    }

    private var trendSection: some View {
        VStack(spacing: 14) {
            Picker("趋势指标", selection: $metric) {
                ForEach(TrendMetric.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metricLabel).font(.caption).foregroundStyle(.secondary)
                            Text(metricValue)
                                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        Spacer()
                        if let deltaText {
                            Text(deltaText)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(deltaColor)
                        }
                    }

                    Button { showTrendDetail = true } label: {
                        MiniTrendChart(points: trendPoints, accent: metric == .strength ? LeanFitTheme.plum : LeanFitTheme.coral)
                            .frame(height: 130)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开\(metric.title)趋势详情")

                    if metric == .strength {
                        Picker("选择动作", selection: Binding(
                            get: { strengthExerciseID ?? selectedExercise?.stableID ?? "" },
                            set: { strengthExerciseID = $0 }
                        )) {
                            ForEach(exercises.filter { !$0.isArchived }) { exercise in
                                Text(exercise.name).tag(exercise.stableID)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(LeanFitTheme.coral)
                    }

                    HStack(spacing: 8) {
                        ForEach(TrendRange.allCases) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { range = option }
                            } label: {
                                Text(option.title)
                                    .font(.subheadline)
                                    .foregroundStyle(range == option ? LeanFitTheme.background : .secondary)
                                    .padding(.horizontal, 13)
                                    .frame(height: 38)
                                    .background(range == option ? Color.primary : LeanFitTheme.surfaceMuted, in: Capsule())
                            }
                        }
                    }

                    Button("更新体重与体脂") { showBodySheet = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LeanFitTheme.coral)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityIdentifier("progress.updateBody")
                }
            }
        }
    }

    private var weekSection: some View {
        let dates = CalendarEngine.weekDates()
        let completedDays = CalendarEngine.uniqueTrainingDays(sessions: sessions, checkIns: checkIns)
        let goal = profile?.weeklyGoal ?? 3
        return VStack(spacing: 12) {
            SectionHeader(title: "本周训练", actionTitle: "补记打卡") {
                showManualCheckIn = true
            }
            Card {
                VStack(spacing: 16) {
                    HStack {
                        Text("本周 \(completedDays.count)/\(goal) 次")
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Spacer()
                        Text(completedDays.count >= goal ? "目标达成" : "再完成 \(max(0, goal - completedDays.count)) 次")
                            .font(.subheadline)
                            .foregroundStyle(completedDays.count >= goal ? LeanFitTheme.progress : .secondary)
                    }
                    HStack(spacing: 0) {
                        ForEach(dates, id: \.self) { date in
                            WeekDayView(
                                date: date,
                                isDone: completedDays.contains(DayKey.make(from: date)),
                                isToday: Calendar.current.isDateInToday(date)
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "近期训练", actionTitle: "查看全部", action: onShowRecords)
            if completedSessions.isEmpty {
                Card {
                    EmptyStateView(
                        symbol: "dumbbell.fill",
                        title: "开始你的第一次训练",
                        message: "点击底部加号，选四个动作开始记录。",
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(completedSessions.prefix(2).enumerated()), id: \.element.id) { index, session in
                            RecentWorkoutRow(session: session, history: completedSessions)
                            if index == 0 && completedSessions.prefix(2).count > 1 { Divider().padding(.leading, 48) }
                        }
                    }
                    .padding(-16)
                }
            }
        }
    }

    private var cutoffDate: Date { Calendar.current.date(byAdding: .day, value: -range.dayCount, to: .now) ?? .distantPast }

    private var trendPoints: [TrendPoint] {
        switch metric {
        case .weight:
            return measurements.filter { $0.recordedAt >= cutoffDate }.compactMap { item in
                item.weightKg.map { TrendPoint(date: item.recordedAt, value: $0) }
            }
        case .bodyFat:
            return measurements.filter { $0.recordedAt >= cutoffDate }.compactMap { item in
                item.bodyFatPercent.map { TrendPoint(date: item.recordedAt, value: $0) }
            }
        case .strength:
            guard let stableID = selectedExercise?.stableID else { return [] }
            return ProgressEngine.strengthTrend(stableID: stableID, sessions: sessions, since: cutoffDate)
        }
    }

    private var metricLabel: String {
        switch metric {
        case .weight: "最近体重"
        case .bodyFat: "最近体脂（用户录入）"
        case .strength: selectedExercise.map { "\($0.name)估算力量" } ?? "选择一个动作"
        }
    }

    private var metricValue: String {
        guard let last = trendPoints.last?.value else { return "暂无记录" }
        switch metric {
        case .weight: return "\(last.formattedOneDecimal) kg"
        case .bodyFat: return "\(last.formattedOneDecimal)%"
        case .strength:
            guard let exercise = selectedExercise else { return "暂无记录" }
            return exercise.loadType == .bodyweight ? "\(Int(last)) 次" : "\(last.formattedOneDecimal) kg"
        }
    }

    private var deltaText: String? {
        guard let first = trendPoints.first?.value, let last = trendPoints.last?.value, trendPoints.count > 1 else { return nil }
        let delta = last - first
        return "\(range.title) \(delta >= 0 ? "+" : "")\(delta.formattedOneDecimal)"
    }

    private var deltaColor: Color {
        guard metric == .strength,
              let first = trendPoints.first?.value,
              let last = trendPoints.last?.value,
              last > first else { return .secondary }
        return LeanFitTheme.progress
    }
}

private struct MiniTrendChart: View {
    let points: [TrendPoint]
    let accent: Color

    var body: some View {
        if points.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line").foregroundStyle(.secondary)
                Text("记录数据，开始观察变化").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Chart(points) { point in
                if points.count > 1 {
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value("数值", point.value)
                    )
                    .foregroundStyle(LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("数值", point.value)
                    )
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                PointMark(x: .value("日期", point.date), y: .value("数值", point.value))
                    .foregroundStyle(accent)
                    .symbolSize(points.count == 1 ? 55 : 20)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("共 \(points.count) 条趋势记录")
        }
    }
}

private struct WeekDayView: View {
    let date: Date
    let isDone: Bool
    let isToday: Bool

    private static let weekday = DateFormatter.shortWeekday

    var body: some View {
        VStack(spacing: 8) {
            Text(Self.weekday.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .fill(isDone ? LeanFitTheme.coral : LeanFitTheme.surfaceMuted)
                if isToday {
                    Circle().stroke(LeanFitTheme.coral, lineWidth: 2).padding(-3)
                }
                if isDone {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text(date.formatted(.dateTime.day())).font(.caption.monospacedDigit())
                }
            }
            .frame(width: 34, height: 34)
            if isToday {
                Text("今天").font(.system(size: 9, weight: .semibold)).foregroundStyle(LeanFitTheme.coral)
            } else {
                Text(" ").font(.system(size: 9))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted))，\(isDone ? "已训练" : "未训练")\(isToday ? "，今天" : "")")
    }
}

private struct RecentWorkoutRow: View {
    let session: WorkoutSession
    let history: [WorkoutSession]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.focusBodyParts.first?.symbol ?? "dumbbell.fill")
                .foregroundStyle(LeanFitTheme.coral)
                .frame(width: 36, height: 36)
                .background(LeanFitTheme.coralSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(session.focusBodyParts.map(\.title).joined(separator: " · "))
                    .font(.headline)
                Text(session.sortedEntries.map(\.exerciseNameSnapshot).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text((session.endedAt ?? session.startedAt).formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let feedback = ProgressEngine.bestFeedback(for: session, history: history) {
                    Pill(text: feedback.kind.title)
                } else {
                    Text("\(session.effectiveSetCount) 组").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 76)
    }
}

struct BodyMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let existing: [BodyMeasurement]
    @State private var date = Date.now
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Card {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    Divider().padding(.leading, 0)
                    LabeledContent("体重") {
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    .frame(minHeight: 48)
                    Divider()
                    LabeledContent("体脂（可选）") {
                        TextField("%", text: $bodyFat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    .frame(minHeight: 48)
                }
                Text("数据来源：手动录入。允许只更新其中一项。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                InlineError(message: errorMessage)
                Spacer()
                Button("保存", action: save)
                    .buttonStyle(CoralButtonStyle())
            }
            .padding(20)
            .background(LeanFitTheme.background)
            .navigationTitle("更新身体数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
        }
        .tint(LeanFitTheme.coral)
        .onAppear { loadExistingForSelectedDate() }
        .onChange(of: date) { _, _ in loadExistingForSelectedDate() }
    }

    private func loadExistingForSelectedDate() {
        let key = DayKey.make(from: date)
        let item = existing.first { $0.localDayKey == key }
        weight = item?.weightKg?.formattedOneDecimal ?? ""
        bodyFat = item?.bodyFatPercent?.formattedOneDecimal ?? ""
    }

    private func save() {
        let weightText = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let fatText = bodyFat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard weightText.isEmpty || Double(weightText) != nil else {
            errorMessage = "请输入有效的体重数字"
            return
        }
        guard fatText.isEmpty || Double(fatText) != nil else {
            errorMessage = "请输入有效的体脂数字"
            return
        }
        let parsedWeight = weightText.isEmpty ? nil : Double(weightText)
        let parsedFat = fatText.isEmpty ? nil : Double(fatText)
        do {
            try PersistenceActions.saveBodyMeasurement(
                date: date,
                weightKg: parsedWeight,
                bodyFatPercent: parsedFat,
                existing: existing,
                context: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TrendDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyMeasurement.recordedAt) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    let metric: TrendMetric
    @State var range: TrendRange
    let exercise: Exercise?

    private var points: [TrendPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.dayCount, to: .now) ?? .distantPast
        switch metric {
        case .weight: return measurements.filter { $0.recordedAt >= cutoff }.compactMap { item in
            item.weightKg.map { TrendPoint(date: item.recordedAt, value: $0) }
        }
        case .bodyFat: return measurements.filter { $0.recordedAt >= cutoff }.compactMap { item in item.bodyFatPercent.map { TrendPoint(date: item.recordedAt, value: $0) } }
        case .strength:
            guard let exercise else { return [] }
            return ProgressEngine.strengthTrend(stableID: exercise.stableID, sessions: sessions, since: cutoff)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("时间范围", selection: $range) {
                        ForEach(TrendRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if let last = points.last {
                        Text(valueText(last.value))
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        Text("最近记录 · \(last.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Card {
                        MiniTrendChart(points: points, accent: LeanFitTheme.coral)
                            .frame(height: 250)
                    }
                    if points.isEmpty {
                        EmptyStateView(symbol: "chart.xyaxis.line", title: "还没有趋势", message: "继续记录后，这里会展示变化。", actionTitle: nil, action: nil)
                    } else {
                        Card {
                            LabeledContent("周期最高", value: valueText(points.map(\.value).max() ?? 0))
                            Divider()
                            LabeledContent("周期最低", value: valueText(points.map(\.value).min() ?? 0))
                            Divider()
                            LabeledContent("记录次数", value: "\(points.count) 次")
                        }
                    }
                    Text(metric == .bodyFat ? "体脂为用户录入值，仅用于观察变化。" : metric == .strength ? "估算力量只用于同一动作的个人纵向比较。" : "趋势来自你的手动记录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(LeanFitTheme.background)
            .navigationTitle(metric == .strength ? (exercise?.name ?? "力量趋势") : "\(metric.title)趋势")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .tint(LeanFitTheme.coral)
    }

    private func valueText(_ value: Double) -> String {
        switch metric {
        case .weight: "\(value.formattedOneDecimal) kg"
        case .bodyFat: "\(value.formattedOneDecimal)%"
        case .strength: exercise?.loadType == .bodyweight ? "\(Int(value)) 次" : "\(value.formattedOneDecimal) kg"
        }
    }

}

private extension DateFormatter {
    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEEE"
        return formatter
    }()
}
