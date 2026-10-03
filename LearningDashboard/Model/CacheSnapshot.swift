//
//  CacheSnapshot.swift
//  LearningDashboard
//

import Foundation

/// A lesson completion the user made that the server has not acknowledged yet.
struct PendingCompletion: Codable, Hashable {
    let courseId: Int
    let lessonId: Int
}

/// Everything persisted for offline use, stored as one small JSON document.
struct CacheSnapshot: Codable, Equatable {
    var courses: [Course] = []
    var details: [CourseDetail] = []
    var pendingCompletions: [PendingCompletion] = []
    /// `nil` means "never loaded successfully" - that is how offline-with-no-data is told apart
    /// from "loaded, and the server genuinely returned zero courses".
    var lastUpdated: Date?
}
