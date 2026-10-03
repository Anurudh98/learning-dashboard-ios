//
//  NetworkMonitor.swift
//  LearningDashboard
//

import Foundation
import Network
import Observation

/// Observable connectivity for the UI. Combines the real network path (`NWPathMonitor`) with the
/// developer overrides used to demo offline / failure / empty scenarios against the mock backend.
@MainActor
@Observable
final class NetworkMonitor {

    /// Effective connectivity: real path is up AND not simulating offline.
    private(set) var isOnline = true
    private(set) var simulatedOffline = false
    private(set) var simulatedApiFailure = false
    private(set) var simulatedEmptyData = false

    /// Read by `MockAPIClient` from any thread.
    nonisolated let conditions: NetworkConditions

    @ObservationIgnored private let monitor = NWPathMonitor()

    init(conditions: NetworkConditions = NetworkConditions()) {
        self.conditions = conditions
        self.simulatedOffline = conditions.simulatesOffline
        self.simulatedApiFailure = conditions.simulatesApiFailure
        self.simulatedEmptyData = conditions.simulatesEmptyData
        self.isOnline = conditions.isOnline

        monitor.pathUpdateHandler = { [weak self] path in
            conditions.setPathSatisfied(path.status == .satisfied)
            Task { @MainActor in self?.refresh() }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    func setSimulatedOffline(_ value: Bool) {
        conditions.setSimulatedOffline(value)
        simulatedOffline = value
        refresh()
    }

    func setSimulatedApiFailure(_ value: Bool) {
        conditions.setSimulatedApiFailure(value)
        simulatedApiFailure = value
    }

    func setSimulatedEmptyData(_ value: Bool) {
        conditions.setSimulatedEmptyData(value)
        simulatedEmptyData = value
    }

    private func refresh() {
        isOnline = conditions.isOnline
    }
}
