# Architecture walkthrough

Companion to the 1-page README. Everything here describes what the code *actually does*, step by step, so it can be explained, modified and debugged in the interview.

---

## 1. Layers and who is allowed to talk to whom

```
┌──────────────────────────────────────────────────────────────────────────┐
│ View/            SwiftUI. Renders state, forwards taps. No logic.        │
│   RootView · LoginView · CourseListView · CourseDetailView · components  │
├──────────────────────────────────────────────────────────────────────────┤
│ ViewModel/       @MainActor @Observable. Owns UI state (LoadState etc.). │
│   LoginViewModel · CourseListViewModel · CourseDetailViewModel           │
├──────────────────────────────────────────────────────────────────────────┤
│ Repository/      Decides "network or cache", optimistic writes, queue.   │
│   CourseRepository (actor) · AuthRepository                              │
├───────────────────────────────┬──────────────────────────────────────────┤
│ Networking/                   │ Storage/                                 │
│   APIClientProtocol           │   CourseCacheProtocol                    │
│   ├─ MockAPIClient (default)  │   └─ FileCourseCache (actor, JSON file)  │
│   └─ APIClient (URLSession)   │   TokenStoreProtocol                     │
│   Endpoint · NetworkError     │   └─ KeychainTokenStore                  │
├───────────────────────────────┴──────────────────────────────────────────┤
│ Model/  Course · CourseDetail · Lesson · CacheSnapshot · LoadState …     │
│ Manager/ SessionManager (logged in?) · NetworkMonitor (online?)          │
│ App/    AppDependencies = composition root                               │
└──────────────────────────────────────────────────────────────────────────┘
Dependencies point downwards only. Every arrow crosses a protocol, so each layer is testable alone.
```

Mapping to the reference `MovieApp` project: `View/ ViewModel/ Repository/ Networking/ Model/ Manager/ App/ Config/` are the same folders with the same roles; `AppDependencies` is the same composition root injected through `.environment`. New here: `Storage/` (cache + keychain) because offline is a requirement.

---

## 2. Step by step: what actually happens

### 2.1 Launch
1. `LearningDashboardApp` creates `AppDependencies` → builds `NetworkMonitor`, `KeychainTokenStore`, `FileCourseCache`, `MockAPIClient`, the two repositories and `SessionManager`.
2. `SessionManager.init` asks `AuthRepository.restoreSession()` → reads the Keychain. Token found → `isAuthenticated == true`.
3. `RootView` shows `CourseListView` if authenticated, otherwise `LoginView`. There is no imperative navigation anywhere: **changing `session` changes the screen**.

### 2.2 Login
1. User types. `LoginViewModel.inputChanged()` clears the previous server error (and re-validates once they have tried to submit).
2. Tap *Log In* → `login()`: validate with `LoginValidator`. Invalid → field errors, **no network call**.
3. Valid → `isLoading = true` (button shows a spinner and is disabled) → `AuthRepository.login` → `MockAPIClient` waits 0.8 s, compares credentials.
4. Wrong credentials → `NetworkError.unauthorized` → `errorMessage = "Invalid email or password."` (error state).
5. Success → token saved in Keychain → `onLoginSuccess(session)` → `SessionManager.didLogin` → `RootView` swaps to the dashboard.

### 2.3 Loading the dashboard (online, first time)
1. `CourseListView.task` → `viewModel.onAppear()` → `load()`. Nothing on screen yet → `state = .loading` → spinner.
2. `CourseRepository.courses()`:
   a. `syncPendingCompletions()` (nothing queued yet).
   b. `apiClient.request(.courses)` → mock waits 0.7 s → returns `courses.json` content.
   c. `cache.update { … }` writes the list + timestamp into the snapshot (atomic, also persisted to disk).
   d. Returns `Sourced(value:, source: .remote)`.
3. ViewModel: `courses = …`, `state = .loaded`. View renders cards; zero courses → empty state view.

### 2.4 Offline (the requirement)
1. Courses were loaded once (step 2.3), so the snapshot on disk has them and `lastUpdated != nil`.
2. Network goes away (real: Wi-Fi off / Airplane; demo: *Simulate offline*). `NetworkMonitor.isOnline` flips → views show the **"You're offline"** banner.
3. User pulls to refresh (or relaunches). `courses()` → request throws `NetworkError.noInternet` → `catch` → snapshot has `lastUpdated` → returns `Sourced(value: snapshot.courses, source: .cache)`.
4. The list stays on screen. Had nothing ever been cached, the error is rethrown and the user gets the *error* state with "Try Again".
5. Network returns → `NetworkMonitor.isOnline` flips back → `CourseListView.onChange` triggers `refresh()` → fresh data replaces the saved copy, banner disappears.

Why `lastUpdated` instead of "cache non-empty"? It distinguishes *"server genuinely has zero courses"* (show the empty state) from *"we have never loaded"* (show the error).

### 2.5 Opening a course
`CourseCardView` (card **or** *Continue* button) → `path.append(course)` → `navigationDestination` builds `CourseDetailViewModel` via `AppDependencies` → `load()` → `repository.courseDetail(id:)` (same network-first / cache-fallback pattern; the detail is cached on success, so a course you opened once also works offline).

### 2.6 Mark a lesson completed — online
1. Tap *Mark Done* → `viewModel.complete(lessonId:)`.
2. **Optimistic UI**: `detail = current.completing(lessonId:)` — row flips to ✓ and progress recalculates *instantly* (`CourseDetail.completing` is a pure function: easy to test, trivial to roll back because it returns a copy).
3. `CourseRepository.completeLesson`:
   a. Writes the same change into the cache (so the **list screen** shows the new % when you go back).
   b. `POST …/complete` → mock updates its "database" and returns the new `CourseDetail`.
   c. The server's answer overwrites the optimistic copy (server is authoritative).
4. Back on the list: `onAppear` → `reloadFromCache()` → card shows the new progress.

### 2.7 Mark a lesson completed — offline
Steps 1–3a as above, then the request throws `noInternet`:
- the optimistic state is **kept**, the change is appended to `pendingCompletions` (persisted),
- the result is `isSynced = false` → blue banner *"Progress saved on this device. It will sync when you're back online."*
- when connectivity returns (or the next refresh): `syncPendingCompletions()` replays each item in order, removes it on success; a 4xx is dropped (server will never accept it); anything else stops and retries next time.
- while items are pending, a refresh **overlays** them on the server copy, so stale server data can never erase what the user did.

### 2.8 Mark a lesson completed — server rejects it (e.g. 500)
Repository restores the previous detail in the cache and rethrows → ViewModel restores its copy and sets `actionError` → alert *"Couldn't update lesson"*. State is consistent everywhere.

---

## 3. Decisions and trade-offs (talking points)

| Decision | Why | Trade-off / what I'd change at scale |
|---|---|---|
| MVVM + Repository, not full Clean Architecture | A use-case layer would just forward calls here | Add use cases when business rules span repositories |
| `LoadState` enum instead of `isLoading` + `error` + `items` flags | Impossible states can't exist | One more type |
| `actor CourseRepository` + atomic `cache.update` | Overlapping calls (refresh + completion) can't lose each other's writes — there is deliberately **no** `save(_:)` | Actor hop on each call (negligible) |
| JSON snapshot file for the cache | Assignment says "simple cache"; whole thing is a few KB; zero dependencies | Replace with SwiftData/SQLite + delta sync at scale (README §4) |
| Optimistic update + outbox | Taps are never lost; UI is instant even on slow networks | Needs idempotent server endpoint (it is: completing twice is a no-op) |
| One completion at a time in the ViewModel | Keeps optimistic state and saved state trivially consistent | Could allow concurrency with per-lesson tracking |
| Mock backend behind `APIClientProtocol` honours real connectivity | "Turn off the internet" actually works in the demo | Real `APIClient` is included but unexercised against a server |
| Keychain wired in even though auth is mocked | Shows the production answer, not just describes it | — |
| Progress is the server's value until the first completion | The sample JSON says 40% of 16 lessons, which isn't a whole number of lessons | After first completion it is recomputed: `round(completed / total × 100)` |

---

## 4. Tests (`⌘U`)

| File | What it protects |
|---|---|
| `ProgressAndModelTests` | rounding/clamping of progress; `completing(lessonId:)` (status change, recalculation, idempotent, unknown lesson); JSON shape from the assignment decodes |
| `CourseRepositoryTests` | **offline**: cached courses returned, error when nothing cached, empty-server ≠ error, 5xx falls back; **writes**: online completion updates list, offline completion queued, queue replayed on reconnect, refresh doesn't erase pending changes, server rejection rolls back, no network call for already-completed lesson |
| `ViewModelTests` | login validation + success/failure; list success/empty/error/cache/refresh-failure/return-from-detail; detail load/complete/offline flag/rollback |

---

## 5. Likely interview asks — where to change what

| "Can you…" | Do this |
|---|---|
| Add a **retry button** on the offline banner | `OfflineBanner` → add `Button` calling `viewModel.refresh()` |
| Change password rules | `LoginValidator` (+ its tests) |
| Show lessons count completed in the list | `CourseCardView.detailText` |
| Make a lesson **un-completable** | Add `uncompleting(lessonId:)` to `CourseDetail`, `Endpoint.uncompleteLesson`, repository method mirroring `completeLesson` |
| Swap in a real backend | `AppConfiguration.useMockBackend = false`, set `baseURL`; `APIClient` already adds the `Bearer` header from the Keychain |
| Replace the JSON cache with SwiftData | New type conforming to `CourseCacheProtocol`; change one line in `AppDependencies` |
| Debug "progress didn't update on the list" | `CourseRepository.store(_:in:)` is the single place that syncs detail → list; `CourseListViewModel.onAppear` → `reloadFromCache` |
| Debug "stuck on loading" | `CancellationError` handling in `CourseListViewModel.load` (pull-to-refresh can cancel the task) |
| Force each state | ⋯ menu → Mock backend, or launch args `-mock-offline -mock-api-failure -mock-empty` |

## 6. Demo video script (≤ 2 min)

1. **Login**: submit empty → field errors; wrong password → error banner; correct → spinner → dashboard. *(0:00–0:30)*
2. **Course list**: loading → 3 cards, progress bars, *Continue*. *(0:30–0:45)*
3. **Details**: open *Python Programming* → lessons; tap *Mark Done* on "Inheritance & Polymorphism" (first pending lesson, #14) → ✓, progress 65 → 70%. Go back → card shows 70%. *(0:45–1:15)*
4. **Offline**: ⋯ → *Simulate offline* (or Wi-Fi off) → banner; pull to refresh → list still there; open a course; mark a lesson → blue "saved on device" banner. *(1:15–1:45)*
5. **Reconnect**: toggle back → banner disappears, sync happens. *(1:45–2:00)*
