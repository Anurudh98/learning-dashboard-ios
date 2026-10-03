//
//  ViewModelTests.swift
//  LearningDashboardTests
//

import XCTest
@testable import LearningDashboard

// MARK: - Login

final class LoginValidatorTests: XCTestCase {

    func testEmailValidation() {
        XCTAssertNotNil(LoginValidator.emailError(""))
        XCTAssertNotNil(LoginValidator.emailError("   "))
        XCTAssertNotNil(LoginValidator.emailError("not-an-email"))
        XCTAssertNotNil(LoginValidator.emailError("a@b"))
        XCTAssertNil(LoginValidator.emailError("demo@learning.com"))
        XCTAssertNil(LoginValidator.emailError("  first.last+tag@sub.example.co  "))
    }

    func testPasswordValidation() {
        XCTAssertNotNil(LoginValidator.passwordError(""))
        XCTAssertNotNil(LoginValidator.passwordError("short"))
        XCTAssertNil(LoginValidator.passwordError("long-enough"))
    }
}

@MainActor
final class LoginViewModelTests: XCTestCase {

    private func makeSUT(
        auth: StubAuthRepository = StubAuthRepository(),
        onSuccess: @escaping (AuthSession) -> Void = { _ in }
    ) -> (LoginViewModel, StubAuthRepository) {
        (LoginViewModel(authRepository: auth, onLoginSuccess: onSuccess), auth)
    }

    func testInvalidInputShowsFieldErrorsAndNeverCallsTheServer() async {
        let (sut, auth) = makeSUT()
        sut.email = "nope"
        sut.password = "123"

        await sut.login()

        XCTAssertNotNil(sut.emailError)
        XCTAssertNotNil(sut.passwordError)
        XCTAssertEqual(auth.loginCallCount, 0)
        XCTAssertFalse(sut.isLoading)
    }

    func testSuccessfulLoginReportsTheSessionAndTrimsTheEmail() async {
        var received: AuthSession?
        let (sut, auth) = makeSUT { received = $0 }
        sut.email = "  demo@learning.com "
        sut.password = "Password@123"

        await sut.login()

        XCTAssertEqual(received, AuthSession(token: "token"))
        XCTAssertEqual(auth.lastCredentials?.email, "demo@learning.com")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testFailedLoginShowsTheErrorAndDoesNotNavigate() async {
        var didNavigate = false
        let auth = StubAuthRepository()
        auth.loginResult = .failure(NetworkError.unauthorized)
        let (sut, _) = makeSUT(auth: auth) { _ in didNavigate = true }
        sut.email = "demo@learning.com"
        sut.password = "wrong-password"

        await sut.login()

        XCTAssertEqual(sut.errorMessage, "Invalid email or password.")
        XCTAssertFalse(didNavigate)
        XCTAssertFalse(sut.isLoading)
    }

    func testTypingClearsTheServerError() async {
        let auth = StubAuthRepository()
        auth.loginResult = .failure(NetworkError.unauthorized)
        let (sut, _) = makeSUT(auth: auth)
        sut.email = "demo@learning.com"
        sut.password = "wrong-password"
        await sut.login()
        XCTAssertNotNil(sut.errorMessage)

        sut.inputChanged()

        XCTAssertNil(sut.errorMessage)
    }
}

// MARK: - Course list

@MainActor
final class CourseListViewModelTests: XCTestCase {

    func testSuccessShowsCourses() async {
        let repo = StubCourseRepository()
        repo.coursesResult = .success(Sourced(value: Fixtures.courses, source: .remote))
        let sut = CourseListViewModel(repository: repo)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.courses, Fixtures.courses)
        XCTAssertEqual(sut.dataSource, .remote)
    }

    func testEmptyResponseIsLoadedWithNoCourses() async {
        let repo = StubCourseRepository()
        repo.coursesResult = .success(Sourced(value: [], source: .remote))
        let sut = CourseListViewModel(repository: repo)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertTrue(sut.courses.isEmpty)   // the view renders this as the empty state
    }

    func testFailureWithNothingToShowIsAnErrorState() async {
        let repo = StubCourseRepository()
        repo.coursesResult = .failure(NetworkError.serverError(500))
        let sut = CourseListViewModel(repository: repo)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .failed("The server returned an error (code 500)."))
    }

    func testSavedDataIsFlaggedAsComingFromTheCache() async {
        let repo = StubCourseRepository()
        repo.coursesResult = .success(Sourced(value: Fixtures.courses, source: .cache))
        let sut = CourseListViewModel(repository: repo)

        await sut.onAppear()

        XCTAssertEqual(sut.dataSource, .cache)
        XCTAssertEqual(sut.courses.count, 2)
    }

    func testFailedRefreshKeepsTheCoursesAlreadyOnScreen() async {
        let repo = StubCourseRepository()
        repo.coursesResult = .success(Sourced(value: Fixtures.courses, source: .remote))
        let sut = CourseListViewModel(repository: repo)
        await sut.onAppear()

        repo.coursesResult = .failure(NetworkError.noInternet)
        await sut.refresh()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.courses, Fixtures.courses)
        XCTAssertEqual(sut.dataSource, .cache)
    }

    func testReturningFromDetailPicksUpProgressSavedByTheDetailScreen() async {
        let repo = StubCourseRepository()
        repo.coursesResult = .success(Sourced(value: Fixtures.courses, source: .remote))
        let sut = CourseListViewModel(repository: repo)
        await sut.onAppear()

        var updated = Fixtures.python
        updated.progress = 75
        repo.cachedResult = [updated, Fixtures.ai]
        await sut.onAppear()   // second appearance = back from the detail screen

        XCTAssertEqual(sut.courses.first?.progress, 75)
    }
}

// MARK: - Course detail

@MainActor
final class CourseDetailViewModelTests: XCTestCase {

    private func loadedSUT(_ repo: StubCourseRepository) async -> CourseDetailViewModel {
        repo.detailResult = .success(Sourced(value: Fixtures.pythonDetail(completed: [1, 2]), source: .remote))
        let sut = CourseDetailViewModel(course: Fixtures.python, repository: repo)
        await sut.load()
        return sut
    }

    func testLoadShowsTheLessons() async {
        let sut = await loadedSUT(StubCourseRepository())

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.detail?.lessons.count, 4)
        XCTAssertEqual(sut.detail?.progress, 50)
    }

    func testLoadFailureWithNoSavedCopyIsAnErrorState() async {
        let repo = StubCourseRepository()
        repo.detailResult = .failure(NetworkError.noInternet)
        let sut = CourseDetailViewModel(course: Fixtures.python, repository: repo)

        await sut.load()

        XCTAssertEqual(sut.state, .failed("No internet connection. Please check your network and try again."))
    }

    func testMarkingALessonCompletedUpdatesStatusAndProgress() async {
        let repo = StubCourseRepository()
        let sut = await loadedSUT(repo)
        repo.completionResult = .success(
            LessonCompletionResult(detail: Fixtures.pythonDetail(completed: [1, 2, 3]), isSynced: true)
        )

        await sut.complete(lessonId: 3)

        XCTAssertEqual(sut.detail?.lessons.first { $0.id == 3 }?.isCompleted, true)
        XCTAssertEqual(sut.detail?.progress, 75)
        XCTAssertFalse(sut.hasUnsyncedChanges)
        XCTAssertNil(sut.completingLessonId)
    }

    func testCompletingOfflineShowsTheChangeAndFlagsItAsUnsynced() async {
        let repo = StubCourseRepository()
        let sut = await loadedSUT(repo)
        repo.completionResult = .success(
            LessonCompletionResult(detail: Fixtures.pythonDetail(completed: [1, 2, 3]), isSynced: false)
        )

        await sut.complete(lessonId: 3)

        XCTAssertEqual(sut.detail?.progress, 75)
        XCTAssertTrue(sut.hasUnsyncedChanges)
        XCTAssertNil(sut.actionError)
    }

    func testFailedCompletionRollsTheRowBackAndReportsTheError() async {
        let repo = StubCourseRepository()
        let sut = await loadedSUT(repo)
        repo.completionResult = .failure(NetworkError.serverError(500))

        await sut.complete(lessonId: 3)

        XCTAssertEqual(sut.detail?.lessons.first { $0.id == 3 }?.isCompleted, false)
        XCTAssertEqual(sut.detail?.progress, 50)
        XCTAssertEqual(sut.actionError, "The server returned an error (code 500).")
    }

    func testCompletedLessonsAreNotSentAgain() async {
        let repo = StubCourseRepository()
        let sut = await loadedSUT(repo)

        await sut.complete(lessonId: 1)   // already completed

        XCTAssertTrue(repo.completeCalls.isEmpty)
    }
}
