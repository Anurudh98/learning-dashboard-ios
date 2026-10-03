//
//  FileCourseCache.swift
//  LearningDashboard
//

import Foundation

/// Offline store: one small JSON document in Application Support, with an in-memory copy.
/// An actor serialises all access, so reads/writes are thread-safe by construction.
actor FileCourseCache: CourseCacheProtocol {

    private let fileURL: URL
    private var memory: CacheSnapshot?

    init(fileURL: URL = FileCourseCache.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("LearningDashboard", isDirectory: true)
            .appendingPathComponent("cache.json")
    }

    func load() -> CacheSnapshot {
        if let memory { return memory }
        let loaded = readFromDisk()
        memory = loaded
        return loaded
    }

    func update<R>(_ transform: @Sendable (inout CacheSnapshot) -> R) -> R {
        var snapshot = load()
        let result = transform(&snapshot)
        memory = snapshot
        writeToDisk(snapshot)
        return result
    }

    func clear() {
        memory = CacheSnapshot()
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Disk

    private func readFromDisk() -> CacheSnapshot {
        guard let data = try? Data(contentsOf: fileURL) else { return CacheSnapshot() }
        // A corrupt file must never brick the app: fall back to an empty cache.
        return (try? JSONDecoder().decode(CacheSnapshot.self, from: data)) ?? CacheSnapshot()
    }

    private func writeToDisk(_ snapshot: CacheSnapshot) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Cache is best-effort: a failed write must not break the user's flow.
            print("FileCourseCache: failed to persist cache - \(error.localizedDescription)")
        }
    }
}
