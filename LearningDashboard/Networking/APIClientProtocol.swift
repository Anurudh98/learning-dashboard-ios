//
//  APIClientProtocol.swift
//  LearningDashboard
//

import Foundation

protocol APIClientProtocol {
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        as responseType: T.Type
    ) async throws -> T
}

extension APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await request(endpoint, as: T.self)
    }
}
