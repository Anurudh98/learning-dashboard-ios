//
//  AuthRepository.swift
//  LearningDashboard
//

import Foundation

final class AuthRepository: AuthRepositoryProtocol {

    private let apiClient: APIClientProtocol
    private let tokenStore: TokenStoreProtocol

    init(apiClient: APIClientProtocol, tokenStore: TokenStoreProtocol) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let response: LoginResponse = try await apiClient.request(.login(email: email, password: password))
        try tokenStore.saveToken(response.token)
        return AuthSession(token: response.token)
    }

    func restoreSession() -> AuthSession? {
        tokenStore.readToken().map { AuthSession(token: $0) }
    }

    func logout() {
        tokenStore.deleteToken()
    }
}
