//
//  ProgressAndModelTests.swift
//  LearningDashboardTests
//

import XCTest
@testable import LearningDashboard

final class ProgressCalculatorTests: XCTestCase {

    func testPercentageRoundsToNearestWholeNumber() {
        XCTAssertEqual(ProgressCalculator.percentage(completed: 1, total: 3), 33)
        XCTAssertEqual(ProgressCalculator.percentage(completed: 2, total: 3), 67)
        XCTAssertEqual(ProgressCalculator.percentage(completed: 13, total: 20), 65)
    }

    func testZeroLessonsIsZeroPercentAndNeverDividesByZero() {
        XCTAssertEqual(ProgressCalculator.percentage(completed: 0, total: 0), 0)
    }

    func testOutOfRangeInputIsClamped() {
        XCTAssertEqual(ProgressCalculator.percentage(completed: 9, total: 4), 100)
        XCTAssertEqual(ProgressCalculator.percentage(completed: -2, total: 4), 0)
    }
}

final class CourseDetailTests: XCTestCase {

    func testCompletingALessonChangesItsStatusAndRecalculatesProgress() {
        let before = Fixtures.pythonDetail(completed: [1, 2])
        XCTAssertEqual(before.progress, 50)

        let after = before.completing(lessonId: 3)

        XCTAssertTrue(after.lessons.first { $0.id == 3 }!.isCompleted)
        XCTAssertEqual(after.completedCount, 3)
        XCTAssertEqual(after.progress, 75)
        // The original value is untouched (value semantics make rollback trivial).
        XCTAssertEqual(before.completedCount, 2)
    }

    func testCompletingTheLastLessonReachesOneHundredPercent() {
        let after = Fixtures.pythonDetail(completed: [1, 2, 3]).completing(lessonId: 4)
        XCTAssertEqual(after.progress, 100)
    }

    func testCompletingAnAlreadyCompletedLessonIsANoOp() {
        let detail = Fixtures.pythonDetail(completed: [1, 2])
        XCTAssertEqual(detail.completing(lessonId: 1), detail)
    }

    func testCompletingAnUnknownLessonIsANoOp() {
        let detail = Fixtures.pythonDetail(completed: [1, 2])
        XCTAssertEqual(detail.completing(lessonId: 99), detail)
    }

    func testCourseDecodesTheAssignmentJSONShape() throws {
        let json = #"{"id":1,"title":"Python Programming","instructor":"John Smith","progress":65,"lessons":20}"#
        let course = try JSONDecoder().decode(Course.self, from: Data(json.utf8))

        XCTAssertEqual(course.lessonCount, 20)
        XCTAssertEqual(course.progress, 65)
    }
}
