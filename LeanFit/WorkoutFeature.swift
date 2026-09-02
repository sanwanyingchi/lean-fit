import SwiftUI
import SwiftData
import UIKit

struct ExerciseSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var searchText = ""
    @State private var selectedIDs: [String] = []
    @State private var selectedPart: BodyPart?
    @State private var showCreateExercise = false
    @State private var errorMessage: String?
    let onStart: (WorkoutSession) -> Void

    private var filteredExercises: [Exercise] {
        let visible = exercises.filter { !$0.isArchived && $0.matches(searchText) }
        let filtered = selectedPart.map { part in visible.filter { $0.primaryBodyPart == part } } ?? visible
        return filtered.sorted { lhs, rhs in
            if selectedPart == nil {
                switch (lhs.lastUsedAt, rhs.lastUsedAt) {
                case let (left?, right?) where left != right: return left > right
                case (_?, nil): return true
                case (nil, _?): return false
                default: break
                }
            }
            if lhs.isCustom != rhs.isCustom { return !lhs.isCustom }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                filterStrip
                exerciseList
            }
            .background(LeanFitTheme.background)
            .navigationTitle("选择本次动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(LeanFitTheme.surfaceMuted, in: Circle())
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("关闭动作选择")
                }
            }
            .safeAreaInset(edge: .bottom) { selectionDock }
        }
        .sheet(isPresented: $showCreateExercise) {
            CreateExerciseSheet(prefilledName: searchText, suggestedPart: selectedPart) { stableID in
                if selectedIDs.count < 4, !selectedIDs.contains(stableID) {
                    selectedIDs.append(stableID)
                }
                showCreateExercise = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("无法开始训练", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索动作", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterButton("最近", part: nil)
                filterButton("胸", part: .chest)
                filterButton("背", part: .back)
                filterButton("腿", part: .legs)
                filterButton("肩", part: .shoulders)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func filterButton(_ title: String, part: BodyPart?) -> some View {
        let selected = selectedPart == part
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedPart = part }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? .white : .primary)
                .frame(minWidth: 58)
                .padding(.horizontal, 10)
                .frame(height: 42)
                .background(selected ? LeanFitTheme.coral : LeanFitTheme.surfaceMuted, in: Capsule())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredExercises.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: "没有找到这个动作",
                        message: "你可以创建自己的动作，之后同样会自动关联上次表现。",
                        actionTitle: "新建自定义动作",
                        action: openCustomExercise
                    )
                    .padding(.top, 24)
                } else {
                    ForEach(filteredExercises) { exercise in
                        exerciseRow(exercise)
                        Divider().padding(.leading, 72)
                    }

                    Button(action: openCustomExercise) {
                        HStack(spacing: 5) {
                            Text("找不到动作？").foregroundStyle(.secondary)
                            Text("＋ 新建自定义动作").foregroundStyle(LeanFitTheme.coral)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .accessibilityLabel("找不到动作，新建自定义动作")
                    .accessibilityIdentifier("exercise.createCustom")
                }
            }
            .background(LeanFitTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .accessibilityIdentifier("exercise.list")
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let selected = selectedIDs.contains(exercise.stableID)
        return Button {
            toggle(exercise)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark" : "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(selected ? LeanFitTheme.coral : Color.clear, in: Circle())
                    .overlay(Circle().stroke(selected ? LeanFitTheme.coral : Color.secondary.opacity(0.2), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.body.weight(.semibold))
                        if exercise.isCustom { Pill(text: "自定义", color: LeanFitTheme.plum) }
                    }
                    Text("\(exercise.primaryBodyPart.title) · \(exercise.equipment)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(lastPerformanceText(for: exercise))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(exercise.name)，\(lastPerformanceText(for: exercise))")
        .accessibilityValue(selected ? "已选择" : "未选择")
        .accessibilityIdentifier("exercise.\(exercise.stableID)")
    }

    private var selectionDock: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    selectionSummary
                    startButton
                }
            } else {
                HStack(spacing: 18) {
                    selectionSummary
                    startButton
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("已选 \(selectedIDs.count)/4")
                .font(.headline.monospacedDigit())
                .accessibilityIdentifier("exercise.selectionSummary")
            Text(selectedIDs.count == 4 ? "可以开始训练" : "还需 \(4 - selectedIDs.count) 个动作")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startButton: some View {
        Button("开始训练", action: createSession)
            .buttonStyle(CoralButtonStyle(disabled: selectedIDs.count != 4))
            .disabled(selectedIDs.count != 4)
            .accessibilityIdentifier("exercise.start")
    }

    private func toggle(_ exercise: Exercise) {
        if let index = selectedIDs.firstIndex(of: exercise.stableID) {
            selectedIDs.remove(at: index)
        } else if selectedIDs.count < 4 {
            selectedIDs.append(exercise.stableID)
        } else {
            errorMessage = "已选满 4 个，请先取消一个"
        }
    }

    private func openCustomExercise() {
        guard selectedIDs.count < 4 else {
            errorMessage = "已选满 4 个，请先取消一个"
            return
        }
        showCreateExercise = true
    }

    private func lastPerformanceText(for exercise: Exercise) -> String {
        guard let entry = ProgressEngine.previousEntry(stableID: exercise.stableID, before: nil, in: sessions),
              let best = entry.completedSets.max(by: { lhs, rhs in
                  lhs.weightKg == rhs.weightKg ? lhs.reps < rhs.reps : lhs.weightKg < rhs.weightKg
              }) else { return "首次记录" }
        switch exercise.loadType {
        case .weighted: return "上次 \(best.weightKg.formattedWeight) kg × \(best.reps)"
        case .bodyweight: return best.weightKg > 0 ? "上次 +\(best.weightKg.formattedWeight) kg × \(best.reps)" : "上次自重 × \(best.reps)"
        case .assisted: return "上次辅助 \(best.weightKg.formattedWeight) kg × \(best.reps)"
        }
    }

    private func createSession() {
        guard selectedIDs.count == 4 else { return }
        let selected = selectedIDs.compactMap { id in exercises.first { $0.stableID == id } }
        guard selected.count == 4 else {
            errorMessage = "部分动作已不可用，请重新选择"
            return
        }

        let session = WorkoutSession(status: .inProgress)
        session.entries = selected.enumerated().map { index, exercise in
            let previous = ProgressEngine.previousEntry(stableID: exercise.stableID, before: nil, in: sessions)
            let targets = TargetEngine.makeTargets(exercise: exercise, previousEntry: previous)
            exercise.lastUsedAt = .now
            return ExerciseEntry(
                orderIndex: index,
                exerciseStableID: exercise.stableID,
                exerciseNameSnapshot: exercise.name,
                bodyPartSnapshot: exercise.primaryBodyPart,
                loadTypeSnapshot: exercise.loadType,
                sets: targets.enumerated().map { setIndex, target in
                    SetEntry(orderIndex: setIndex, weightKg: target.weight, reps: target.reps)
                }
            )
        }
        session.focusBodyPartsCSV = Array(Set(selected.map { $0.primaryBodyPart.rawValue })).joined(separator: ",")
        modelContext.insert(session)
        do {
            try modelContext.save()
            onStart(session)
        } catch {
            errorMessage = "训练草稿未能保存：\(error.localizedDescription)"
        }
    }
}

private struct CreateExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]

    @State private var name: String
    @State private var alias = ""
    @State private var bodyPart: BodyPart
    @State private var equipment = "未选择"
    @State private var loadType: LoadType = .weighted
    @State private var repMin = 8
    @State private var repMax = 12
    @State private var increment = 2.5
    @State private var showMore = false
    @State private var errorMessage: String?
    let onCreated: (String) -> Void

    init(prefilledName: String, suggestedPart: BodyPart?, onCreated: @escaping (String) -> Void) {
        _name = State(initialValue: prefilledName)
        _bodyPart = State(initialValue: suggestedPart ?? .chest)
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    fieldLabel("动作名称", required: true)
                    TextField("例如：史密斯机臀推", text: $name)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    fieldLabel("训练部位", required: true)
                    HStack(spacing: 10) {
                        ForEach([BodyPart.chest, .back, .legs, .shoulders]) { part in
                            Button {
                                bodyPart = part
                            } label: {
                                Text(part.title)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundStyle(bodyPart == part ? .white : .primary)
                                    .background(bodyPart == part ? LeanFitTheme.coral : LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }

                    fieldLabel("负重方式", required: true)
                    Picker("负重方式", selection: $loadType) {
                        ForEach(LoadType.allCases) { Text($0.shortTitle).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .tint(LeanFitTheme.coral)

                    fieldLabel("器械", required: false)
                    Picker("器械（选填）", selection: $equipment) {
                        ForEach(["未选择", "杠铃", "哑铃", "固定器械", "绳索", "史密斯机", "徒手", "其他"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(LeanFitTheme.coral)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 14)
                    .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    DisclosureGroup("更多设置", isExpanded: $showMore) {
                        VStack(spacing: 16) {
                            TextField("别名（选填）", text: $alias)
                                .textInputAutocapitalization(.never)
                                .padding(.horizontal, 14)
                                .frame(height: 48)
                                .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Stepper("默认最低次数：\(repMin)", value: $repMin, in: 1...100)
                            Stepper("默认最高次数：\(repMax)", value: $repMax, in: 1...100)
                            Picker("默认加重档位", selection: $increment) {
                                ForEach([0.5, 1, 2.5, 5], id: \.self) { Text("\($0.formattedWeight) kg").tag($0) }
                            }
                        }
                        .padding(.top, 16)
                    }
                    .tint(LeanFitTheme.coral)
                    .padding(16)
                    .background(LeanFitTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("创建后会自动加入本次训练，并关联后续进步记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    InlineError(message: errorMessage)
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .background(LeanFitTheme.background)
            .navigationTitle("新建自定义动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("关闭")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("保存并选择", action: save)
                    .buttonStyle(CoralButtonStyle(disabled: name.normalizedExerciseName.isEmpty))
                    .disabled(name.normalizedExerciseName.isEmpty)
                    .padding(12)
                    .background(.regularMaterial)
            }
        }
    }

    private func fieldLabel(_ title: String, required: Bool) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if required { Text("必填").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func save() {
        if let error = InputValidation.validateExercise(
            name: name,
            existingNames: exercises.map(\.name),
            repMin: repMin,
            repMax: repMax,
            increment: increment
        ) {
            errorMessage = error
            return
        }
        let stableID = "custom-\(UUID().uuidString.lowercased())"
        let exercise = Exercise(
            stableID: stableID,
            name: name.normalizedExerciseName,
            aliases: alias.normalizedExerciseName.isEmpty ? [] : [alias.normalizedExerciseName],
            primaryBodyPart: bodyPart,
            equipment: equipment == "未选择" ? "其他" : equipment,
            loadType: loadType,
            defaultRepMin: repMin,
            defaultRepMax: repMax,
            defaultIncrementKg: increment,
            isCustom: true,
            lastUsedAt: .now
        )
        modelContext.insert(exercise)
        do {
            try modelContext.save()
            onCreated(stableID)
            dismiss()
        } catch {
            errorMessage = "未能保存动作：\(error.localizedDescription)"
        }
    }
}

private enum SetField: String {
    case weight
    case reps
}

private struct SetEditorPayload: Identifiable {
    let id = UUID()
    let setID: UUID
    let field: SetField
}

struct WorkoutFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]

    let sessionID: UUID
    let onFinished: () -> Void
    @State private var currentIndex = 0
    @State private var editorPayload: SetEditorPayload?
    @State private var showOverview = false
    @State private var showFinishConfirmation = false
    @State private var toast: String?
    @State private var errorMessage: String?
    @State private var completionFeedback: ProgressFeedback?
    @State private var showCelebration = false

    private var session: WorkoutSession? { sessions.first { $0.id == sessionID } }
    private var currentEntry: ExerciseEntry? {
        guard let entries = session?.sortedEntries, entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session, let entry = currentEntry {
                    workoutContent(session: session, entry: entry)
                } else {
                    ContentUnavailableView("训练不可用", systemImage: "exclamationmark.triangle", description: Text("这份训练草稿可能已被删除。"))
                }
            }
            .background(LeanFitTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("动作") { showOverview = true }
                }
                ToolbarItem(placement: .principal) {
                    Text("训练中").font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("结束") { requestFinish() }
                }
            }
        }
        .background(LeanFitTheme.background.ignoresSafeArea())
        .tint(LeanFitTheme.coral)
        .sheet(item: $editorPayload) { payload in
            if let set = currentEntry?.sets.first(where: { $0.id == payload.setID }), let entry = currentEntry {
                SetValueEditor(set: set, entry: entry, field: payload.field) { applyFollowing in
                    if applyFollowing { syncFollowing(from: set, field: payload.field, in: entry) }
                    saveDraft(successMessage: "第 \(set.orderIndex + 1) 组已更新")
                }
                .presentationDetents([.height(payload.field == .weight ? 460 : 380)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showOverview) {
            WorkoutOverviewSheet(session: session, currentIndex: $currentIndex)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("还有动作未完成", isPresented: $showFinishConfirmation) {
            Button("继续训练", role: .cancel) {}
            Button("仍然结束", role: .destructive) { finishWorkout() }
        } message: {
            Text("未完成动作会标记为跳过，且不参与力量趋势计算。")
        }
        .alert("未能保存", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .overlay {
            if showCelebration, let session {
                CompletionCelebrationView(
                    feedback: completionFeedback,
                    session: session,
                    weekCount: CalendarEngine.uniqueTrainingDays(sessions: sessions, checkIns: checkIns).count,
                    goal: profiles.first?.weeklyGoal ?? 3,
                    reduceMotion: reduceMotion,
                    onDone: onFinished
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(message: toast).padding(.bottom, 110)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { try? modelContext.save() }
        }
    }

    private func workoutContent(session: WorkoutSession, entry: ExerciseEntry) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ProgressView(value: Double(currentIndex + 1), total: Double(max(session.entries.count, 1)))
                        .tint(LeanFitTheme.coral)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("动作 \(currentIndex + 1)/\(session.entries.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.exerciseNameSnapshot).font(.largeTitle.bold())
                        }
                        Spacer()
                        Text("\(entry.completedSets.count)/\(entry.sets.count) 组")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(LeanFitTheme.surfaceMuted, in: Capsule())
                    }

                    historyAndTarget(entry: entry, session: session)

                    HStack {
                        Text("工作组").font(.title3.weight(.semibold))
                        Spacer()
                        Button("添加一组") { addSet(to: entry) }
                            .font(.subheadline)
                    }

                    VStack(spacing: 0) {
                        setHeader
                        ForEach(entry.sortedSets) { set in
                            setRow(set, entry: entry)
                            if set.id != entry.sortedSets.last?.id { Divider().padding(.leading, 52) }
                        }
                    }
                    .background(LeanFitTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text("点按重量或次数快速修改；已完成的组仍可编辑并重新计算结果。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .padding(.bottom, 120)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(currentIndex == session.entries.count - 1 ? "完成训练" : "完成当前动作") {
                        completeCurrentEntry()
                    }
                    .buttonStyle(CoralButtonStyle())
                    .accessibilityIdentifier("workout.completeEntry")
                    Button("查看其他动作") { showOverview = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(12)
                .background(.regularMaterial)
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private func historyAndTarget(entry: ExerciseEntry, session: WorkoutSession) -> some View {
        let previous = ProgressEngine.previousEntry(stableID: entry.exerciseStableID, before: session, in: sessions)
        return HStack(spacing: 12) {
            contextCard(title: "上次表现", value: performanceSummary(previous), highlighted: false)
            contextCard(title: "本次目标", value: targetSummary(entry), highlighted: true)
        }
    }

    private func contextCard(title: String, value: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(highlighted ? LeanFitTheme.coralSoft : LeanFitTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var setHeader: some View {
        HStack {
            Text("组").frame(width: 34)
            Text("重量 kg").frame(maxWidth: .infinity)
            Text("次数").frame(maxWidth: .infinity)
            Text("完成").frame(width: 48)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 38)
    }

    private func setRow(_ set: SetEntry, entry: ExerciseEntry) -> some View {
        HStack(spacing: 8) {
            Text("\(set.orderIndex + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34)
            Button(weightText(set, type: entry.loadTypeSnapshot)) {
                editorPayload = SetEditorPayload(setID: set.id, field: .weight)
            }
            .font(.title3.weight(.semibold).monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button("\(set.reps)") {
                editorPayload = SetEditorPayload(setID: set.id, field: .reps)
            }
            .font(.title3.weight(.semibold).monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(LeanFitTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button { toggleSet(set) } label: {
                Image(systemName: set.isCompleted ? "checkmark" : "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(set.isCompleted ? LeanFitTheme.progress : Color.clear, in: Circle())
                    .overlay(Circle().stroke(set.isCompleted ? LeanFitTheme.progress : Color.secondary.opacity(0.25), lineWidth: 1.5))
            }
            .frame(width: 48, height: 48)
            .accessibilityLabel("完成第 \(set.orderIndex + 1) 组")
            .accessibilityValue(set.isCompleted ? "已完成" : "未完成")
            if entry.sets.count > 1 {
                Button(role: .destructive) { deleteSet(set, from: entry) } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .frame(width: 24, height: 44)
                .accessibilityLabel("删除第 \(set.orderIndex + 1) 组")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private func performanceSummary(_ entry: ExerciseEntry?) -> String {
        guard let entry, let best = entry.completedSets.max(by: { lhs, rhs in
            lhs.weightKg == rhs.weightKg ? lhs.reps < rhs.reps : lhs.weightKg < rhs.weightKg
        }) else { return "首次训练\n建立基准" }
        return "\(best.weightKg.formattedWeight) kg × \(best.reps)"
    }

    private func targetSummary(_ entry: ExerciseEntry) -> String {
        guard let first = entry.sortedSets.first else { return "添加一组" }
        return "\(first.weightKg.formattedWeight) kg × \(first.reps)"
    }

    private func weightText(_ set: SetEntry, type: LoadType) -> String {
        switch type {
        case .weighted: set.weightKg.formattedWeight
        case .bodyweight: set.weightKg > 0 ? "+\(set.weightKg.formattedWeight)" : "自重"
        case .assisted: "\(set.weightKg.formattedWeight)"
        }
    }

    private func addSet(to entry: ExerciseEntry) {
        let last = entry.sortedSets.last
        entry.sets.append(SetEntry(
            orderIndex: entry.sets.count,
            weightKg: last?.weightKg ?? 0,
            reps: last?.reps ?? 8
        ))
        saveDraft(successMessage: "已添加一组")
    }

    private func deleteSet(_ set: SetEntry, from entry: ExerciseEntry) {
        guard entry.sets.count > 1 else { return }
        entry.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, item) in entry.sortedSets.enumerated() { item.orderIndex = index }
        saveDraft(successMessage: "已删除一组")
    }

    private func toggleSet(_ set: SetEntry) {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? .now : nil
        set.updatedAt = .now
        if set.isCompleted { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        saveDraft(successMessage: set.isCompleted ? "第 \(set.orderIndex + 1) 组完成" : "已取消完成")
    }

    private func syncFollowing(from source: SetEntry, field: SetField, in entry: ExerciseEntry) {
        for set in entry.sets where set.orderIndex > source.orderIndex && !set.isCompleted {
            if field == .weight { set.weightKg = source.weightKg } else { set.reps = source.reps }
            set.updatedAt = .now
        }
    }

    private func completeCurrentEntry() {
        guard let session, let entry = currentEntry else { return }
        guard !entry.completedSets.isEmpty else {
            showToast("请先完成至少一组")
            return
        }
        entry.status = .completed
        saveDraft(successMessage: "动作已完成")
        if currentIndex < session.entries.count - 1 {
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3)) { currentIndex += 1 }
        } else {
            requestFinish()
        }
    }

    private func requestFinish() {
        guard let session else { return }
        if session.entries.contains(where: { $0.status != .completed }) {
            showFinishConfirmation = true
        } else {
            finishWorkout()
        }
    }

    private func finishWorkout() {
        guard let session else { return }
        guard session.status != .completed else { return }
        for entry in session.entries where entry.status != .completed { entry.status = .skipped }
        session.status = .completed
        session.endedAt = .now
        session.localDayKey = DayKey.make(from: .now)
        session.focusBodyPartsCSV = Array(Set(session.entries.map(\.bodyPartSnapshotRaw))).joined(separator: ",")
        session.updatedAt = .now
        do {
            try modelContext.save()
            if !checkIns.contains(where: { $0.workoutID == session.id }) {
                modelContext.insert(CheckIn(
                    occurredAt: session.endedAt ?? .now,
                    source: .workout,
                    workoutID: session.id,
                    bodyPart: session.focusBodyParts.first ?? .other
                ))
                try modelContext.save()
            }
            completionFeedback = ProgressEngine.bestFeedback(for: session, history: sessions)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.35)) { showCelebration = true }
        } catch {
            errorMessage = "训练未能完整保存：\(error.localizedDescription)"
        }
    }

    private func saveDraft(successMessage: String) {
        session?.updatedAt = .now
        do {
            try modelContext.save()
            showToast(successMessage)
        } catch {
            errorMessage = "本次修改未能保存：\(error.localizedDescription)"
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

private struct SetValueEditor: View {
    @Environment(\.dismiss) private var dismiss
    let set: SetEntry
    let entry: ExerciseEntry
    let field: SetField
    let onSave: (Bool) -> Void
    @State private var value: String
    @State private var step = 2.5
    @State private var errorMessage: String?

    init(set: SetEntry, entry: ExerciseEntry, field: SetField, onSave: @escaping (Bool) -> Void) {
        self.set = set
        self.entry = entry
        self.field = field
        self.onSave = onSave
        _value = State(initialValue: field == .weight ? set.weightKg.formattedWeight : String(set.reps))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text("\(entry.exerciseNameSnapshot) · 第 \(set.orderIndex + 1) 组")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    adjustButton(symbol: "minus", direction: -1)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("数值", text: $value)
                            .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                            .multilineTextAlignment(.center)
                            .keyboardType(field == .weight ? .decimalPad : .numberPad)
                            .frame(width: 150)
                        Text(field == .weight ? "kg" : "次")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    adjustButton(symbol: "plus", direction: 1)
                }
                InlineError(message: errorMessage)
                if field == .weight {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("每次加减").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            ForEach([0.5, 1, 2.5], id: \.self) { option in
                                Button("\(option.formattedWeight) kg") { step = option }
                                    .buttonStyle(.bordered)
                                    .tint(step == option ? LeanFitTheme.coral : .secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("同步后续组") { commit(applyFollowing: true) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("保存") { commit(applyFollowing: false) }
                        .buttonStyle(CoralButtonStyle())
                }
            }
            .padding(20)
            .navigationTitle(field == .weight ? "修改重量" : "修改次数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("关闭")
                }
            }
            .background(LeanFitTheme.background)
        }
    }

    private func adjustButton(symbol: String, direction: Double) -> some View {
        Button {
            let current = Double(value) ?? 0
            let delta = field == .weight ? step : 1
            value = field == .weight
                ? max(0, current + direction * delta).formattedWeight
                : String(max(1, Int(current + direction * delta)))
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
                .background(LeanFitTheme.surfaceMuted, in: Circle())
        }
    }

    private func commit(applyFollowing: Bool) {
        switch field {
        case .weight:
            guard let number = Double(value), InputValidation.validWeight(number) else {
                errorMessage = "重量需在 0–500 kg，且最多一位小数"
                return
            }
            set.weightKg = number
        case .reps:
            guard let number = Int(value), InputValidation.validReps(number) else {
                errorMessage = "次数需为 1–100 的整数"
                return
            }
            set.reps = number
        }
        set.updatedAt = .now
        onSave(applyFollowing)
        dismiss()
    }
}

private struct WorkoutOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession?
    @Binding var currentIndex: Int

    var body: some View {
        NavigationStack {
            List {
                ForEach(session?.sortedEntries ?? []) { entry in
                    Button {
                        currentIndex = entry.orderIndex
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: statusSymbol(entry.status))
                                .foregroundStyle(statusColor(entry.status))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.exerciseNameSnapshot).font(.headline)
                                Text("\(entry.completedSets.count)/\(entry.sets.count) 组 · \(statusText(entry.status))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if entry.orderIndex == currentIndex { Pill(text: "当前", color: LeanFitTheme.coral) }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LeanFitTheme.background)
            .navigationTitle("今日训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .tint(LeanFitTheme.coral)
    }

    private func statusText(_ status: EntryStatus) -> String {
        switch status { case .pending: "未完成"; case .completed: "已完成"; case .skipped: "已跳过" }
    }
    private func statusSymbol(_ status: EntryStatus) -> String {
        switch status { case .pending: "circle"; case .completed: "checkmark.circle.fill"; case .skipped: "forward.circle" }
    }
    private func statusColor(_ status: EntryStatus) -> Color {
        switch status { case .pending: .secondary; case .completed: LeanFitTheme.progress; case .skipped: .orange }
    }
}

private struct CompletionCelebrationView: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    let feedback: ProgressFeedback?
    let session: WorkoutSession
    let weekCount: Int
    let goal: Int
    let reduceMotion: Bool
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LeanFitTheme.progress, LeanFitTheme.progress.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            if !reduceMotion {
                CelebrationParticles(active: appeared)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: feedback == nil ? "checkmark" : "trophy.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(.white.opacity(0.16), in: Circle())
                    .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.65))
                VStack(spacing: 10) {
                    Text(feedback?.title ?? "训练完成")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(feedback?.detail ?? "四个动作已记录，继续保持训练节奏")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.82))
                }
                .foregroundStyle(.white)
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本周第 \(weekCount) 次训练完成").font(.headline)
                            Text(weekCount >= goal ? "本周目标已达成" : "距离目标还差 \(max(0, goal - weekCount)) 次")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(weekCount)/\(goal)").font(.title2.bold().monospacedDigit())
                    }
                }
                Spacer()
                Button("完成", action: onDone)
                    .buttonStyle(CoralButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.18) : .spring(response: 0.48, dampingFraction: 0.68)) {
                appeared = true
            }
        }
        .task {
            guard !voiceOverEnabled else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            onDone()
        }
    }
}

private struct CelebrationParticles: View {
    let active: Bool
    private let symbols = ["sparkles", "circle.fill", "diamond.fill", "plus"]

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<18, id: \.self) { index in
                Image(systemName: symbols[index % symbols.count])
                    .font(.system(size: CGFloat(8 + index % 8), weight: .bold))
                    .foregroundStyle(.white.opacity(0.45 + Double(index % 4) * 0.1))
                    .position(
                        x: active ? CGFloat((index * 71) % Int(max(proxy.size.width, 1))) : proxy.size.width / 2,
                        y: active ? CGFloat(60 + (index * 97) % Int(max(proxy.size.height - 120, 1))) : proxy.size.height / 2
                    )
                    .opacity(active ? 1 : 0)
                    .animation(.easeOut(duration: 1.2).delay(Double(index) * 0.025), value: active)
            }
        }
    }
}
