//
//  NetworkConditions.swift
//  LearningDashboard
//

import Foundation

/// Thread-safe flags that describe the network as the (mock) backend should see it.
///
/// `NetworkMonitor` (main actor, observable) owns and updates this; `MockAPIClient`
/// (arbitrary threads) reads it. A lock keeps both sides race-free.
final class NetworkConditions: @unchecked Sendable {

    private let lock = NSLock()
    private var pathSatisfied = true
    private var offlineOverride: Bool
    private var apiFailureOverride: Bool
    private var emptyDataOverride: Bool

    /// Launch arguments let you start the app directly in a failure scenario
    /// (Xcode > Scheme > Run > Arguments): `-mock-offline`, `-mock-api-failure`, `-mock-empty`.
    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        offlineOverride = arguments.contains("-mock-offline")
        apiFailureOverride = arguments.contains("-mock-api-failure")
        emptyDataOverride = arguments.contains("-mock-empty")
    }

    var isOnline: Bool { locked { pathSatisfied && !offlineOverride } }
    var simulatesOffline: Bool { locked { offlineOverride } }
    var simulatesApiFailure: Bool { locked { apiFailureOverride } }
    var simulatesEmptyData: Bool { locked { emptyDataOverride } }

    func setPathSatisfied(_ value: Bool) { locked { pathSatisfied = value } }
    func setSimulatedOffline(_ value: Bool) { locked { offlineOverride = value } }
    func setSimulatedApiFailure(_ value: Bool) { locked { apiFailureOverride = value } }
    func setSimulatedEmptyData(_ value: Bool) { locked { emptyDataOverride = value } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
