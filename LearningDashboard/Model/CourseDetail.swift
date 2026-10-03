//
//  CourseDetail.swift
//  LearningDashboard
//

import Foundation

struct Lesson: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    var isCompleted: Bool
}

struct CourseDetail: Codable, Equatable {

    var course: Course
    var lessons: [Lesson]

    var completedCount: Int {
        lessons.filter(\.isCompleted).count
    }

    /// Current progress (0...100). It is the server's value until the user completes a lesson,
    /// after which `completing(lessonId:)` recalculates it from the lessons themselves.
    var progress: Int {
        course.progress
    }

    /// Returns a copy with `lessonId` completed and the course progress recalculated.
    /// Completing an unknown or already-completed lesson is a no-op (idempotent).
    func completing(lessonId: Int) -> CourseDetail {
        guard
            let index = lessons.firstIndex(where: { $0.id == lessonId }),
            !lessons[index].isCompleted
        else { return self }

        var copy = self
        copy.lessons[index].isCompleted = true
        copy.course.progress = ProgressCalculator.percentage(
            completed: copy.completedCount,
            total: copy.lessons.count
        )
        return copy
    }
}
