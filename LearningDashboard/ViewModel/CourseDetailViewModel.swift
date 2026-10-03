//
//  CourseDetailViewModel.swift
//  LearningDashboard
//

import Foundation
import Observation

@MainActor
@Observable
final class CourseDetailViewModel {

    let course: Course

    private(set) var state: LoadState = .idle
    private(set) var detail: CourseDetail?
    private(set) var dataSource: DataSource = .remote
    private(set) var completingLessonId: Int?
    private(set) var hasUnsyncedChanges = false

    /// Bound to an alert; set when a completion could not be saved.
    private(set) var actionError: String?

    @ObservationIgnored private let repository: CourseRepositoryProtocol

    init(course: Course, repository: CourseRepositoryProtocol) {
        self.course = course
        self.repository = repository
    }

    func load() async {
        guard detail == nil else { return }
        await fetch()
    }

    func retry() async {
        await fetch()
    }

    private func fetch() async {
        state = .loading

        do {
            let result = try await repository.courseDetail(id: course.id)
            detail = result.value
            dataSource = result.source
            hasUnsyncedChanges = await repository.hasPendingCompletions(courseId: course.id)
            state = .loaded
        } catch is CancellationError {
            if state == .loading { state = detail == nil ? .idle : .loaded }
        } catch {
            state = .failed(error.userMessage)
        }
    }

    /// Optimistic update: the row flips immediately; if saving fails it flips back and an alert is shown.
    func complete(lessonId: Int) async {
        // One completion at a time keeps the optimistic state and the saved state trivially consistent.
        guard
            completingLessonId == nil,
            let current = detail,
            current.lessons.first(where: { $0.id == lessonId })?.isCompleted == false
        else { return }

        completingLessonId = lessonId
        defer { completingLessonId = nil }

        detail = current.completing(lessonId: lessonId)

        do {
            let result = try await repository.completeLesson(courseId: course.id, lessonId: lessonId)
            detail = result.detail
            hasUnsyncedChanges = !result.isSynced
        } catch {
            detail = current
            actionError = error.userMessage
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    /// Called when connectivity returns: push queued changes, then show the server's version.
    func onConnectivityRestored() async {
        guard hasUnsyncedChanges else { return }
        await repository.syncPendingCompletions()

        do {
            let result = try await repository.courseDetail(id: course.id)
            detail = result.value
            dataSource = result.source
        } catch {
            // Keep showing what we have; the next appearance or reconnect will retry.
        }
        hasUnsyncedChanges = await repository.hasPendingCompletions(courseId: course.id)
    }
}
