//
//  AppConfiguration.swift
//  LearningDashboard
//

import Foundation

enum AppConfiguration {

    /// Base URL used by the real `APIClient` when `useMockBackend` is `false`.
    static let baseURL = URL(string: "https://api.learning-dashboard.example.com/v1")!

    /// The assignment allows a mocked backend. Flip this to `false` to talk to a real API;
    /// nothing else changes because every layer depends on `APIClientProtocol`.
    static let useMockBackend = true
}
