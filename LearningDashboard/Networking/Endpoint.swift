//
//  Endpoint.swift
//  LearningDashboard
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct Endpoint: Equatable {

    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Data?

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
    }

    func urlRequest(baseURL: URL = AppConfiguration.baseURL, token: String? = nil) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidUrl
        }
        components.path += path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

extension Endpoint {

    static func login(email: String, password: String) -> Endpoint {
        let body = try? JSONEncoder().encode(LoginRequest(email: email, password: password))
        return Endpoint(path: "/auth/login", method: .post, body: body)
    }

    static var courses: Endpoint {
        Endpoint(path: "/courses")
    }

    static func courseDetail(id: Int) -> Endpoint {
        Endpoint(path: "/courses/\(id)")
    }

    static func completeLesson(courseId: Int, lessonId: Int) -> Endpoint {
        Endpoint(path: "/courses/\(courseId)/lessons/\(lessonId)/complete", method: .post)
    }
}
