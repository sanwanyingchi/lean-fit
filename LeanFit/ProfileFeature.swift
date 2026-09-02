import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.recordedAt, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var hasBirthDate = false
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var biologicalSex: BiologicalSex = .unspecified
    @State private var height = ""
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var weeklyGoal = 3
    @State private var errorMessage: String?
    @State private var showResetConfirmation = false
    @State private var didLoad = false

    private var profile: UserProfile? { profiles.first }
    private var latestWeight: Double? { measurements.first(where: { $0.weightKg != nil })?.weightKg }
    private var parsedHeight: Double? { Double(height.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var restingEnergy: Double? {
        EnergyEngine.restingEnergy(
            sex: biologicalSex,
            weightKg: latestWeight,
            heightCm: parsedHeight,
            birthDate: hasBirthDate ? birthDate : nil
        )
    }
    private var totalEnergy: Double? {
        EnergyEngine.totalDailyEnergy(
            sex: biologicalSex,
            weightKg: latestWeight,
            heightCm: parsedHeight,
            birthDate: hasBirthDate ? birthDate : nil,
            activityLevel: activityLevel
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    energyCard
                    profileCard
                    privacyCard
                    InlineError(message: errorMessage)
                    Button("保存档案", action: save)
                        .buttonStyle(CoralButtonStyle())
                    Button("清除训练与身体数据", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(minHeight: 44)
                }
                .padding(20)
            }
            .background(LeanFitTheme.background)
            .navigationTitle("个人档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: save).fontWeight(.semibold)
                }
            }
        }
        .tint(LeanFitTheme.coral)
        .onAppear(perform: loadProfile)
        .alert("清除所有个人记录？", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive, action: resetPersonalData)
        } message: {
            Text("训练、打卡、体重体脂和自定义动作都会被删除。内置动作库会保留，此操作无法撤销。")
        }
    }

    private var energyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每日总消耗估算").font(.caption).foregroundStyle(.secondary)
                        if let totalEnergy {
                            Text("\(Int(totalEnergy)) kcal")
                                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        } else {
                            Text("完善档案后计算")
                                .font(.title2.weight(.bold))
                        }
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(LeanFitTheme.coral)
                        .frame(width: 52, height: 52)
                        .background(LeanFitTheme.coralSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let restingEnergy {
                    Divider()
                    LabeledContent("静息能量消耗", value: "\(Int(restingEnergy)) kcal")
                        .font(.subheadline)
                } else {
                    Text(missingEnergyFields)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("采用 Mifflin–St Jeor 公式并乘以活动系数，仅用于日常参考，不替代医疗或营养建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profileCard: some View {
        Card {
            VStack(spacing: 0) {
                Toggle("设置出生日期", isOn: $hasBirthDate)
                    .frame(minHeight: 50)
                if hasBirthDate {
                    Divider()
                    DatePicker(
                        "出生日期",
                        selection: $birthDate,
                        in: ...Calendar.current.date(byAdding: .year, value: -18, to: .now)!,
                        displayedComponents: .date
                    )
                    .frame(minHeight: 50)
                }
                Divider()
                Picker("生理性别", selection: $biologicalSex) {
                    ForEach(BiologicalSex.allCases) { Text($0.title).tag($0) }
                }
                .frame(minHeight: 50)
                Divider()
                LabeledContent("身高") {
                    HStack(spacing: 5) {
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 50)
                Divider()
                Picker("日常活动", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases) { Text($0.title).tag($0) }
                }
                .frame(minHeight: 50)
                Divider()
                Picker("每周训练目标", selection: $weeklyGoal) {
                    ForEach(1...7, id: \.self) { Text("\($0) 次").tag($0) }
                }
                .frame(minHeight: 50)
            }
        }
    }

    private var privacyCard: some View {
        Card {
            Label {
                VStack(alignment: .leading, spacing: 5) {
                    Text("数据保存在这台设备上").font(.headline)
                    Text("Lean Fit 当前不需要账号，也不会把训练和身体数据上传到服务器。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.fill").foregroundStyle(LeanFitTheme.progress)
            }
        }
    }

    private var missingEnergyFields: String {
        var fields: [String] = []
        if latestWeight == nil { fields.append("最近体重") }
        if parsedHeight == nil { fields.append("身高") }
        if !hasBirthDate { fields.append("出生日期") }
        if biologicalSex == .unspecified { fields.append("生理性别") }
        return "还需填写：\(fields.joined(separator: "、"))"
    }

    private func loadProfile() {
        guard !didLoad, let profile else { return }
        didLoad = true
        if let storedDate = profile.birthDate {
            hasBirthDate = true
            birthDate = storedDate
        }
        biologicalSex = profile.biologicalSex
        height = profile.heightCm?.formattedOneDecimal ?? ""
        activityLevel = profile.activityLevel
        weeklyGoal = profile.weeklyGoal
    }

    private func save() {
        guard let profile else {
            errorMessage = "档案尚未准备好，请稍后重试"
            return
        }
        if !height.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsedHeight, (80...250).contains(parsedHeight) else {
                errorMessage = "身高需在 80–250 cm 之间"
                return
            }
        }
        profile.birthDate = hasBirthDate ? birthDate : nil
        profile.biologicalSex = biologicalSex
        profile.heightCm = parsedHeight
        profile.activityLevel = activityLevel
        profile.weeklyGoal = weeklyGoal
        profile.updatedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "档案未能保存：\(error.localizedDescription)"
        }
    }

    private func resetPersonalData() {
        do {
            try modelContext.fetch(FetchDescriptor<WorkoutSession>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<CheckIn>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<BodyMeasurement>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<Exercise>()).filter(\.isCustom).forEach(modelContext.delete)
            if let profile {
                profile.birthDate = nil
                profile.biologicalSex = .unspecified
                profile.heightCm = nil
                profile.activityLevel = .moderate
                profile.weeklyGoal = 3
                profile.lastTrendMetric = .weight
                profile.updatedAt = .now
            }
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "数据未能清除：\(error.localizedDescription)"
        }
    }
}
