import SwiftUI
import SwiftData

@main
struct LeanFitApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            BodyMeasurement.self,
            Exercise.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            CheckIn.self
        ])
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-uiTesting") || arguments.contains("-launchUITesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Lean Fit 无法打开本地数据库：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppContainerView()
        }
        .modelContainer(container)
    }
}

private struct AppContainerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingLaunch: Bool
    private let autoFinishLaunch: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldSkipLaunch = arguments.contains("-uiTesting") || arguments.contains("-skipLaunchAnimation")
        _isShowingLaunch = State(initialValue: !shouldSkipLaunch)
        autoFinishLaunch = !arguments.contains("-launchUITesting")
    }

    var body: some View {
        ZStack {
            RootView()

            if isShowingLaunch {
                LaunchExperienceView(autoFinish: autoFinishLaunch) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                        isShowingLaunch = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.018)))
                .zIndex(1)
            }
        }
    }
}

private struct LaunchExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let autoFinish: Bool
    let onFinish: () -> Void

    @State private var iconOpacity = 0.0
    @State private var iconScale = 0.88
    @State private var pathProgress = 0.0
    @State private var dotOpacity = 0.0
    @State private var dotScale = 0.2
    @State private var textOpacity = 0.0
    @State private var textOffset = 8.0
    @State private var launchTask: Task<Void, Never>?
    @State private var hasFinished = false

    var body: some View {
        Button(action: { finish() }) {
            ZStack {
                LeanFitTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    logo
                    VStack(spacing: 7) {
                        Text("Lean Fit")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("记录每一次，稳步变强")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 22)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                }

                VStack {
                    Spacer()
                    Text("点按跳过")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(textOpacity)
                        .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lean Fit 正在启动，点按跳过")
        .accessibilityIdentifier("launch.experience")
        .onAppear(perform: startAnimation)
        .onDisappear {
            launchTask?.cancel()
            launchTask = nil
        }
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LeanFitTheme.coral)

            GeometryReader { geometry in
                LeanFitLogoShape()
                    .trim(from: 0, to: pathProgress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: geometry.size.width * 88 / 1024,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                Circle()
                    .fill(LeanFitTheme.plum)
                    .frame(
                        width: geometry.size.width * 52 / 1024,
                        height: geometry.size.height * 52 / 1024
                    )
                    .position(
                        x: geometry.size.width * 748 / 1024,
                        y: geometry.size.height * 286 / 1024
                    )
                    .opacity(dotOpacity)
                    .scaleEffect(dotScale)
            }
        }
        .frame(width: 124, height: 124)
        .opacity(iconOpacity)
        .scaleEffect(iconScale)
        .shadow(color: LeanFitTheme.coral.opacity(0.22), radius: 24, y: 12)
    }

    private func startAnimation() {
        launchTask?.cancel()
        launchTask = Task { @MainActor in
            if reduceMotion {
                iconOpacity = 1
                iconScale = 1
                pathProgress = 1
                dotOpacity = 1
                dotScale = 1
                textOpacity = 1
                textOffset = 0
                try? await Task.sleep(for: .milliseconds(620))
                guard !Task.isCancelled else { return }
                if autoFinish { finish() }
                return
            }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.76)) {
                iconOpacity = 1
                iconScale = 1
            }
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.72)) {
                pathProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(580))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) {
                dotOpacity = 1
                dotScale = 1
            }
            withAnimation(.easeOut(duration: 0.38)) {
                textOpacity = 1
                textOffset = 0
            }
            try? await Task.sleep(for: .milliseconds(720))
            guard !Task.isCancelled else { return }
            if autoFinish { finish() }
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        launchTask?.cancel()
        launchTask = nil
        onFinish()
    }
}

private struct LeanFitLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 1024, y: rect.minY + rect.height * y / 1024)
        }

        var path = Path()
        path.move(to: point(304, 286))
        path.addLine(to: point(304, 704))
        path.addLine(to: point(452, 704))
        path.addLine(to: point(570, 586))
        path.addLine(to: point(570, 286))
        path.addLine(to: point(748, 286))
        path.move(to: point(570, 470))
        path.addLine(to: point(696, 470))
        return path
    }
}

private enum RootTab {
    case progress
    case records
}

private struct WorkoutRoute: Identifiable {
    let id: UUID
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    @State private var selectedTab: RootTab = .progress
    @State private var showExercisePicker = false
    @State private var workoutRoute: WorkoutRoute?
    @State private var recoverySession: WorkoutSession?
    @State private var showRecovery = false
    @State private var showOnboarding = false
    @State private var toast: String?
    @State private var bootstrapError: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .progress:
                    ProgressDashboard(
                        onStartWorkout: startWorkout,
                        onShowRecords: { selectedTab = .records }
                    )
                case .records:
                    RecordsTimeline()
                }
            }
            .padding(.bottom, 72)

            RootTabBar(selectedTab: $selectedTab, onPlus: handlePlus)

            if let toast {
                ToastView(message: toast)
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .leanFitPageBackground()
        .task {
            do {
                try SeedData.bootstrapIfNeeded(context: modelContext)
                let storedProfiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
                showOnboarding = storedProfiles.first?.hasSeenOnboarding == false
                if let active = try modelContext.fetch(FetchDescriptor<WorkoutSession>())
                    .filter(\.isActive)
                    .sorted(by: { $0.updatedAt > $1.updatedAt })
                    .first {
                    recoverySession = active
                    showRecovery = true
                }
            } catch {
                bootstrapError = "初始化本地数据失败：\(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExerciseSelectionSheet { session in
                showExercisePicker = false
                startWorkout(session)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .fullScreenCover(item: $workoutRoute) { route in
            WorkoutFlow(sessionID: route.id) {
                workoutRoute = nil
                showToast("训练已保存，本周又前进了一步")
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .alert("发现未完成的训练", isPresented: $showRecovery, presenting: recoverySession) { session in
            Button("放弃", role: .destructive) { abandon(session) }
            Button("继续训练") { startWorkout(session) }
            Button("取消", role: .cancel) {}
        } message: { session in
            Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) 开始，已完成 \(session.effectiveSetCount) 组。")
        }
        .alert("无法准备应用", isPresented: Binding(
            get: { bootstrapError != nil },
            set: { if !$0 { bootstrapError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(bootstrapError ?? "未知错误")
        }
    }

    private func handlePlus() {
        if let active = sessions.first(where: \.isActive) {
            recoverySession = active
            showRecovery = true
        } else {
            showExercisePicker = true
        }
    }

    private func startWorkout(_ session: WorkoutSession) {
        workoutRoute = WorkoutRoute(id: session.id)
    }

    private func abandon(_ session: WorkoutSession) {
        session.status = .abandoned
        session.endedAt = .now
        session.updatedAt = .now
        do {
            try modelContext.save()
            showToast("训练草稿已放弃")
        } catch {
            bootstrapError = "未能放弃草稿：\(error.localizedDescription)"
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

private struct RootTabBar: View {
    @Binding var selectedTab: RootTab
    let onPlus: () -> Void

    var body: some View {
        HStack {
            tabButton(title: "进展", symbol: "chart.xyaxis.line", tab: .progress)
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(LeanFitTheme.coral, in: Circle())
                    .overlay(Circle().stroke(LeanFitTheme.background, lineWidth: 5))
                    .shadow(color: LeanFitTheme.coral.opacity(0.28), radius: 15, y: 8)
            }
            .accessibilityLabel("开始训练")
            .accessibilityIdentifier("root.startWorkout")
            .offset(y: -14)
            Spacer()
            tabButton(title: "记录", symbol: "list.bullet.rectangle.portrait", tab: .records)
        }
        .padding(.horizontal, 36)
        .padding(.top, 8)
        .frame(height: 72)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func tabButton(title: String, symbol: String, tab: RootTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                Text(title).font(.caption2)
            }
            .frame(width: 64, height: 50)
            .foregroundStyle(selectedTab == tab ? LeanFitTheme.coral : Color.secondary)
        }
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
        .accessibilityIdentifier(tab == .progress ? "root.tab.progress" : "root.tab.records")
    }
}

private struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var weeklyGoal = 3
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(LeanFitTheme.coral)
                .frame(width: 110, height: 110)
                .background(LeanFitTheme.coralSoft, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            VStack(spacing: 10) {
                Text("从下一组开始进步").font(.largeTitle.bold())
                Text("记录每组重量和次数。下次训练时，Lean Fit 会把上次表现带回来。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("每周训练目标").font(.headline)
                Picker("每周训练目标", selection: $weeklyGoal) {
                    ForEach(1...7, id: \.self) { Text("\($0) 次").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)

            Spacer()
            Button("开始使用") { finish() }
                .buttonStyle(CoralButtonStyle())
                .padding(.horizontal, 20)
            Button("跳过，使用默认 3 次") {
                weeklyGoal = 3
                finish()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
        }
        .padding(.vertical, 24)
        .leanFitPageBackground()
    }

    private func finish() {
        guard let profile = profiles.first else { return }
        profile.weeklyGoal = weeklyGoal
        profile.hasSeenOnboarding = true
        profile.updatedAt = .now
        try? modelContext.save()
        onDone()
    }
}
