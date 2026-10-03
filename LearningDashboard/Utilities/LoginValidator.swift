//
//  LoginValidator.swift
//  LearningDashboard
//

import Foundation

/// Pure, side-effect-free input validation (trivially unit-testable).
enum LoginValidator {

    static let minimumPasswordLength = 8

    static func emailError(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Email is required." }

        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            return "Enter a valid email address."
        }
        return nil
    }

    static func passwordError(_ password: String) -> String? {
        if password.isEmpty { return "Password is required." }
        if password.count < minimumPasswordLength {
            return "Password must be at least \(minimumPasswordLength) characters."
        }
        return nil
    }
}
