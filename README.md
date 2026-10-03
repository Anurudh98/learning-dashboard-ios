# Learning Dashboard (iOS · SwiftUI)

Login → Course Dashboard → Course Details, with offline support.
**Swift 5 · SwiftUI · `@Observable` · async/await · no third-party dependencies.** Requires Xcode 16+ / iOS 17+.

## Run it

1. `open LearningDashboard.xcodeproj` → scheme **LearningDashboard** → any iPhone simulator → **⌘R**
2. Log in with **`demo@learning.com` / `Password@123`** (the backend is an in-process mock with realistic latency and errors).
3. Tests: **⌘U** (`LearningDashboardTests`).

**Demoing the states** — top-right **⋯ menu → Mock backend**: *Simulate offline*, *Simulate API failure*, *Simulate empty list*, *Clear saved data & reload*.
Turning off Wi-Fi / Airplane Mode is honoured too (the mock reads the real `NWPathMonitor`), but the menu toggle is the most reliable on the Simulator. Launch arguments: `-mock-offline`, `-mock-api-failure`, `-mock-empty`.

## Architecture

```
SwiftUI View ─► ViewModel (@Observable, @MainActor) ─► Repository ─┬─► APIClientProtocol  (MockAPIClient | URLSession APIClient)
                                                                   └─► CourseCacheProtocol (FileCourseCache, JSON in Application Support)
AppDependencies = composition root (injected via SwiftUI environment)
```

Folders mirror the reference project: `App/ Config/ Manager/ Model/ Networking/ Repository/ Storage/ ViewModel/ View/`.
Deeper walkthrough (step-by-step flows, trade-offs, interview notes): [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## 1. Architecture — why?

MVVM + Repository, everything behind protocols. Views only render a `LoadState` (`idle / loading / loaded / failed`), so loading/success/empty/error are mutually exclusive by construction. ViewModels hold UI state and contain no I/O; the repository is the only place that knows about "network first, fall back to cache". Because `APIClientProtocol`/`CourseRepositoryProtocol` are protocols, tests use fakes and the mock backend can be replaced by the real client by flipping one flag. Chosen over full Clean Architecture because a use-case layer would be pure pass-through at this size.

## 2. Offline support

`CourseRepository` is network-first and writes every successful response (courses, details, pending changes) into one JSON snapshot, held in an `actor` (thread-safe, atomic read-modify-write, atomic file writes, corrupt file → empty cache). If the request fails and a snapshot exists, the UI shows the saved data with an "offline" banner. Lesson completion is **optimistic**: saved locally first, then sent; if offline it is queued and replayed when connectivity returns, and refreshes never overwrite queued changes.

## 3. Security — where do tokens go?

In the **Keychain** (`kSecClassGenericPassword`, `AfterFirstUnlockThisDeviceOnly`) — never `UserDefaults` or files. Production: short-lived access token in memory, refresh token in the Keychain (optionally behind biometrics), single-flight refresh on 401, wipe token + cached data on logout. `KeychainTokenStore` is already wired in; TLS/ATS on, optional certificate pinning.

## 4. Scale — 1M users, hundreds of courses

1. **Paginated, summary-only list endpoint** + lazy-loaded lessons; server-side search/filter.
2. **Real database** (SwiftData/SQLite, normalized lessons, per-user) and **delta sync** (`updatedAt` / ETag) instead of one JSON snapshot.
3. **Durable outbox** for writes: idempotency keys, exponential backoff + jitter, `BGTaskScheduler`, server-authoritative conflict rules.
4. **Auth hardening**: refresh-token rotation, 401 interceptor, remote session revocation.
5. **Operability**: CDN-cached catalogue + image cache, MetricKit/crash/perf telemetry, feature flags, staged rollouts, contract tests against the API.

## 5. Second platform — Android

Kotlin + Jetpack Compose, same layering: `@Composable` screens collect `StateFlow<UiState>` from a Hilt-injected `ViewModel`; a `CourseRepository` combines **Retrofit/OkHttp + kotlinx.serialization** with a **Room** database exposed as `Flow` (Room is the single source of truth, so offline is free and the list updates reactively after a lesson is completed). Pending completions go in an outbox table drained by **WorkManager** (network-constrained). Tokens in **EncryptedSharedPreferences / Android Keystore**. Navigation Compose with a route per screen; tests with JUnit + MockK + Turbine, `MockWebServer` for the API.

## Known limitations (deliberate, 3-hour scope)

Mock auth only; no token refresh; completion queue is not retried in the background (it replays on the next refresh/reconnect); JSON snapshot cache is not encrypted; lesson "undo" is not supported.
