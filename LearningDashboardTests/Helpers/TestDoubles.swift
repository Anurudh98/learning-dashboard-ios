//
//  TestDoubles.swift
//  LearningDashboardTests
//

import Foundation
@testable import LearningDashboard

// MARK: - Fixtures

enum Fixtures {

    static let python = Course(id: 1, title: "Python", instructor: "John Smith", progress: 50, lessonCount: 4)
    static let ai = Course(id: 2, title: "Generative AI", instructor: "Sarah Williams", progress: 0, lessonCount: 2)
    static let courses = [python, ai]

    /// Course 1 with 4 lessons, `completed` ids done. Progress mirrors the completed share.
    static func pythonDetail(completed: Set<Int> = [1, 2]) -> CourseDetail {
        let lessons = (1...4).map { Lesson(id: $0, title: "Lesson \($0)", isCompleted: completed.contains($0)) }
        var course = python
        course.progress = ProgressCalculator.percentage(completed: completed.count, total: 4)
        return CourseDetail(course: course, lessons: lessons)
    }

    static func json<T: Encodable>(_ value: T) -> Data {
        // Force-try is acceptable in test fixtures: a failure here is a bug in the test itself.
        try! JSONEncoder().encode(value)
    }
}

// MARK: - API

/// Scriptable API client: register a JSON body or an error per "METHOD /path", flip `isOffline`.
final class FakeAPIClient: APIClientProtocol, @unchecked Sendable {

    enum Response {
        case json(Data)
        case failure(Error)
    }

    var isOffline = false
    private var routes: [String: Response] = [:]
    private(set) var requests: [Endpoint] = []

    func stub(_ method: HTTPMethod, _ path: String, _ response: Response) {
        routes["\(method.rawValue) \(path)"] = response
    }

    func requestCount(_ method: HTTPMethod, _ path: String) -> Int {
        requests.filter { $0.method == method && $0.path == path }.count
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as responseType: T.Type) async throws -> T {
        requests.append(endpoint)

        if isOffline { throw NetworkError.noInternet }

        guard let response = routes["\(endpoint.method.rawValue) \(endpoint.path)"] else {
            throw NetworkError.serverError(404)
        }

        switch response {
        case .failure(let error):
            throw error
        case .json(let data):
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

// MARK: - Cache

actor InMemoryCourseCache: CourseCacheProtocol {

    private var snapshot: CacheSnapshot

    init(_ snapshot: CacheSnapshot = CacheSnapshot()) {
        self.snapshot = snapshot
    }

    func load() -> CacheSnapshot { snapshot }

    func update<R>(_ transform: @Sendable (inout CacheSnapshot) -> R) -> R {
        transform(&snapshot)
    }

    func clear() { snapshot = CacheSnapshot() }
}

// MARK: - Repositories

final class StubCourseRepository: CourseRepositoryProtocol, @unchecked Sendable {

    var coursesResult: Result<Sourced<[Course]>, Error> = .success(Sourced(value: [], source: .remote))
    var cachedResult: [Course] = []
    var detailResult: Result<Sourced<CourseDetail>, Error> = .failure(NetworkError.noInternet)
    var completionResult: Result<LessonCompletionResult, Error> = .failure(NetworkError.noInternet)
    var hasPending = false

    private(set) var completeCalls: [(courseId: Int, lessonId: Int)] = []
    private(set) var syncCallCount = 0

    func courses() async throws -> Sourced<[Course]> { try coursesResult.get() }

    func cachedCourses() async -> [Course] { cachedResult }

    func courseDetail(id: Int) async throws -> Sourced<CourseDetail> { try detailResult.get() }

    func completeLesson(courseId: Int, lessonId: Int) async throws -> LessonCompletionResult {
        completeCalls.append((courseId, lessonId))
        return try completionResult.get()
    }

    func syncPendingCompletions() async { syncCallCount += 1 }

    func hasPendingCompletions(courseId: Int) async -> Bool { hasPending }

    func clearLocalData() async {}
}

final class StubAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {

    var loginResult: Result<AuthSession, Error> = .success(AuthSession(token: "token"))
    private(set) var loginCallCount = 0
    private(set) var lastCredentials: (email: String, password: String)?

    func login(email: String, password: String) async throws -> AuthSession {
        loginCallCount += 1
        lastCredentials = (email, password)
        return try loginResult.get()
    }

    func restoreSession() -> AuthSession? { nil }

    func logout() {}
}
