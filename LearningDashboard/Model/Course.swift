//
//  Course.swift
//  LearningDashboard
//

import Foundation

struct Course: Codable, Identifiable, Hashable {

    let id: Int
    let title: String
    let instructor: String
    /// 0...100
    var progress: Int
    let lessonCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, instructor, progress
        // The API calls the lesson *count* `lessons`.
        case lessonCount = "lessons"
    }

    var progressFraction: Double {
        Double(progress) / 100
    }
}
