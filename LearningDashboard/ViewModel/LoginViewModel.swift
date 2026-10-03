//
//  LoginViewModel.swift
//  LearningDashboard
//

import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {

    var email = ""
    var password = ""

    private(set) var isLoading = false
    /// Server / network failure (e.g. wrong credentials).
    private(set) var errorMessage: String?
    /// Field-level validation messages.
    private(set) var emailError: String?
    private(set) var passwordError: String?

    @ObservationIgnored private let authRepository: AuthRepositoryProtocol
    @ObservationIgnored private let onLoginSuccess: (AuthSession) -> Void
    @ObservationIgnored private var hasAttemptedSubmit = false

    init(
        authRepository: AuthRepositoryProtocol,
        onLoginSuccess: @escaping (AuthSession) -> Void
    ) {
        self.authRepository = authRepository
        self.onLoginSuccess = onLoginSuccess
    }

    func login() async {
        guard !isLoading else { return }

        hasAttemptedSubmit = true
        errorMessage = nil
        guard validate() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await authRepository.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            onLoginSuccess(session)
        } catch {
            errorMessage = error.userMessage
        }
    }

    /// Called as the user types: clears stale errors, and re-validates once they have tried to submit
    /// (so we never shout "invalid email" at someone who has only typed one character).
    func inputChanged() {
        errorMessage = nil
        if hasAttemptedSubmit { _ = validate() }
    }

    @discardableResult
    private func validate() -> Bool {
        emailError = LoginValidator.emailError(email)
        passwordError = LoginValidator.passwordError(password)
        return emailError == nil && passwordError == nil
    }
}
