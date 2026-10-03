//
//  CourseRepositoryProtocol.swift
//  LearningDashboard
//

import Foundation

protocol CourseRepositoryProtocol {

    /// Network first; falls back to the saved copy when the network is unavailable.
    func courses() async throws -> Sourced<[Course]>

    /// Whatever is saved on the device (no network).
    func cachedCourses() async -> [Course]

    func courseDetail(id: Int) async throws -> Sourced<CourseDetail>

    /// Applies the change locally first, then tells the server. If the device is offline the change
    /// is queued and the result has `isSynced == false`.
    func completeLesson(courseId: Int, lessonId: Int) async throws -> LessonCompletionResult

    /// Replays changes made while offline. Safe to call at any time.
    func syncPendingCompletions() async

    func hasPendingCompletions(courseId: Int) async -> Bool

    func clearLocalData() async
}

enum RepositoryError: LocalizedError, Equatable {
    case courseNotLoaded

    var errorDescription: String? {
        switch self {
        case .courseNotLoaded:
            return "This course isn't available yet. Please reload it and try again."
        }
    }
}
