//
//  LoadState.swift
//  LearningDashboard
//

import Foundation

/// Explicit screen state. A single enum makes impossible combinations
/// (e.g. "loading" and "failed" at once) unrepresentable.
enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
