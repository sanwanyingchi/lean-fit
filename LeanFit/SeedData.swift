import Foundation
import SwiftData

private struct CatalogExercise {
    let stableID: String
    let name: String
    let aliases: [String]
    let part: BodyPart
    let equipment: String
    let loadType: LoadType
    let minReps: Int
    let maxReps: Int
    let increment: Double
}

enum SeedData {
    private static let catalog: [CatalogExercise] = [
        .init(stableID: "chest-barbell-bench-press", name: "杠铃卧推", aliases: ["卧推", "平板卧推"], part: .chest, equipment: "杠铃", loadType: .weighted, minReps: 6, maxReps: 10, increment: 2.5),
        .init(stableID: "chest-incline-dumbbell-press", name: "上斜哑铃卧推", aliases: ["上斜卧推"], part: .chest, equipment: "哑铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 1),
        .init(stableID: "chest-cable-fly", name: "绳索夹胸", aliases: ["龙门架夹胸"], part: .chest, equipment: "绳索", loadType: .weighted, minReps: 10, maxReps: 15, increment: 2.5),
        .init(stableID: "chest-dips", name: "双杠臂屈伸", aliases: ["双杠撑体"], part: .chest, equipment: "徒手", loadType: .bodyweight, minReps: 6, maxReps: 12, increment: 2.5),
        .init(stableID: "chest-push-up", name: "俯卧撑", aliases: ["伏地挺身"], part: .chest, equipment: "徒手", loadType: .bodyweight, minReps: 8, maxReps: 20, increment: 2.5),
        .init(stableID: "chest-machine-press", name: "坐姿推胸", aliases: ["器械推胸"], part: .chest, equipment: "固定器械", loadType: .weighted, minReps: 8, maxReps: 12, increment: 5),
        .init(stableID: "chest-dumbbell-fly", name: "哑铃飞鸟", aliases: ["平板飞鸟"], part: .chest, equipment: "哑铃", loadType: .weighted, minReps: 10, maxReps: 15, increment: 1),
        .init(stableID: "chest-smith-bench", name: "史密斯机卧推", aliases: ["史密斯卧推"], part: .chest, equipment: "史密斯机", loadType: .weighted, minReps: 8, maxReps: 12, increment: 2.5),

        .init(stableID: "back-lat-pulldown", name: "高位下拉", aliases: ["下拉"], part: .back, equipment: "绳索", loadType: .weighted, minReps: 8, maxReps: 12, increment: 2.5),
        .init(stableID: "back-barbell-row", name: "杠铃划船", aliases: ["俯身划船"], part: .back, equipment: "杠铃", loadType: .weighted, minReps: 6, maxReps: 10, increment: 2.5),
        .init(stableID: "back-seated-row", name: "坐姿划船", aliases: ["绳索划船"], part: .back, equipment: "绳索", loadType: .weighted, minReps: 8, maxReps: 12, increment: 2.5),
        .init(stableID: "back-pull-up", name: "引体向上", aliases: ["引体"], part: .back, equipment: "徒手", loadType: .bodyweight, minReps: 5, maxReps: 10, increment: 2.5),
        .init(stableID: "back-assisted-pull-up", name: "辅助引体向上", aliases: ["助力引体"], part: .back, equipment: "固定器械", loadType: .assisted, minReps: 6, maxReps: 10, increment: 5),
        .init(stableID: "back-one-arm-row", name: "单臂哑铃划船", aliases: ["单臂划船"], part: .back, equipment: "哑铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 1),
        .init(stableID: "back-face-pull", name: "面拉", aliases: ["绳索面拉"], part: .back, equipment: "绳索", loadType: .weighted, minReps: 12, maxReps: 15, increment: 2.5),
        .init(stableID: "back-straight-arm-pulldown", name: "直臂下压", aliases: ["直臂下拉"], part: .back, equipment: "绳索", loadType: .weighted, minReps: 10, maxReps: 15, increment: 2.5),

        .init(stableID: "legs-back-squat", name: "杠铃深蹲", aliases: ["深蹲"], part: .legs, equipment: "杠铃", loadType: .weighted, minReps: 5, maxReps: 10, increment: 2.5),
        .init(stableID: "legs-romanian-deadlift", name: "罗马尼亚硬拉", aliases: ["罗马尼亚式硬拉", "RDL"], part: .legs, equipment: "杠铃", loadType: .weighted, minReps: 6, maxReps: 10, increment: 2.5),
        .init(stableID: "legs-leg-press", name: "腿举", aliases: ["倒蹬"], part: .legs, equipment: "固定器械", loadType: .weighted, minReps: 8, maxReps: 12, increment: 5),
        .init(stableID: "legs-bulgarian-split-squat", name: "保加利亚分腿蹲", aliases: ["分腿蹲"], part: .legs, equipment: "哑铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 1),
        .init(stableID: "legs-extension", name: "腿屈伸", aliases: ["坐姿腿屈伸"], part: .legs, equipment: "固定器械", loadType: .weighted, minReps: 10, maxReps: 15, increment: 5),
        .init(stableID: "legs-curl", name: "腿弯举", aliases: ["俯卧腿弯举"], part: .legs, equipment: "固定器械", loadType: .weighted, minReps: 10, maxReps: 15, increment: 5),
        .init(stableID: "legs-hip-thrust", name: "杠铃臀推", aliases: ["臀推"], part: .legs, equipment: "杠铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 5),
        .init(stableID: "legs-calf-raise", name: "站姿提踵", aliases: ["提踵"], part: .legs, equipment: "固定器械", loadType: .weighted, minReps: 12, maxReps: 20, increment: 5),

        .init(stableID: "shoulders-overhead-press", name: "杠铃推举", aliases: ["站姿推举", "OHP"], part: .shoulders, equipment: "杠铃", loadType: .weighted, minReps: 6, maxReps: 10, increment: 2.5),
        .init(stableID: "shoulders-dumbbell-press", name: "哑铃肩推", aliases: ["哑铃推举"], part: .shoulders, equipment: "哑铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 1),
        .init(stableID: "shoulders-lateral-raise", name: "哑铃侧平举", aliases: ["侧平举"], part: .shoulders, equipment: "哑铃", loadType: .weighted, minReps: 12, maxReps: 20, increment: 1),
        .init(stableID: "shoulders-reverse-fly", name: "俯身反向飞鸟", aliases: ["反向飞鸟"], part: .shoulders, equipment: "哑铃", loadType: .weighted, minReps: 12, maxReps: 15, increment: 1),
        .init(stableID: "shoulders-arnold-press", name: "阿诺德推举", aliases: ["阿诺德肩推"], part: .shoulders, equipment: "哑铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 1),
        .init(stableID: "shoulders-cable-lateral-raise", name: "绳索侧平举", aliases: ["单臂侧平举"], part: .shoulders, equipment: "绳索", loadType: .weighted, minReps: 12, maxReps: 20, increment: 2.5),
        .init(stableID: "shoulders-upright-row", name: "直立划船", aliases: ["杠铃直立划船"], part: .shoulders, equipment: "杠铃", loadType: .weighted, minReps: 8, maxReps: 12, increment: 2.5),
        .init(stableID: "shoulders-machine-press", name: "器械肩推", aliases: ["固定器械推举"], part: .shoulders, equipment: "固定器械", loadType: .weighted, minReps: 8, maxReps: 12, increment: 5)
    ]

    @MainActor
    static func bootstrapIfNeeded(context: ModelContext) throws {
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        let existingIDs = Set(existingExercises.map(\.stableID))
        for item in catalog where !existingIDs.contains(item.stableID) {
            context.insert(Exercise(
                stableID: item.stableID,
                name: item.name,
                aliases: item.aliases,
                primaryBodyPart: item.part,
                equipment: item.equipment,
                loadType: item.loadType,
                defaultRepMin: item.minReps,
                defaultRepMax: item.maxReps,
                defaultIncrementKg: item.increment
            ))
        }

        if try context.fetch(FetchDescriptor<UserProfile>()).isEmpty {
            context.insert(UserProfile())
        }
        try context.save()

        let arguments = ProcessInfo.processInfo.arguments
        if (arguments.contains("-uiTesting") || arguments.contains("-launchUITesting")),
           let profile = try context.fetch(FetchDescriptor<UserProfile>()).first {
            profile.hasSeenOnboarding = true
            try context.save()
        }

        if ProcessInfo.processInfo.arguments.contains("-demoData") {
            try seedDemoDataIfNeeded(context: context)
        }
    }

    @MainActor
    private static func seedDemoDataIfNeeded(context: ModelContext) throws {
        guard try context.fetch(FetchDescriptor<BodyMeasurement>()).isEmpty,
              try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty else { return }
        let calendar = Calendar.current
        for (offset, weight, fat) in [(-24, 73.3, 19.1), (-17, 73.0, 18.9), (-10, 72.8, 18.8), (-3, 72.4, 18.6)] {
            if let date = calendar.date(byAdding: .day, value: offset, to: .now) {
                context.insert(BodyMeasurement(recordedAt: date, weightKg: weight, bodyFatPercent: fat))
            }
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let ids = ["chest-barbell-bench-press", "chest-incline-dumbbell-press", "chest-cable-fly", "shoulders-lateral-raise"]
        for dayOffset in [-7, -2] {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
            let session = WorkoutSession(startedAt: date, status: .completed)
            session.endedAt = date.addingTimeInterval(48 * 60)
            session.localDayKey = DayKey.make(from: date)
            session.entries = ids.enumerated().compactMap { index, id in
                guard let exercise = exercises.first(where: { $0.stableID == id }) else { return nil }
                let base: Double = id.contains("bench-press") ? (dayOffset == -2 ? 62.5 : 60) : id.contains("incline") ? 22.5 : 15
                return ExerciseEntry(
                    orderIndex: index,
                    exerciseStableID: exercise.stableID,
                    exerciseNameSnapshot: exercise.name,
                    bodyPartSnapshot: exercise.primaryBodyPart,
                    loadTypeSnapshot: exercise.loadType,
                    status: .completed,
                    sets: (0..<4).map { setIndex in SetEntry(orderIndex: setIndex, weightKg: base, reps: 8 + (setIndex % 2), isCompleted: true) }
                )
            }
            session.focusBodyPartsCSV = [BodyPart.chest.rawValue, BodyPart.shoulders.rawValue].joined(separator: ",")
            context.insert(session)
            context.insert(CheckIn(occurredAt: session.endedAt ?? date, source: .workout, workoutID: session.id, bodyPart: .chest))
        }
        try context.save()
    }
}
