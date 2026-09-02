import Foundation
import SwiftData

struct ExercisePerformance: Equatable {
    let maxWeight: Double
    let repsAtMaxWeight: Int
    let maxReps: Int
    let estimatedStrength: Double?
    let volume: Double
    let minAssistance: Double?
    let repsAtMinAssistance: Int
}

struct ProgressFeedback: Equatable, Identifiable {
    let id = UUID()
    let kind: ProgressKind
    let title: String
    let detail: String
}

struct TrendPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum ProgressEngine {
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double? {
        guard weight > 0, (1...10).contains(reps) else { return nil }
        return weight * (1 + Double(reps) / 30)
    }

    static func performance(for entry: ExerciseEntry) -> ExercisePerformance? {
        let sets = entry.completedSets
        guard !sets.isEmpty, entry.status == .completed else { return nil }
        let maxWeight = sets.map(\.weightKg).max() ?? 0
        let repsAtMax = sets.filter { $0.weightKg == maxWeight }.map(\.reps).max() ?? 0
        let maxReps = sets.map(\.reps).max() ?? 0
        let oneRM = sets.compactMap { estimatedOneRepMax(weight: $0.weightKg, reps: $0.reps) }.max()
        let volume = sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        let positiveAssistance = sets.map(\.weightKg).filter { $0 > 0 }
        let minAssistance = positiveAssistance.min()
        let repsAtMinAssistance = minAssistance.map { minimum in
            sets.filter { $0.weightKg == minimum }.map(\.reps).max() ?? 0
        } ?? 0
        return ExercisePerformance(
            maxWeight: maxWeight,
            repsAtMaxWeight: repsAtMax,
            maxReps: maxReps,
            estimatedStrength: oneRM,
            volume: volume,
            minAssistance: minAssistance,
            repsAtMinAssistance: repsAtMinAssistance
        )
    }

    static func compare(
        current: ExercisePerformance,
        previous: ExercisePerformance,
        loadType: LoadType,
        exerciseName: String
    ) -> ProgressFeedback? {
        switch loadType {
        case .weighted:
            if let currentStrength = current.estimatedStrength,
               let previousStrength = previous.estimatedStrength,
               currentStrength > previousStrength + 0.05 {
                let delta = currentStrength - previousStrength
                return .init(
                    kind: .estimatedStrength,
                    title: "\(exerciseName)估算力量突破",
                    detail: "估算力量比上次提高 \(delta.formattedOneDecimal) kg"
                )
            }
            if current.maxWeight > previous.maxWeight {
                return .init(
                    kind: .weight,
                    title: "\(exerciseName)重量突破",
                    detail: "\(current.maxWeight.formattedWeight) kg × \(current.repsAtMaxWeight)，比上次增加 \((current.maxWeight - previous.maxWeight).formattedWeight) kg"
                )
            }
            if current.maxWeight == previous.maxWeight, current.repsAtMaxWeight > previous.repsAtMaxWeight {
                return .init(
                    kind: .reps,
                    title: "\(exerciseName)次数突破",
                    detail: "同样重量多完成 \(current.repsAtMaxWeight - previous.repsAtMaxWeight) 次"
                )
            }
        case .bodyweight:
            if current.maxWeight > previous.maxWeight {
                return .init(
                    kind: .weight,
                    title: "\(exerciseName)附加重量突破",
                    detail: "附加 \(current.maxWeight.formattedWeight) kg × \(current.repsAtMaxWeight)"
                )
            }
            if current.maxReps > previous.maxReps {
                return .init(
                    kind: .reps,
                    title: "\(exerciseName)次数突破",
                    detail: "单组最高 \(current.maxReps) 次，比上次多 \(current.maxReps - previous.maxReps) 次"
                )
            }
        case .assisted:
            if let currentAssistance = current.minAssistance,
               let previousAssistance = previous.minAssistance,
               currentAssistance < previousAssistance {
                return .init(
                    kind: .weight,
                    title: "\(exerciseName)辅助降低",
                    detail: "辅助重量减少 \((previousAssistance - currentAssistance).formattedWeight) kg"
                )
            }
            if current.minAssistance == previous.minAssistance,
               current.repsAtMinAssistance > previous.repsAtMinAssistance {
                return .init(
                    kind: .reps,
                    title: "\(exerciseName)次数突破",
                    detail: "相同辅助重量多完成 \(current.repsAtMinAssistance - previous.repsAtMinAssistance) 次"
                )
            }
        }

        if current.volume > previous.volume + 0.05 {
            return .init(
                kind: .volume,
                title: "\(exerciseName)训练量突破",
                detail: "本次训练量比上次增加 \((current.volume - previous.volume).formattedWeight) kg"
            )
        }
        return nil
    }

    static func previousEntry(
        stableID: String,
        before session: WorkoutSession?,
        in sessions: [WorkoutSession]
    ) -> ExerciseEntry? {
        sessions
            .filter { candidate in
                candidate.status == .completed && candidate.id != session?.id
            }
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
            .compactMap { workout in
                workout.sortedEntries.first {
                    $0.exerciseStableID == stableID && $0.status == .completed && !$0.completedSets.isEmpty
                }
            }
            .first
    }

    static func bestFeedback(for session: WorkoutSession, history: [WorkoutSession]) -> ProgressFeedback? {
        let ranking: [ProgressKind: Int] = [
            .estimatedStrength: 0,
            .weight: 1,
            .reps: 2,
            .volume: 3,
            .weeklyGoal: 4,
            .completion: 5
        ]
        return session.sortedEntries.compactMap { entry -> ProgressFeedback? in
            guard let current = performance(for: entry),
                  let previousEntry = previousEntry(stableID: entry.exerciseStableID, before: session, in: history),
                  let previous = performance(for: previousEntry) else { return nil }
            return compare(
                current: current,
                previous: previous,
                loadType: entry.loadTypeSnapshot,
                exerciseName: entry.exerciseNameSnapshot
            )
        }
        .sorted { (ranking[$0.kind] ?? 99) < (ranking[$1.kind] ?? 99) }
        .first
    }

    static func strengthTrend(stableID: String, sessions: [WorkoutSession], since startDate: Date) -> [TrendPoint] {
        sessions
            .filter { $0.status == .completed && ($0.endedAt ?? $0.startedAt) >= startDate }
            .compactMap { session -> TrendPoint? in
                guard let entry = session.sortedEntries.first(where: {
                    $0.exerciseStableID == stableID && $0.status == .completed
                }), let performance = performance(for: entry) else { return nil }
                let value: Double
                switch entry.loadTypeSnapshot {
                case .weighted: value = performance.estimatedStrength ?? performance.maxWeight
                case .bodyweight: value = Double(performance.maxReps)
                case .assisted: value = performance.minAssistance ?? 0
                }
                return TrendPoint(date: session.endedAt ?? session.startedAt, value: value)
            }
            .sorted { $0.date < $1.date }
    }
}

enum TargetEngine {
    static func makeTargets(exercise: Exercise, previousEntry: ExerciseEntry?) -> [(weight: Double, reps: Int)] {
        makeTargets(
            loadType: exercise.loadType,
            repMin: exercise.defaultRepMin,
            repMax: exercise.defaultRepMax,
            incrementKg: exercise.defaultIncrementKg,
            previousSets: previousEntry?.completedSets.map { ($0.weightKg, $0.reps) } ?? []
        )
    }

    static func makeTargets(
        loadType: LoadType,
        repMin: Int,
        repMax: Int,
        incrementKg: Double,
        previousSets: [(weight: Double, reps: Int)]
    ) -> [(weight: Double, reps: Int)] {
        guard !previousSets.isEmpty else {
            return (0..<4).map { _ in (0, repMin) }
        }

        let allAtUpperLimit = previousSets.allSatisfy { $0.reps >= repMax }
        if allAtUpperLimit {
            return previousSets.map { set in
                let nextWeight: Double
                switch loadType {
                case .assisted: nextWeight = max(0, set.weight - incrementKg)
                case .weighted, .bodyweight: nextWeight = set.weight + incrementKg
                }
                return (nextWeight, repMin)
            }
        }

        var result = previousSets
        if let index = result.indices.min(by: { result[$0].1 < result[$1].1 }) {
            result[index].1 = min(repMax, result[index].1 + 1)
        }
        return result
    }
}

enum EnergyEngine {
    static func age(on date: Date = .now, birthDate: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }

    static func restingEnergy(
        sex: BiologicalSex,
        weightKg: Double?,
        heightCm: Double?,
        birthDate: Date?,
        on date: Date = .now
    ) -> Double? {
        guard sex != .unspecified,
              let weightKg, (20...400).contains(weightKg),
              let heightCm, (80...250).contains(heightCm),
              let birthDate else { return nil }
        let years = age(on: date, birthDate: birthDate)
        guard years >= 18 else { return nil }
        let adjustment = sex == .male ? 5.0 : -161.0
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(years) + adjustment
    }

    static func totalDailyEnergy(
        sex: BiologicalSex,
        weightKg: Double?,
        heightCm: Double?,
        birthDate: Date?,
        activityLevel: ActivityLevel,
        on date: Date = .now
    ) -> Double? {
        guard let ree = restingEnergy(
            sex: sex,
            weightKg: weightKg,
            heightCm: heightCm,
            birthDate: birthDate,
            on: date
        ) else { return nil }
        return (ree * activityLevel.factor / 10).rounded() * 10
    }
}

enum CalendarEngine {
    static func startOfWeek(containing date: Date, calendar input: Calendar = .current) -> Date {
        var calendar = input
        calendar.firstWeekday = 2
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    static func weekDates(containing date: Date = .now, calendar: Calendar = .current) -> [Date] {
        let start = startOfWeek(containing: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func uniqueTrainingDays(
        sessions: [WorkoutSession],
        checkIns: [CheckIn],
        weekContaining date: Date = .now,
        calendar: Calendar = .current
    ) -> Set<String> {
        let sessionKeys = sessions.filter { $0.status == .completed }.map(\.localDayKey)
        let checkInKeys = checkIns.map(\.localDayKey)
        return uniqueTrainingDays(
            sessionDayKeys: sessionKeys,
            checkInDayKeys: checkInKeys,
            weekContaining: date,
            calendar: calendar
        )
    }

    static func uniqueTrainingDays(
        sessionDayKeys: [String],
        checkInDayKeys: [String],
        weekContaining date: Date = .now,
        calendar: Calendar = .current
    ) -> Set<String> {
        let week = weekDates(containing: date, calendar: calendar)
        let keys = Set(week.map { DayKey.make(from: $0, timeZone: calendar.timeZone) })
        return Set((sessionDayKeys + checkInDayKeys).filter(keys.contains))
    }
}

enum InputValidation {
    static func normalizedExerciseName(_ raw: String) -> String { raw.normalizedExerciseName }

    static func validateExercise(
        name: String,
        existingNames: [String],
        repMin: Int,
        repMax: Int,
        increment: Double
    ) -> String? {
        let normalized = normalizedExerciseName(name)
        if normalized.isEmpty { return "请输入动作名称" }
        if normalized.count > 24 { return "动作名称不能超过 24 个字符" }
        if existingNames.map(\.normalizedExerciseName).contains(normalized) { return "动作库中已有同名动作" }
        if !(1...100).contains(repMin) || !(1...100).contains(repMax) { return "默认次数必须在 1–100 之间" }
        if repMin > repMax { return "最低次数不能高于最高次数" }
        if increment <= 0 || increment > 20 { return "加重档位必须在 0–20 kg 之间" }
        return nil
    }

    static func validWeight(_ value: Double) -> Bool {
        guard (0...500).contains(value) else { return false }
        return abs(value * 10 - (value * 10).rounded()) < 0.0001
    }

    static func validReps(_ value: Int) -> Bool { (1...100).contains(value) }
}

enum PersistenceActions {
    static func saveBodyMeasurement(
        date: Date,
        weightKg: Double?,
        bodyFatPercent: Double?,
        existing: [BodyMeasurement],
        context: ModelContext
    ) throws {
        guard weightKg != nil || bodyFatPercent != nil else {
            throw LeanFitError.validation("请至少填写体重或体脂中的一项")
        }
        if let weightKg, !(20...400).contains(weightKg) {
            throw LeanFitError.validation("体重需在 20–400 kg 之间")
        }
        if let bodyFatPercent, !(1...75).contains(bodyFatPercent) {
            throw LeanFitError.validation("体脂需在 1%–75% 之间")
        }

        let key = DayKey.make(from: date)
        if let measurement = existing.first(where: { $0.localDayKey == key }) {
            measurement.recordedAt = date
            if let weightKg { measurement.weightKg = weightKg }
            if let bodyFatPercent { measurement.bodyFatPercent = bodyFatPercent }
            measurement.updatedAt = .now
        } else {
            context.insert(BodyMeasurement(recordedAt: date, weightKg: weightKg, bodyFatPercent: bodyFatPercent))
        }
        try context.save()
    }
}

enum LeanFitError: LocalizedError {
    case validation(String)
    case persistence(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message), .persistence(let message): message
        }
    }
}

extension Double {
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(format: "%.1f", self)
    }

    var formattedOneDecimal: String { String(format: "%.1f", self) }
}
