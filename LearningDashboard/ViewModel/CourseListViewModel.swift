//
//  CourseListViewModel.swift
//  LearningDashboard
//

import Foundation
import Observation

@MainActor
@Observable
final class CourseListViewModel {

    private(set) var state: LoadState = .idle
    private(set) var courses: [Course] = []
    private(set) var dataSource: DataSource = .remote

    @ObservationIgnored private let repository: CourseRepositoryProtocol
    @ObservationIgnored private var hasLoaded = false

    init(repository: CourseRepositoryProtocol) {
        self.repository = repository
    }

    /// First appearance loads from the repository. Coming back from the detail screen only re-reads
    /// the local copy, which is where the detail screen has already saved the new progress.
    func onAppear() async {
        if hasLoaded {
            await reloadFromCache()
        } else {
            await load()
        }
    }

    func load() async {
        // Only show the full-screen spinner when there is nothing else to show.
        if courses.isEmpty { state = .loading }

        do {
            let result = try await repository.courses()
            courses = result.value
            dataSource = result.source
            state = .loaded
            hasLoaded = true
        } catch is CancellationError {
            // e.g. pull-to-refresh interrupted: never leave the screen stuck on "loading".
            if state == .loading { state = courses.isEmpty ? .idle : .loaded }
        } catch {
            if courses.isEmpty {
                state = .failed(error.userMessage)
            } else {
                dataSource = .cache
                state = .loaded
            }
        }
    }

    func refresh() async {
        await load()
    }

    func reloadFromCache() async {
        let cached = await repository.cachedCourses()
        guard !cached.isEmpty else { return }
        courses = cached
    }

    /// Developer tool (mock backend menu): wipe saved data so the error/empty states can be shown.
    func clearSavedDataAndReload() async {
        await repository.clearLocalData()
        courses = []
        hasLoaded = false
        state = .idle
        await load()
    }
}
