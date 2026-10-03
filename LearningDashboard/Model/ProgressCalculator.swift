//
//  ProgressCalculator.swift
//  LearningDashboard
//

import Foundation

enum ProgressCalculator {

    /// Whole-number percentage (0...100), rounded to nearest. Zero lessons -> 0.
    static func percentage(completed: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let clamped = min(max(completed, 0), total)
        return Int((Double(clamped) / Double(total) * 100).rounded())
    }

    /// Inverse helper, used only to seed the mock backend from a percentage.
    static func completedCount(forProgress progress: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let count = Int((Double(progress) * Double(total) / 100).rounded())
        return min(max(count, 0), total)
    }
}
