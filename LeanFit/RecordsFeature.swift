import SwiftUI
import SwiftData

private struct WorkoutSnapshot {
    struct SetSnapshot {
        let id: UUID
        let orderIndex: Int
        let weightKg: Double
        let reps: Int
        let isCompleted: Bool
        let completedAt: Date?
        let updatedAt: Date
    }

    struct EntrySnapshot {
        let id: UUID
        let orderIndex: Int
        let stableID: String
        let name: String
        let bodyPart: BodyPart
        let loadType: LoadType
        let status: EntryStatus
        let sets: [SetSnapshot]
    }

    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let status: WorkoutStatus
    let focusBodyPartsCSV: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    let entries: [EntrySnapshot]
    let checkIn: CheckInSnapshot?

    struct CheckInSnapshot {
        let id: UUID
        let occurredAt: Date
        let bodyPart: BodyPart
        let notes: String
    }

    init(session: WorkoutSession, checkIn: CheckIn?) {
        id = session.id
        startedAt = session.startedAt
        endedAt = session.endedAt
        status = session.status
        focusBodyPartsCSV = session.focusBodyPartsCSV
        notes = session.notes
        createdAt = session.createdAt
        updatedAt = session.updatedAt
        entries = session.sortedEntries.map { entry in
            EntrySnapshot(
                id: entry.id,
                orderIndex: entry.orderIndex,
                stableID: entry.exerciseStableID,
                name: entry.exerciseNameSnapshot,
                bodyPart: entry.bodyPartSnapshot,
                loadType: entry.loadTypeSnapshot,
                status: entry.status,
                sets: entry.sortedSets.map {
                    SetSnapshot(
                        id: $0.id,
                        orderIndex: $0.orderIndex,
                        weightKg: $0.weightKg,
                        reps: $0.reps,
                        isCompleted: $0.isCompleted,
                        completedAt: $0.completedAt,
                        updatedAt: $0.updatedAt
                    )
                }
            )
        }
        self.checkIn = checkIn.map {
            CheckInSnapshot(id: $0.id, occurredAt: $0.occurredAt, bodyPart: $0.bodyPart, notes: $0.notes)
        }
    }

    func restore(in context: ModelContext) throws {
        let session = WorkoutSession(id: id, startedAt: startedAt, status: status)
        session.endedAt = endedAt
        session.localDayKey = DayKey.make(from: startedAt)
        session.focusBodyPartsCSV = focusBodyPartsCSV
        session.notes = notes
        session.createdAt = createdAt
        session.updatedAt = updatedAt
        session.entries = entries.map { entry in
            ExerciseEntry(
                id: entry.id,
                orderIndex: entry.orderIndex,
                exerciseStableID: entry.stableID,
                exerciseNameSnapshot: entry.name,
                bodyPartSnapshot: entry.bodyPart,
                loadTypeSnapshot: entry.loadType,
                status: entry.status,
                sets: entry.sets.map {
                    let set = SetEntry(
                        id: $0.id,
                        orderIndex: $0.orderIndex,
                        weightKg: $0.weightKg,
                        reps: $0.reps,
                        isCompleted: $0.isCompleted
                    )
                    set.completedAt = $0.completedAt
                    set.updatedAt = $0.updatedAt
                    return set
                }
            )
        }
        context.insert(session)
        if let checkIn {
            context.insert(CheckIn(
                id: checkIn.id,
                occurredAt: checkIn.occurredAt,
                source: .workout,
                workoutID: session.id,
                bodyPart: checkIn.bodyPart,
                notes: checkIn.notes
            ))
        }
        try context.save()
    }
}

private enum TimelineItem: Identifiable {
    case workout(WorkoutSession)
    case checkIn(CheckIn)

    var id: String {
        switch self {
        case .workout(let session): "workout-\(session.id.uuidString)"
        case .checkIn(let checkIn): "checkin-\(checkIn.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .workout(let session): session.endedAt ?? session.startedAt
        case .checkIn(let checkIn): checkIn.occurredAt
        }
    }
}

struct RecordsTimeline: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \CheckIn.occurredAt, order: .reverse) private var checkIns: [CheckIn]

    @State private var selectedSession: WorkoutSession?
    @State private var showManualCheckIn = false
    @State private var deletedSnapshot: WorkoutSnapshot?
    @State private var toastMessage: String?
    @State private var errorMessage: String?

    private var completedSessions: [WorkoutSession] { sessions.filter { $0.status == .completed } }
    private var manualCheckIns: [CheckIn] { checkIns.filter { $0.source == .manual } }
    private var items: [TimelineItem] {
        (completedSessions.map(TimelineItem.workout) + manualCheckIns.map(TimelineItem.checkIn))
            .sorted { $0.date > $1.date }
    }
    private var monthSections: [(String, [TimelineItem])] {
        let grouped = Dictionary(grouping: items) { item in Self.monthFormatter.string(from: item.date) }
        return grouped.map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.1.first?.date ?? .distantPast) > ($1.1.first?.date ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(
                        symbol: "calendar.badge.plus",
                        title: "还没有记录",
                        message: "完成训练或手动打卡后，会按时间显示在这里。",
                        actionTitle: "手动打卡",
                        action: { showManualCheckIn = true }
                    )
                    .padding(20)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                            ForEach(monthSections, id: \.0) { section in
                                Section {
                                    ZStack(alignment: .leading) {
                                        if section.1.count > 1 {
                                            Rectangle()
                                                .fill(Color.secondary.opacity(0.16))
                                                .frame(width: 1)
                                                .padding(.leading, 34)
                                                .padding(.vertical, 38)
                                        }
                                        VStack(spacing: 0) {
                                            ForEach(Array(section.1.enumerated()), id: \.element.id) { index, item in
                                                timelineRow(item)
                                                if index < section.1.count - 1 { Divider().padding(.leading, 68) }
                                            }
                                        }
                                    }
                                    .background(LeanFitTheme.surface, in: RoundedRectangle(cornerRadius: LeanFitTheme.cardRadius, style: .continuous))
                                    .padding(.horizontal, 20)
                                } header: {
                                    Text(section.0)
                                        .font(.title3.weight(.semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(LeanFitTheme.background.opacity(0.96))
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(LeanFitTheme.background)
            .navigationTitle("记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showManualCheckIn = true } label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 17, weight: .light))
                            .symbolRenderingMode(.monochrome)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("手动打卡")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let toastMessage {
                    HStack(spacing: 14) {
                        Text(toastMessage).font(.subheadline.weight(.semibold))
                        Spacer()
                        if deletedSnapshot != nil {
                            Button("撤销", action: undoDelete).fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(.black.opacity(0.86), in: Capsule())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .tint(LeanFitTheme.coral)
        .sheet(item: $selectedSession) { session in
            WorkoutRecordDetail(session: session, history: completedSessions) {
                deleteWorkout(session)
            }
        }
        .sheet(isPresented: $showManualCheckIn) {
            ManualCheckInSheet(existing: manualCheckIns)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("操作未完成", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    @ViewBuilder
    private func timelineRow(_ item: TimelineItem) -> some View {
        switch item {
        case .workout(let session):
            Button { selectedSession = session } label: {
                HStack(spacing: 14) {
                    timelineMarker(symbol: session.focusBodyParts.first?.symbol ?? "dumbbell.fill", color: LeanFitTheme.coral)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.focusBodyParts.map(\.title).joined(separator: " · "))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(session.sortedEntries.count) 个动作 · \(session.effectiveSetCount) 组 · \(durationText(session.duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(item.date.formatted(.dateTime.day().weekday(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 78)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("records.workout")
        case .checkIn(let checkIn):
            HStack(spacing: 14) {
                timelineMarker(symbol: "checkmark", color: LeanFitTheme.progress)
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(checkIn.bodyPart.title)训练打卡").font(.headline)
                    Text(checkIn.notes.isEmpty ? "手动记录" : checkIn.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(item.date.formatted(.dateTime.day().weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 78)
        }
    }

    private func timelineMarker(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func deleteWorkout(_ session: WorkoutSession) {
        let relatedCheckIn = checkIns.first { $0.workoutID == session.id }
        deletedSnapshot = WorkoutSnapshot(session: session, checkIn: relatedCheckIn)
        if let relatedCheckIn { modelContext.delete(relatedCheckIn) }
        modelContext.delete(session)
        selectedSession = nil
        do {
            try modelContext.save()
            showToast("训练已删除", keepUndo: true)
        } catch {
            deletedSnapshot = nil
            errorMessage = "训练未能删除：\(error.localizedDescription)"
        }
    }

    private func undoDelete() {
        guard let deletedSnapshot else { return }
        do {
            try deletedSnapshot.restore(in: modelContext)
            self.deletedSnapshot = nil
            showToast("已恢复训练", keepUndo: false)
        } catch {
            errorMessage = "训练未能恢复：\(error.localizedDescription)"
        }
    }

    private func showToast(_ message: String, keepUndo: Bool) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: keepUndo ? 5_000_000_000 : 2_000_000_000)
            await MainActor.run {
                withAnimation { toastMessage = nil }
                if keepUndo { deletedSnapshot = nil }
            }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter
    }()
}

struct ManualCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let existing: [CheckIn]
    @State private var date = Date.now
    @State private var bodyPart: BodyPart = .chest
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Card {
                        DatePicker("日期", selection: $date, in: ...Date.now, displayedComponents: .date)
                            .frame(minHeight: 48)
                        Divider()
                        Picker("训练部位", selection: $bodyPart) {
                            ForEach([BodyPart.chest, .back, .legs, .shoulders]) { Text($0.title).tag($0) }
                        }
                        .frame(minHeight: 48)
                        Divider()
                        TextField("备注（可选）", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .frame(minHeight: 64, alignment: .topLeading)
                    }
                    Text("手动打卡只计入训练天数，不会生成重量或力量趋势。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    InlineError(message: errorMessage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button("完成打卡", action: save).buttonStyle(CoralButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
            }
            .background(LeanFitTheme.background)
            .navigationTitle("训练打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
        }
        .tint(LeanFitTheme.coral)
    }

    private func save() {
        let key = DayKey.make(from: date)
        if let item = existing.first(where: { $0.localDayKey == key }) {
            item.occurredAt = date
            item.localDayKey = key
            item.bodyPartRaw = bodyPart.rawValue
            item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            modelContext.insert(CheckIn(
                occurredAt: date,
                source: .manual,
                bodyPart: bodyPart,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "打卡未能保存：\(error.localizedDescription)"
        }
    }
}

private struct WorkoutRecordDetail: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let history: [WorkoutSession]
    let onDelete: () -> Void
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard
                    if let feedback = ProgressEngine.bestFeedback(for: session, history: history) {
                        Card {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feedback.title).font(.headline)
                                    Text(feedback.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(LeanFitTheme.progress)
                            }
                        }
                    }
                    ForEach(session.sortedEntries) { entry in
                        exerciseCard(entry)
                    }
                    Button("删除这次训练", role: .destructive) { showDeleteConfirmation = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .padding(20)
            }
            .background(LeanFitTheme.background)
            .navigationTitle("训练详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("编辑") { showEdit = true }.fontWeight(.semibold) }
            }
        }
        .tint(LeanFitTheme.coral)
        .sheet(isPresented: $showEdit) {
            RecordEditSheet(session: session)
        }
        .alert("删除这次训练？", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                dismiss()
                onDelete()
            }
        } message: {
            Text("对应打卡和力量趋势也会更新，删除后可在 5 秒内撤销。")
        }
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.focusBodyParts.map(\.title).joined(separator: " · "))
                    .font(.title2.weight(.bold))
                Text((session.endedAt ?? session.startedAt).formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    Label("\(session.sortedEntries.count) 动作", systemImage: "list.number")
                    Label("\(session.effectiveSetCount) 组", systemImage: "checkmark.circle")
                    Label("\(max(1, Int(session.duration / 60))) 分", systemImage: "clock")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private func exerciseCard(_ entry: ExerciseEntry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: entry.bodyPartSnapshot.symbol).foregroundStyle(LeanFitTheme.coral)
                    Text(entry.exerciseNameSnapshot).font(.headline)
                    Spacer()
                    Text(entry.loadTypeSnapshot.shortTitle).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text("组").frame(width: 30, alignment: .leading)
                    Text(entry.loadTypeSnapshot == .assisted ? "辅助 kg" : "重量 kg").frame(maxWidth: .infinity)
                    Text("次数").frame(width: 60, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(entry.sortedSets.filter(\.isCompleted)) { set in
                    HStack {
                        Text("\(set.orderIndex + 1)").frame(width: 30, alignment: .leading)
                        Text(set.weightKg.formattedWeight).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(set.reps)").frame(width: 60, alignment: .trailing)
                    }
                    .font(.body.monospacedDigit())
                }
            }
        }
    }
}

private struct RecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Card {
                        DatePicker("训练开始", selection: $session.startedAt)
                        if let endedAt = session.endedAt {
                            Divider()
                            DatePicker("训练结束", selection: Binding(
                                get: { endedAt },
                                set: { session.endedAt = $0 }
                            ))
                        }
                    }
                    ForEach(session.sortedEntries) { entry in
                        editCard(entry)
                    }
                    InlineError(message: errorMessage)
                    Button("保存修改", action: save).buttonStyle(CoralButtonStyle())
                }
                .padding(20)
            }
            .background(LeanFitTheme.background)
            .navigationTitle("编辑训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { modelContext.rollback(); dismiss() } } }
        }
        .tint(LeanFitTheme.coral)
    }

    private func editCard(_ entry: ExerciseEntry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.exerciseNameSnapshot).font(.headline)
                ForEach(entry.sortedSets) { set in
                    HStack(spacing: 10) {
                        Button {
                            set.isCompleted.toggle()
                            set.completedAt = set.isCompleted ? (set.completedAt ?? .now) : nil
                        } label: {
                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(set.isCompleted ? LeanFitTheme.progress : .secondary)
                        }
                        .accessibilityLabel("第 \(set.orderIndex + 1) 组\(set.isCompleted ? "已完成" : "未完成")")
                        TextField("重量", value: Binding(
                            get: { set.weightKg },
                            set: { set.weightKg = $0 }
                        ), format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        Text("kg").font(.caption).foregroundStyle(.secondary)
                        TextField("次数", value: Binding(
                            get: { set.reps },
                            set: { set.reps = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                    }
                }
            }
        }
    }

    private func save() {
        let invalidSet = session.entries.flatMap(\.sets).first {
            !InputValidation.validWeight($0.weightKg) || !InputValidation.validReps($0.reps)
        }
        guard invalidSet == nil else {
            errorMessage = "重量需在 0–500 kg，次数需在 1–100 之间"
            return
        }
        session.localDayKey = DayKey.make(from: session.startedAt)
        session.updatedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "修改未能保存：\(error.localizedDescription)"
        }
    }
}
