//
//  Auth.swift
//  LearningDashboard
//

import Foundation

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
}

struct AuthSession: Equatable {
    let token: String
}
