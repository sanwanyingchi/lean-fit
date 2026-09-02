import XCTest

final class LeanFitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreNavigationAndExercisePicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData"]
        app.launch()

        XCTAssertTrue(app.navigationBars["进展"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["progress.profile"].exists)
        XCTAssertTrue(app.buttons["root.startWorkout"].exists)

        app.buttons["root.tab.records"].tap()
        XCTAssertTrue(app.navigationBars["记录"].waitForExistence(timeout: 3))

        app.buttons["root.startWorkout"].tap()
        XCTAssertTrue(app.navigationBars["选择本次动作"].waitForExistence(timeout: 3))
        let search = app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 2))
        search.tap()
        search.typeText("一个动作库里没有的动作")
        XCTAssertTrue(app.buttons["新建自定义动作"].waitForExistence(timeout: 2))
    }

    func testSelectFourExercisesAndStartWorkout() throws {
        let app = launchDemoApp()
        app.buttons["root.startWorkout"].tap()
        XCTAssertTrue(app.navigationBars["选择本次动作"].waitForExistence(timeout: 3))

        let exerciseList = app.scrollViews["exercise.list"]
        let selectionSummary = app.staticTexts["exercise.selectionSummary"]
        XCTAssertTrue(exerciseList.waitForExistence(timeout: 2))
        XCTAssertTrue(selectionSummary.waitForExistence(timeout: 2))
        exerciseList.swipeUp()
        for identifier in [
            "exercise.shoulders-arnold-press",
            "exercise.legs-bulgarian-split-squat",
            "exercise.back-one-arm-row"
        ] {
            assertExerciseSelected(app.buttons[identifier], in: exerciseList, above: selectionSummary)
        }

        assertExerciseSelected(app.buttons["exercise.shoulders-reverse-fly"], in: exerciseList, above: selectionSummary)

        let start = app.buttons["exercise.start"]
        expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: start
        )
        waitForExpectations(timeout: 3)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.91)).tap()
        XCTAssertTrue(app.staticTexts["训练中"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["workout.completeEntry"].waitForExistence(timeout: 2))
    }

    func testBodyUpdateProfileAndRecordDetailEntrances() throws {
        let app = launchDemoApp()
        app.buttons["progress.updateBody"].tap()
        XCTAssertTrue(app.navigationBars["更新身体数据"].waitForExistence(timeout: 3))
        app.buttons["取消"].tap()

        app.buttons["progress.profile"].tap()
        XCTAssertTrue(app.navigationBars["个人档案"].waitForExistence(timeout: 3))
        app.buttons["取消"].tap()

        app.buttons["root.tab.records"].tap()
        XCTAssertTrue(app.buttons["records.workout"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["records.workout"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["训练详情"].waitForExistence(timeout: 3))
    }

    func testManualCheckInSheetLayout() throws {
        let app = launchDemoApp()
        app.buttons["root.tab.records"].tap()
        XCTAssertTrue(app.navigationBars["记录"].waitForExistence(timeout: 3))

        let manualCheckIn = app.buttons["手动打卡"]
        XCTAssertTrue(manualCheckIn.waitForExistence(timeout: 2))
        manualCheckIn.tap()

        XCTAssertTrue(app.navigationBars["训练打卡"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["取消"].exists)
        XCTAssertTrue(app.buttons["完成打卡"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["完成打卡"].isHittable)
        keepScreenshot(of: app, named: "records-manual-check-in-after")
    }

    func testVisualSnapshots() throws {
        let app = launchDemoApp()
        keepScreenshot(of: app, named: "01-progress")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.93)).tap()
        XCTAssertTrue(app.navigationBars["记录"].waitForExistence(timeout: 3))
        keepScreenshot(of: app, named: "02-records")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.93)).tap()
        XCTAssertTrue(app.navigationBars["选择本次动作"].waitForExistence(timeout: 3))
        keepScreenshot(of: app, named: "03-exercise-picker")

        let exerciseList = app.scrollViews["exercise.list"]
        let selectionSummary = app.staticTexts["exercise.selectionSummary"]
        XCTAssertTrue(exerciseList.waitForExistence(timeout: 2))
        XCTAssertTrue(selectionSummary.waitForExistence(timeout: 2))
        exerciseList.swipeUp()
        for identifier in [
            "exercise.shoulders-arnold-press",
            "exercise.legs-bulgarian-split-squat",
            "exercise.back-one-arm-row",
            "exercise.shoulders-reverse-fly"
        ] {
            assertExerciseSelected(app.buttons[identifier], in: exerciseList, above: selectionSummary)
        }
        keepScreenshot(of: app, named: "04-exercises-selected")

        let start = app.buttons["exercise.start"]
        expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: start
        )
        waitForExpectations(timeout: 3)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.91)).tap()
        let completeEntry = app.buttons["workout.completeEntry"]
        XCTAssertTrue(completeEntry.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: completeEntry)
        waitForExpectations(timeout: 3)
        keepScreenshot(of: app, named: "05-workout")
    }

    func testLaunchExperienceCanBeSkipped() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-launchUITesting", "-demoData"]
        app.launch()

        let launchExperience = app.buttons["launch.experience"]
        XCTAssertTrue(launchExperience.waitForExistence(timeout: 3))
        keepScreenshot(of: app, named: "00-launch")
        launchExperience.tap()

        expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: launchExperience
        )
        waitForExpectations(timeout: 2)
        XCTAssertTrue(app.navigationBars["进展"].waitForExistence(timeout: 5))
    }

    private func launchDemoApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData"]
        app.launch()
        XCTAssertTrue(app.navigationBars["进展"].waitForExistence(timeout: 5))
        return app
    }

    private func assertExerciseSelected(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        above selectionSummary: XCUIElement
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 2))
        let predicate = NSPredicate(format: "value == %@", "已选择")

        for _ in 0..<12 {
            if predicate.evaluate(with: element) { return }
            let elementFrame = element.frame
            if elementFrame.minY < scrollView.frame.minY {
                nudge(scrollView, contentTowardBottom: true)
                continue
            }
            if elementFrame.midY >= selectionSummary.frame.minY - 8 {
                nudge(scrollView, contentTowardBottom: false)
                continue
            }
            if element.isHittable {
                element.tap()
                let selected = XCTNSPredicateExpectation(predicate: predicate, object: element)
                if XCTWaiter.wait(for: [selected], timeout: 1) == .completed { return }
            }
        }

        XCTFail("动作未成功切换为已选择：\(element)")
    }

    private func nudge(_ scrollView: XCUIElement, contentTowardBottom: Bool) {
        let startY = contentTowardBottom ? 0.42 : 0.60
        let endY = contentTowardBottom ? 0.60 : 0.42
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func keepScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
