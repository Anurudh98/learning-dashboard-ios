//
//  LessonCompletionResult.swift
//  LearningDashboard
//

import Foundation

struct LessonCompletionResult: Equatable {
    let detail: CourseDetail
    /// `false` when the change is saved on the device but the server has not confirmed it yet.
    let isSynced: Bool
}
