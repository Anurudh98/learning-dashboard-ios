//
//  MockAPIClient.swift
//  LearningDashboard
//

import Foundation

/// In-process fake server. It sits behind `APIClientProtocol`, so the repositories and everything
/// above them behave exactly as they would against a real backend: latency, auth errors,
/// offline errors, server errors and server-side state that changes when a lesson is completed.
final class MockAPIClient: APIClientProtocol {

    static let validEmail = "demo@learning.com"
    static let validPassword = "Password@123"

    private let state: MockBackendState
    private let conditions: NetworkConditions

    init(bundle: Bundle = .main, conditions: NetworkConditions) {
        self.conditions = conditions
        self.state = MockBackendState(
            courses: MockAPIClient.loadCourses(from: bundle),
            lessonTitles: MockAPIClient.loadLessonTitles(from: bundle)
        )
    }

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        as responseType: T.Type
    ) async throws -> T {

        // Like a real device: when there is no network the request fails immediately.
        guard conditions.isOnline else { throw NetworkError.noInternet }

        try await Task.sleep(for: latency(for: endpoint))

        // The network may have dropped while the "request" was in flight.
        guard conditions.isOnline else { throw NetworkError.noInternet }

        let parts = endpoint.path.split(separator: "/").map(String.init)

        if endpoint.method == .post, parts == ["auth", "login"] {
            return try login(endpoint, as: T.self)
        }

        if endpoint.method == .get, parts == ["courses"] {
            if conditions.simulatesApiFailure { throw NetworkError.serverError(500) }
            if conditions.simulatesEmptyData { return try respond([Course](), as: T.self) }
            return try respond(await state.courses(), as: T.self)
        }

        if endpoint.method == .get, parts.count == 2, parts[0] == "courses", let courseId = Int(parts[1]) {
            if conditions.simulatesApiFailure { throw NetworkError.serverError(500) }
            guard let detail = await state.detail(courseId: courseId) else { throw NetworkError.serverError(404) }
            return try respond(detail, as: T.self)
        }

        if endpoint.method == .post,
           parts.count == 5, parts[0] == "courses", parts[2] == "lessons", parts[4] == "complete",
           let courseId = Int(parts[1]), let lessonId = Int(parts[3]) {
            guard let detail = await state.complete(courseId: courseId, lessonId: lessonId) else {
                throw NetworkError.serverError(404)
            }
            return try respond(detail, as: T.self)
        }

        throw NetworkError.serverError(404)
    }

    // MARK: - Routes

    private func login<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) throws -> T {
        guard
            let body = endpoint.body,
            let credentials = try? JSONDecoder().decode(LoginRequest.self, from: body)
        else { throw NetworkError.serverError(400) }

        guard
            credentials.email.lowercased() == MockAPIClient.validEmail,
            credentials.password == MockAPIClient.validPassword
        else { throw NetworkError.unauthorized }

        return try respond(LoginResponse(token: "mock-token-\(UUID().uuidString)"), as: T.self)
    }

    // MARK: - Helpers

    private func latency(for endpoint: Endpoint) -> Duration {
        switch endpoint.method {
        case .post where endpoint.path.hasSuffix("/complete"): return .milliseconds(400)
        case .post: return .milliseconds(800)
        case .get: return .milliseconds(700)
        }
    }

    /// Encode the server model to JSON and decode it as whatever the caller asked for -
    /// the same path a real response body would take.
    private func respond<R: Encodable, T: Decodable>(_ value: R, as type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(value)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    private static func loadCourses(from bundle: Bundle) -> [Course] {
        guard
            let url = bundle.url(forResource: "courses", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let courses = try? JSONDecoder().decode([Course].self, from: data)
        else { return [] }
        return courses
    }

    private static func loadLessonTitles(from bundle: Bundle) -> [Int: [String]] {
        guard
            let url = bundle.url(forResource: "lessons", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }

        var titles: [Int: [String]] = [:]
        for (key, value) in raw {
            if let id = Int(key) { titles[id] = value }
        }
        return titles
    }
}

/// The fake server's database. An actor, because requests can overlap.
actor MockBackendState {

    private let baseCourses: [Course]
    private let titles: [Int: [String]]
    private var completed: [Int: Set<Int>] = [:]
    /// Courses the user has changed. Until then the server reports the progress from the JSON
    /// verbatim (e.g. 40% of 16 lessons cannot be represented exactly by whole lessons).
    private var touched: Set<Int> = []

    init(courses: [Course], lessonTitles: [Int: [String]]) {
        self.baseCourses = courses
        self.titles = lessonTitles

        for course in courses {
            let total = lessonTitles[course.id]?.count ?? course.lessonCount
            let done = ProgressCalculator.completedCount(forProgress: course.progress, total: total)
            completed[course.id] = Set((0..<done).map { $0 + 1 })
        }
    }

    func courses() -> [Course] {
        baseCourses.map(course(for:))
    }

    func detail(courseId: Int) -> CourseDetail? {
        guard
            let base = baseCourses.first(where: { $0.id == courseId }),
            let names = titles[courseId]
        else { return nil }

        let done = completed[courseId] ?? []
        let lessons = names.enumerated().map { index, name in
            Lesson(id: index + 1, title: name, isCompleted: done.contains(index + 1))
        }
        return CourseDetail(course: course(for: base), lessons: lessons)
    }

    func complete(courseId: Int, lessonId: Int) -> CourseDetail? {
        guard let names = titles[courseId], lessonId >= 1, lessonId <= names.count else { return nil }
        completed[courseId, default: []].insert(lessonId)
        touched.insert(courseId)
        return detail(courseId: courseId)
    }

    private func course(for base: Course) -> Course {
        guard touched.contains(base.id) else { return base }
        var course = base
        course.progress = ProgressCalculator.percentage(
            completed: completed[base.id]?.count ?? 0,
            total: base.lessonCount
        )
        return course
    }
}
