//
//  Sourced.swift
//  LearningDashboard
//

import Foundation

enum DataSource: Equatable {
    case remote
    case cache
}

/// A value together with where it came from, so the UI can say "showing saved data".
struct Sourced<Value> {
    let value: Value
    let source: DataSource
}
