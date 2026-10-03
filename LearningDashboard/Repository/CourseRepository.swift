//
//  CourseRepository.swift
//  LearningDashboard
//

import Foundation

/// Single source of truth for course data: remote API + local cache.
///
/// An `actor` so overlapping calls (a refresh and a lesson completion, say) cannot interleave
/// in ways that corrupt state; all cache writes go through the cache's atomic `update`.
actor CourseRepository: CourseRepositoryProtocol {

    private let apiClient: APIClientProtocol
    private let cache: CourseCacheProtocol
    private let now: @Sendable () -> Date

    init(
        apiClient: APIClientProtocol,
        cache: CourseCacheProtocol,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.apiClient = apiClient
        self.cache = cache
        self.now = now
    }

    // MARK: - Reads

    func courses() async throws -> Sourced<[Course]> {
        await syncPendingCompletions()

        do {
            let remote: [Course] = try await apiClient.request(.courses)
            let timestamp = now()

            let merged = await cache.update { snapshot -> [Course] in
                snapshot.courses = CourseRepository.applyingPending(to: remote, in: snapshot)
                snapshot.lastUpdated = timestamp
                return snapshot.courses
            }
            return Sourced(value: merged, source: .remote)
        } catch {
            if error is CancellationError { throw error }

            // Stale-while-error: prefer showing saved data over an error screen.
            let snapshot = await cache.load()
            guard snapshot.lastUpdated != nil else { throw error }
            return Sourced(value: snapshot.courses, source: .cache)
        }
    }

    func cachedCourses() async -> [Course] {
        await cache.load().courses
    }

    func courseDetail(id: Int) async throws -> Sourced<CourseDetail> {
        do {
            let remote: CourseDetail = try await apiClient.request(.courseDetail(id: id))

            let merged = await cache.update { snapshot -> CourseDetail in
                // Never let an older server copy erase something the user did while offline.
                let pending = snapshot.pendingCompletions.filter { $0.courseId == id }
                let detail = pending.reduce(remote) { $0.completing(lessonId: $1.lessonId) }
                CourseRepository.store(detail, in: &snapshot)
                return detail
            }
            return Sourced(value: merged, source: .remote)
        } catch {
            if error is CancellationError { throw error }

            let snapshot = await cache.load()
            if let cached = snapshot.details.first(where: { $0.course.id == id }) {
                return Sourced(value: cached, source: .cache)
            }
            throw error
        }
    }

    func hasPendingCompletions(courseId: Int) async -> Bool {
        await cache.load().pendingCompletions.contains { $0.courseId == courseId }
    }

    // MARK: - Writes

    func completeLesson(courseId: Int, lessonId: Int) async throws -> LessonCompletionResult {

        // 1. Optimistic local write - the user's tap is never lost, even with no network.
        let change = await cache.update { snapshot -> (previous: CourseDetail, updated: CourseDetail)? in
            guard let existing = snapshot.details.first(where: { $0.course.id == courseId }) else { return nil }
            let updated = existing.completing(lessonId: lessonId)
            CourseRepository.store(updated, in: &snapshot)
            return (previous: existing, updated: updated)
        }

        guard let change else { throw RepositoryError.courseNotLoaded }

        // Already completed (or unknown lesson): nothing to send.
        if change.updated == change.previous {
            return LessonCompletionResult(detail: change.updated, isSynced: true)
        }

        // 2. Tell the server.
        do {
            let remote: CourseDetail = try await apiClient.request(
                .completeLesson(courseId: courseId, lessonId: lessonId)
            )

            let outcome = await cache.update { snapshot -> (detail: CourseDetail, hasPending: Bool) in
                let pending = snapshot.pendingCompletions.filter { $0.courseId == courseId }
                let detail = pending.reduce(remote) { $0.completing(lessonId: $1.lessonId) }
                CourseRepository.store(detail, in: &snapshot)
                return (detail: detail, hasPending: !pending.isEmpty)
            }
            return LessonCompletionResult(detail: outcome.detail, isSynced: !outcome.hasPending)

        } catch let error where CourseRepository.isConnectivityFailure(error) {
            // 3a. Offline: keep the optimistic state and queue it for later.
            let item = PendingCompletion(courseId: courseId, lessonId: lessonId)
            await cache.update { snapshot -> Void in
                if !snapshot.pendingCompletions.contains(item) {
                    snapshot.pendingCompletions.append(item)
                }
            }
            return LessonCompletionResult(detail: change.updated, isSynced: false)

        } catch {
            // 3b. The server rejected it: undo the optimistic write and surface the error.
            let previous = change.previous
            await cache.update { snapshot -> Void in
                CourseRepository.store(previous, in: &snapshot)
            }
            throw error
        }
    }

    func syncPendingCompletions() async {
        let pending = await cache.load().pendingCompletions

        for item in pending {
            do {
                let remote: CourseDetail = try await apiClient.request(
                    .completeLesson(courseId: item.courseId, lessonId: item.lessonId)
                )
                await cache.update { snapshot -> Void in
                    snapshot.pendingCompletions.removeAll { $0 == item }
                    let remaining = snapshot.pendingCompletions.filter { $0.courseId == item.courseId }
                    let detail = remaining.reduce(remote) { $0.completing(lessonId: $1.lessonId) }
                    CourseRepository.store(detail, in: &snapshot)
                }
            } catch {
                // A 4xx means the server will never accept this item: drop it so it cannot block
                // the queue forever. Anything else (offline, 5xx...) - stop and retry next time.
                guard case NetworkError.serverError(let code) = error, (400..<500).contains(code) else {
                    return
                }
                await cache.update { snapshot -> Void in
                    snapshot.pendingCompletions.removeAll { $0 == item }
                }
            }
        }
    }

    func clearLocalData() async {
        await cache.clear()
    }

    // MARK: - Helpers

    private static func isConnectivityFailure(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .noInternet
    }

    /// Writes `detail` into the snapshot and keeps the course list's progress in step with it.
    private static func store(_ detail: CourseDetail, in snapshot: inout CacheSnapshot) {
        if let index = snapshot.details.firstIndex(where: { $0.course.id == detail.course.id }) {
            snapshot.details[index] = detail
        } else {
            snapshot.details.append(detail)
        }

        if let index = snapshot.courses.firstIndex(where: { $0.id == detail.course.id }) {
            snapshot.courses[index].progress = detail.course.progress
        }
    }

    /// Courses with un-synced local changes keep their locally computed progress.
    private static func applyingPending(to courses: [Course], in snapshot: CacheSnapshot) -> [Course] {
        let pendingCourseIds = Set(snapshot.pendingCompletions.map(\.courseId))
        guard !pendingCourseIds.isEmpty else { return courses }

        return courses.map { course in
            guard
                pendingCourseIds.contains(course.id),
                let local = snapshot.details.first(where: { $0.course.id == course.id })
            else { return course }

            var updated = course
            updated.progress = local.course.progress
            return updated
        }
    }
}
