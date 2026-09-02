import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case male
    case female

    var id: String { rawValue }
    var title: String {
        switch self {
        case .unspecified: "未设置"
        case .male: "男性"
        case .female: "女性"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case veryActive
    case extraActive

    var id: String { rawValue }
    var title: String {
        switch self {
        case .sedentary: "久坐、很少运动"
        case .light: "每周轻度活动 1–3 次"
        case .moderate: "每周中等活动 3–5 次"
        case .veryActive: "每周高强度活动 6–7 次"
        case .extraActive: "高强度训练或高体力工作"
        }
    }

    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }
}

enum BodyPart: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .chest: "胸"
        case .back: "背"
        case .legs: "腿"
        case .shoulders: "肩"
        case .arms: "手臂"
        case .core: "核心"
        case .other: "其他"
        }
    }

    var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .legs: "figure.step.training"
        case .shoulders: "dumbbell.fill"
        case .arms: "figure.arms.open"
        case .core: "figure.core.training"
        case .other: "figure.mixed.cardio"
        }
    }
}

enum LoadType: String, Codable, CaseIterable, Identifiable {
    case weighted
    case bodyweight
    case assisted

    var id: String { rawValue }
    var title: String {
        switch self {
        case .weighted: "普通负重"
        case .bodyweight: "自重动作"
        case .assisted: "辅助动作"
        }
    }

    var shortTitle: String {
        switch self {
        case .weighted: "负重"
        case .bodyweight: "自重"
        case .assisted: "辅助"
        }
    }
}

enum WorkoutStatus: String, Codable, CaseIterable {
    case draft
    case inProgress
    case completed
    case abandoned
}

enum EntryStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case skipped
}

enum CheckInSource: String, Codable, CaseIterable {
    case workout
    case manual
}

enum TrendMetric: String, Codable, CaseIterable, Identifiable {
    case weight
    case bodyFat
    case strength

    var id: String { rawValue }
    var title: String {
        switch self {
        case .weight: "体重"
        case .bodyFat: "体脂"
        case .strength: "力量"
        }
    }
}

enum TrendRange: String, CaseIterable, Identifiable {
    case fourWeeks
    case threeMonths
    case oneYear

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fourWeeks: "4 周"
        case .threeMonths: "3 个月"
        case .oneYear: "1 年"
        }
    }

    var dayCount: Int {
        switch self {
        case .fourWeeks: 28
        case .threeMonths: 92
        case .oneYear: 366
        }
    }
}

enum ProgressKind: String, Codable {
    case estimatedStrength
    case weight
    case reps
    case volume
    case weeklyGoal
    case completion

    var title: String {
        switch self {
        case .estimatedStrength: "估算力量突破"
        case .weight: "重量突破"
        case .reps: "次数突破"
        case .volume: "训练量突破"
        case .weeklyGoal: "本周目标达成"
        case .completion: "训练完成"
        }
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var singletonKey: String
    var id: UUID
    var birthDate: Date?
    var biologicalSexRaw: String
    var heightCm: Double?
    var activityLevelRaw: String
    var weeklyGoal: Int
    var lastTrendMetricRaw: String
    var hasSeenOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        birthDate: Date? = nil,
        biologicalSex: BiologicalSex = .unspecified,
        heightCm: Double? = nil,
        activityLevel: ActivityLevel = .moderate,
        weeklyGoal: Int = 3,
        hasSeenOnboarding: Bool = false
    ) {
        singletonKey = "profile"
        self.id = id
        self.birthDate = birthDate
        biologicalSexRaw = biologicalSex.rawValue
        self.heightCm = heightCm
        activityLevelRaw = activityLevel.rawValue
        self.weeklyGoal = weeklyGoal
        lastTrendMetricRaw = TrendMetric.weight.rawValue
        self.hasSeenOnboarding = hasSeenOnboarding
        createdAt = .now
        updatedAt = .now
    }

    var biologicalSex: BiologicalSex {
        get { BiologicalSex(rawValue: biologicalSexRaw) ?? .unspecified }
        set { biologicalSexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var lastTrendMetric: TrendMetric {
        get { TrendMetric(rawValue: lastTrendMetricRaw) ?? .weight }
        set { lastTrendMetricRaw = newValue.rawValue }
    }
}

@Model
final class BodyMeasurement {
    var id: UUID
    var recordedAt: Date
    @Attribute(.unique) var localDayKey: String
    var weightKg: Double?
    var bodyFatPercent: Double?
    var sourceRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        weightKg: Double?,
        bodyFatPercent: Double?,
        sourceRaw: String = "manual"
    ) {
        self.id = id
        self.recordedAt = recordedAt
        localDayKey = DayKey.make(from: recordedAt)
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.sourceRaw = sourceRaw
        createdAt = .now
        updatedAt = .now
    }
}

@Model
final class Exercise {
    var id: UUID
    @Attribute(.unique) var stableID: String
    var name: String
    var aliasesCSV: String
    var primaryBodyPartRaw: String
    var secondaryBodyPartsCSV: String
    var equipment: String
    var loadTypeRaw: String
    var defaultRepMin: Int
    var defaultRepMax: Int
    var defaultIncrementKg: Double
    var isCustom: Bool
    var isArchived: Bool
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        stableID: String,
        name: String,
        aliases: [String] = [],
        primaryBodyPart: BodyPart,
        secondaryBodyParts: [BodyPart] = [],
        equipment: String,
        loadType: LoadType,
        defaultRepMin: Int = 8,
        defaultRepMax: Int = 12,
        defaultIncrementKg: Double = 2.5,
        isCustom: Bool = false,
        isArchived: Bool = false,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.stableID = stableID
        self.name = name
        aliasesCSV = aliases.joined(separator: ",")
        primaryBodyPartRaw = primaryBodyPart.rawValue
        secondaryBodyPartsCSV = secondaryBodyParts.map(\.rawValue).joined(separator: ",")
        self.equipment = equipment
        loadTypeRaw = loadType.rawValue
        self.defaultRepMin = defaultRepMin
        self.defaultRepMax = defaultRepMax
        self.defaultIncrementKg = defaultIncrementKg
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.lastUsedAt = lastUsedAt
    }

    var aliases: [String] {
        get { aliasesCSV.split(separator: ",").map(String.init) }
        set { aliasesCSV = newValue.joined(separator: ",") }
    }

    var primaryBodyPart: BodyPart {
        get { BodyPart(rawValue: primaryBodyPartRaw) ?? .other }
        set { primaryBodyPartRaw = newValue.rawValue }
    }

    var loadType: LoadType {
        get { LoadType(rawValue: loadTypeRaw) ?? .weighted }
        set { loadTypeRaw = newValue.rawValue }
    }

    func matches(_ query: String) -> Bool {
        let needle = query.normalizedExerciseName
        guard !needle.isEmpty else { return true }
        return ([name] + aliases).contains { $0.normalizedExerciseName.contains(needle) }
    }
}

@Model
final class WorkoutSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var localDayKey: String
    var statusRaw: String
    var focusBodyPartsCSV: String
    var notes: String
    @Relationship(deleteRule: .cascade) var entries: [ExerciseEntry]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        status: WorkoutStatus = .draft,
        entries: [ExerciseEntry] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        endedAt = nil
        localDayKey = DayKey.make(from: startedAt)
        statusRaw = status.rawValue
        focusBodyPartsCSV = ""
        notes = ""
        self.entries = entries
        createdAt = .now
        updatedAt = .now
    }

    var status: WorkoutStatus {
        get { WorkoutStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var sortedEntries: [ExerciseEntry] { entries.sorted { $0.orderIndex < $1.orderIndex } }
    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    var effectiveSetCount: Int { entries.flatMap(\.sets).filter(\.isCompleted).count }
    var isActive: Bool { status == .draft || status == .inProgress }

    var focusBodyParts: [BodyPart] {
        let stored = focusBodyPartsCSV.split(separator: ",").compactMap { BodyPart(rawValue: String($0)) }
        if !stored.isEmpty { return stored }
        var seen = Set<String>()
        return sortedEntries.compactMap { entry in
            guard seen.insert(entry.bodyPartSnapshotRaw).inserted else { return nil }
            return BodyPart(rawValue: entry.bodyPartSnapshotRaw)
        }
    }
}

@Model
final class ExerciseEntry {
    var id: UUID
    var orderIndex: Int
    var exerciseStableID: String
    var exerciseNameSnapshot: String
    var bodyPartSnapshotRaw: String
    var loadTypeSnapshotRaw: String
    var statusRaw: String
    @Relationship(deleteRule: .cascade) var sets: [SetEntry]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        exerciseStableID: String,
        exerciseNameSnapshot: String,
        bodyPartSnapshot: BodyPart,
        loadTypeSnapshot: LoadType,
        status: EntryStatus = .pending,
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.exerciseStableID = exerciseStableID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        bodyPartSnapshotRaw = bodyPartSnapshot.rawValue
        loadTypeSnapshotRaw = loadTypeSnapshot.rawValue
        statusRaw = status.rawValue
        self.sets = sets
    }

    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var bodyPartSnapshot: BodyPart { BodyPart(rawValue: bodyPartSnapshotRaw) ?? .other }
    var loadTypeSnapshot: LoadType { LoadType(rawValue: loadTypeSnapshotRaw) ?? .weighted }
    var sortedSets: [SetEntry] { sets.sorted { $0.orderIndex < $1.orderIndex } }
    var completedSets: [SetEntry] { sortedSets.filter(\.isCompleted) }
}

@Model
final class SetEntry {
    var id: UUID
    var orderIndex: Int
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        weightKg: Double,
        reps: Int,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = isCompleted
        completedAt = isCompleted ? .now : nil
        updatedAt = .now
    }
}

@Model
final class CheckIn {
    var id: UUID
    var occurredAt: Date
    var localDayKey: String
    var sourceRaw: String
    var workoutID: UUID?
    var bodyPartRaw: String
    var notes: String

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        source: CheckInSource,
        workoutID: UUID? = nil,
        bodyPart: BodyPart,
        notes: String = ""
    ) {
        self.id = id
        self.occurredAt = occurredAt
        localDayKey = DayKey.make(from: occurredAt)
        sourceRaw = source.rawValue
        self.workoutID = workoutID
        bodyPartRaw = bodyPart.rawValue
        self.notes = notes
    }

    var source: CheckInSource { CheckInSource(rawValue: sourceRaw) ?? .manual }
    var bodyPart: BodyPart { BodyPart(rawValue: bodyPartRaw) ?? .other }
}

enum DayKey {
    static func make(from date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension String {
    var normalizedExerciseName: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
    }
}

