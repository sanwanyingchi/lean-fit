import XCTest
@testable import LeanFit

final class EngineTests: XCTestCase {
    func testEstimatedOneRepMaxUsesEpleyForSupportedRange() {
        XCTAssertEqual(ProgressEngine.estimatedOneRepMax(weight: 60, reps: 10)!, 80, accuracy: 0.001)
        XCTAssertNil(ProgressEngine.estimatedOneRepMax(weight: 60, reps: 11))
        XCTAssertNil(ProgressEngine.estimatedOneRepMax(weight: 0, reps: 8))
    }

    func testWeightedProgressPrefersEstimatedStrength() {
        let previous = ExercisePerformance(
            maxWeight: 60,
            repsAtMaxWeight: 8,
            maxReps: 8,
            estimatedStrength: 76,
            volume: 1_920,
            minAssistance: 60,
            repsAtMinAssistance: 8
        )
        let current = ExercisePerformance(
            maxWeight: 60,
            repsAtMaxWeight: 10,
            maxReps: 10,
            estimatedStrength: 80,
            volume: 2_400,
            minAssistance: 60,
            repsAtMinAssistance: 10
        )
        let result = ProgressEngine.compare(current: current, previous: previous, loadType: .weighted, exerciseName: "杠铃卧推")
        XCTAssertEqual(result?.kind, .estimatedStrength)
    }

    func testAssistedProgressTreatsLessAssistanceAsImprovement() {
        let previous = ExercisePerformance(maxWeight: 40, repsAtMaxWeight: 8, maxReps: 8, estimatedStrength: nil, volume: 1_280, minAssistance: 40, repsAtMinAssistance: 8)
        let current = ExercisePerformance(maxWeight: 35, repsAtMaxWeight: 8, maxReps: 8, estimatedStrength: nil, volume: 1_120, minAssistance: 35, repsAtMinAssistance: 8)
        XCTAssertEqual(ProgressEngine.compare(current: current, previous: previous, loadType: .assisted, exerciseName: "辅助引体")?.kind, .weight)
    }

    func testExerciseValidationNormalizesWhitespaceAndWidth() {
        XCTAssertEqual("  ＢＥＮＣＨ   Press  ".normalizedExerciseName, "bench press")
        XCTAssertEqual(
            InputValidation.validateExercise(
                name: "BENCH press",
                existingNames: ["Bench Press"],
                repMin: 8,
                repMax: 12,
                increment: 2.5
            ),
            "动作库中已有同名动作"
        )
    }

    func testWeightAndRepBoundaries() {
        XCTAssertTrue(InputValidation.validWeight(0))
        XCTAssertTrue(InputValidation.validWeight(500))
        XCTAssertFalse(InputValidation.validWeight(10.25))
        XCTAssertFalse(InputValidation.validWeight(500.1))
        XCTAssertTrue(InputValidation.validReps(1))
        XCTAssertTrue(InputValidation.validReps(100))
        XCTAssertFalse(InputValidation.validReps(0))
        XCTAssertFalse(InputValidation.validReps(101))
    }

    func testEnergyCalculation() {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = calendar.date(from: DateComponents(year: 1996, month: 1, day: 1))!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let resting = EnergyEngine.restingEnergy(sex: .male, weightKg: 70, heightCm: 175, birthDate: birthDate, on: reference)
        XCTAssertEqual(resting!, 1648.75, accuracy: 0.001)
        let total = EnergyEngine.totalDailyEnergy(sex: .male, weightKg: 70, heightCm: 175, birthDate: birthDate, activityLevel: .moderate, on: reference)
        XCTAssertEqual(total!, 2_560, accuracy: 0.001)
    }

    func testWeekAlwaysStartsOnMonday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6))!
        let start = CalendarEngine.startOfWeek(containing: sunday, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: start), 2)
        XCTAssertEqual(calendar.component(.day, from: start), 31)
    }

    func testTrainingDaysDeduplicateSessionsAndManualCheckIns() {
        let date = Date.now
        let key = DayKey.make(from: date)
        XCTAssertEqual(
            CalendarEngine.uniqueTrainingDays(
                sessionDayKeys: [key, key],
                checkInDayKeys: [key],
                weekContaining: date
            ).count,
            1
        )
    }

    func testDoubleProgressionAddsOneRepBeforeWeight() {
        let targets = TargetEngine.makeTargets(
            loadType: .weighted,
            repMin: 8,
            repMax: 12,
            incrementKg: 2.5,
            previousSets: [(60, 10), (60, 8)]
        )
        XCTAssertEqual(targets[0].reps, 10)
        XCTAssertEqual(targets[1].reps, 9)
        XCTAssertEqual(targets[1].weight, 60)
    }


    func testDoubleProgressionAddsWeightAfterAllSetsReachTopOfRange() {
        let targets = TargetEngine.makeTargets(
            loadType: .weighted,
            repMin: 8,
            repMax: 12,
            incrementKg: 2.5,
            previousSets: [(80, 12), (80, 12), (80, 12), (80, 12)]
        )
        XCTAssertEqual(targets.map(\.weight), [82.5, 82.5, 82.5, 82.5])
        XCTAssertEqual(targets.map(\.reps), [8, 8, 8, 8])
    }
}
