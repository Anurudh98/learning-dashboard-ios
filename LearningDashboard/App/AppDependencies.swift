//
//  AppDependencies.swift
//  LearningDashboard
//

import SwiftUI

/// Composition root: the only place that knows which concrete types are used.
@MainActor
@Observable
final class AppDependencies {

    let authRepository: AuthRepositoryProtocol
    let courseRepository: CourseRepositoryProtocol
    let sessionManager: SessionManager
    let networkMonitor: NetworkMonitor

    /// Production wiring.
    init() {
        let networkMonitor = NetworkMonitor()
        let tokenStore = KeychainTokenStore()
        let cache = FileCourseCache()

        let apiClient: APIClientProtocol
        if AppConfiguration.useMockBackend {
            apiClient = MockAPIClient(conditions: networkMonitor.conditions)
        } else {
            apiClient = APIClient(tokenProvider: { tokenStore.readToken() })
        }

        let authRepository = AuthRepository(apiClient: apiClient, tokenStore: tokenStore)

        self.networkMonitor = networkMonitor
        self.authRepository = authRepository
        self.courseRepository = CourseRepository(apiClient: apiClient, cache: cache)
        self.sessionManager = SessionManager(authRepository: authRepository, courseCache: cache)
    }

    /// Injection point for previews and tests.
    init(
        authRepository: AuthRepositoryProtocol,
        courseRepository: CourseRepositoryProtocol,
        sessionManager: SessionManager,
        networkMonitor: NetworkMonitor
    ) {
        self.authRepository = authRepository
        self.courseRepository = courseRepository
        self.sessionManager = sessionManager
        self.networkMonitor = networkMonitor
    }

    // MARK: - View model factories

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            authRepository: authRepository,
            onLoginSuccess: { [sessionManager] session in
                sessionManager.didLogin(session)
            }
        )
    }

    func makeCourseListViewModel() -> CourseListViewModel {
        CourseListViewModel(repository: courseRepository)
    }

    func makeCourseDetailViewModel(for course: Course) -> CourseDetailViewModel {
        CourseDetailViewModel(course: course, repository: courseRepository)
    }
}
