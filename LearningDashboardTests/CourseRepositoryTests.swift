//
//  CourseRepositoryTests.swift
//  LearningDashboardTests
//

import XCTest
@testable import LearningDashboard

/// The offline requirement and the optimistic-update logic live in the repository,
/// so this is where the most valuable tests are.
final class CourseRepositoryTests: XCTestCase {

    private var api: FakeAPIClient!
    private var cache: InMemoryCourseCache!
    private var repository: CourseRepository!

    override func setUp() {
        super.setUp()
        api = FakeAPIClient()
        cache = InMemoryCourseCache()
        repository = CourseRepository(apiClient: api, cache: cache, now: { Date(timeIntervalSince1970: 1_000) })

        api.stub(.get, "/courses", .json(Fixtures.json(Fixtures.courses)))
        api.stub(.get, "/courses/1", .json(Fixtures.json(Fixtures.pythonDetail(completed: [1, 2]))))
    }

    // MARK: - Courses / offline

    func testCoursesFromNetworkAreReturnedAndCached() async throws {
        let result = try await repository.courses()

        XCTAssertEqual(result.source, .remote)
        XCTAssertEqual(result.value, Fixtures.courses)

        let saved = await cache.load()
        XCTAssertEqual(saved.courses, Fixtures.courses)
        XCTAssertEqual(saved.lastUpdated, Date(timeIntervalSince1970: 1_000))
    }

    func testPreviouslyLoadedCoursesAreStillAvailableOffline() async throws {
        _ = try await repository.courses()          // load once while online
        api.isOffline = true                        // "turn off the internet"

        let result = try await repository.courses()

        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.value, Fixtures.courses)
    }

    func testOfflineWithNothingCachedSurfacesTheError() async {
        api.isOffline = true

        do {
            _ = try await repository.courses()
            XCTFail("Expected an error: there is neither network nor saved data")
        } catch {
            XCTAssertEqual(error as? NetworkError, .noInternet)
        }
    }

    func testServerReturningZeroCoursesIsAnEmptyListNotAnError() async throws {
        api.stub(.get, "/courses", .json(Fixtures.json([Course]())))

        let result = try await repository.courses()

        XCTAssertTrue(result.value.isEmpty)
        XCTAssertEqual(result.source, .remote)
    }

    func testServerErrorFallsBackToSavedCoursesWhenAvailable() async throws {
        _ = try await repository.courses()
        api.stub(.get, "/courses", .failure(NetworkError.serverError(500)))

        let result = try await repository.courses()

        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.value, Fixtures.courses)
    }

    // MARK: - Completing lessons

    func testCompletingALessonOnlineUsesTheServerResponseAndUpdatesTheCourseList() async throws {
        _ = try await repository.courses()
        _ = try await repository.courseDetail(id: 1)
        api.stub(.post, "/courses/1/lessons/3/complete",
                 .json(Fixtures.json(Fixtures.pythonDetail(completed: [1, 2, 3]))))

        let result = try await repository.completeLesson(courseId: 1, lessonId: 3)

        XCTAssertTrue(result.isSynced)
        XCTAssertEqual(result.detail.progress, 75)

        let saved = await cache.load()
        XCTAssertEqual(saved.courses.first { $0.id == 1 }?.progress, 75, "list screen must see the new progress")
        XCTAssertTrue(saved.pendingCompletions.isEmpty)
    }

    func testCompletingALessonOfflineKeepsTheChangeAndQueuesItForLater() async throws {
        _ = try await repository.courses()
        _ = try await repository.courseDetail(id: 1)
        api.isOffline = true

        let result = try await repository.completeLesson(courseId: 1, lessonId: 3)

        XCTAssertFalse(result.isSynced)
        XCTAssertEqual(result.detail.progress, 75)

        let saved = await cache.load()
        XCTAssertEqual(saved.pendingCompletions, [PendingCompletion(courseId: 1, lessonId: 3)])
        XCTAssertEqual(saved.courses.first { $0.id == 1 }?.progress, 75)
    }

    func testQueuedCompletionsAreSentWhenTheNetworkReturns() async throws {
        _ = try await repository.courses()
        _ = try await repository.courseDetail(id: 1)
        api.isOffline = true
        _ = try await repository.completeLesson(courseId: 1, lessonId: 3)

        api.isOffline = false
        api.stub(.post, "/courses/1/lessons/3/complete",
                 .json(Fixtures.json(Fixtures.pythonDetail(completed: [1, 2, 3]))))
        await repository.syncPendingCompletions()

        let saved = await cache.load()
        XCTAssertTrue(saved.pendingCompletions.isEmpty)
        XCTAssertEqual(api.requestCount(.post, "/courses/1/lessons/3/complete"), 2) // failed once offline, then delivered
        XCTAssertEqual(saved.details.first?.progress, 75)
    }

    func testRefreshingWhileChangesArePendingDoesNotEraseThem() async throws {
        _ = try await repository.courses()
        _ = try await repository.courseDetail(id: 1)
        api.isOffline = true
        _ = try await repository.completeLesson(courseId: 1, lessonId: 3)

        // Back online, but the sync POST still fails (server hiccup), while GETs return the stale 50%.
        api.isOffline = false
        api.stub(.post, "/courses/1/lessons/3/complete", .failure(NetworkError.serverError(503)))
        let detail = try await repository.courseDetail(id: 1)
        let courses = try await repository.courses()

        XCTAssertEqual(detail.value.progress, 75)
        XCTAssertEqual(courses.value.first { $0.id == 1 }?.progress, 75)
    }

    func testRejectedCompletionIsRolledBackAndTheErrorIsThrown() async throws {
        _ = try await repository.courses()
        _ = try await repository.courseDetail(id: 1)
        api.stub(.post, "/courses/1/lessons/3/complete", .failure(NetworkError.serverError(500)))

        do {
            _ = try await repository.completeLesson(courseId: 1, lessonId: 3)
            XCTFail("Expected the server error to be rethrown")
        } catch {
            XCTAssertEqual(error as? NetworkError, .serverError(500))
        }

        let saved = await cache.load()
        XCTAssertEqual(saved.details.first?.progress, 50)
        XCTAssertEqual(saved.courses.first { $0.id == 1 }?.progress, 50)
        XCTAssertTrue(saved.pendingCompletions.isEmpty)
    }

    func testCompletingAnAlreadyCompletedLessonDoesNotHitTheNetwork() async throws {
        _ = try await repository.courseDetail(id: 1)

        let result = try await repository.completeLesson(courseId: 1, lessonId: 1)

        XCTAssertTrue(result.isSynced)
        XCTAssertEqual(api.requestCount(.post, "/courses/1/lessons/1/complete"), 0)
    }
}
