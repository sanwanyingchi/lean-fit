import XCTest
import SwiftData
@testable import LeanFit

final class PersistenceTests: XCTestCase {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            BodyMeasurement.self,
            Exercise.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            CheckIn.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    @MainActor
    func testSeedIsIdempotentAndCatalogHasRequiredCoverage() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.bootstrapIfNeeded(context: context)
        try SeedData.bootstrapIfNeeded(context: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertGreaterThanOrEqual(exercises.count, 32)
        for bodyPart in [BodyPart.chest, .back, .legs, .shoulders] {
            XCTAssertGreaterThanOrEqual(exercises.filter { $0.primaryBodyPart == bodyPart }.count, 8)
        }
        XCTAssertEqual(Set(exercises.map(\.stableID)).count, exercises.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1)
    }

    @MainActor
    func testBodyMeasurementUpsertsSameLocalDayAndPreservesOtherMetric() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = Date.now
        try PersistenceActions.saveBodyMeasurement(
            date: date,
            weightKg: 72.5,
            bodyFatPercent: nil,
            existing: [],
            context: context
        )
        let first = try context.fetch(FetchDescriptor<BodyMeasurement>())
        try PersistenceActions.saveBodyMeasurement(
            date: date,
            weightKg: nil,
            bodyFatPercent: 18.2,
            existing: first,
            context: context
        )
        let stored = try context.fetch(FetchDescriptor<BodyMeasurement>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].weightKg, 72.5)
        XCTAssertEqual(stored[0].bodyFatPercent, 18.2)
    }

    @MainActor
    func testSessionObjectGraphPersistsAndCascades() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let set = SetEntry(orderIndex: 0, weightKg: 60, reps: 8, isCompleted: true)
        let entry = ExerciseEntry(
            orderIndex: 0,
            exerciseStableID: "chest-barbell-bench-press",
            exerciseNameSnapshot: "杠铃卧推",
            bodyPartSnapshot: .chest,
            loadTypeSnapshot: .weighted,
            status: .completed,
            sets: [set]
        )
        let session = WorkoutSession(status: .completed, entries: [entry])
        session.endedAt = .now
        context.insert(session)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).first?.effectiveSetCount, 1)

        context.delete(session)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }
}
