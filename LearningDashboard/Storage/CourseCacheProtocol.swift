//
//  CourseCacheProtocol.swift
//  LearningDashboard
//

import Foundation

protocol CourseCacheProtocol {

    func load() async -> CacheSnapshot

    /// Atomic read-modify-write. The transform runs inside the cache's own isolation, so two
    /// concurrent callers can never overwrite each other with a stale copy
    /// (that is why there is deliberately no plain `save(_:)`).
    func update<R>(_ transform: @Sendable (inout CacheSnapshot) -> R) async -> R

    func clear() async
}
