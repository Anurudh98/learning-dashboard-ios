//
//  AuthRepositoryProtocol.swift
//  LearningDashboard
//

import Foundation

protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws -> AuthSession
    func restoreSession() -> AuthSession?
    func logout()
}
