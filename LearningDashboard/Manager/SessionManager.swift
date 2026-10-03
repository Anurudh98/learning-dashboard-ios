//
//  SessionManager.swift
//  LearningDashboard
//

import Foundation
import Observation

/// Owns "is somebody logged in?". The root view switches between Login and the Dashboard on it.
@MainActor
@Observable
final class SessionManager {

    private(set) var session: AuthSession?

    @ObservationIgnored private let authRepository: AuthRepositoryProtocol
    @ObservationIgnored private let courseCache: CourseCacheProtocol

    init(authRepository: AuthRepositoryProtocol, courseCache: CourseCacheProtocol) {
        self.authRepository = authRepository
        self.courseCache = courseCache
        // Returning users with a Keychain token skip the login screen.
        self.session = authRepository.restoreSession()
    }

    var isAuthenticated: Bool {
        session != nil
    }

    func didLogin(_ session: AuthSession) {
        self.session = session
    }

    func logout() {
        authRepository.logout()
        session = nil
        // The previous user's data must not be visible to the next one.
        let cache = courseCache
        Task { await cache.clear() }
    }
}
