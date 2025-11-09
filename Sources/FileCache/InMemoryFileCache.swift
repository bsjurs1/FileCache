//
//  InMemoryFileCache.swift
//
//  Created by Bjarte Sjursen on 05/10/2025.
//

import Foundation
import Observation

/// A lightweight in-memory implementation of `FileCaching`
/// for tests and SwiftUI previews. No network or disk I/O.
/// Note: `getFileURLForCachedResource(at:)` returns `nil` since no files are written.
@Observable
public final class InMemoryFileCache: FileCaching {
    public enum Behavior {
        case data(Data)
        case error(Error)
        case delayed(TimeInterval, Data)
    }

    private var storage: [URL: Data] = [:]
    private var behaviors: [URL: Behavior] = [:]

    // Useful for verification in tests
    public private(set) var fetchCalls: [URL] = []
    public private(set) var removeCalls: [URL] = []

    public init() { }

    /// Seed known data for a URL (great for previews)
    public func seed(_ data: Data, for url: URL) {
        storage[url] = data
    }

    /// Script per-URL behavior for tests (success, error, artificial delay)
    public func setBehavior(_ behavior: Behavior, for url: URL) {
        behaviors[url] = behavior
    }

    @discardableResult
    public func fetch(_ url: URL) async throws -> Data {
        fetchCalls.append(url)

        if let behavior = behaviors[url] {
            switch behavior {
            case .data(let data):
                storage[url] = data
                return data
            case .error(let error):
                throw error
            case .delayed(let delay, let data):
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                storage[url] = data
                return data
            }
        }

        if let data = storage[url] {
            return data
        } else {
            throw URLError(.resourceUnavailable)
        }
    }
    
    public func add(_ data: Data, for url: URL) throws {
        storage[url] = data
    }

    /// Purely in-memory: returns `nil` because no file URL exists.
    public func getFileURLForCachedResource(at url: URL) -> URL? {
        nil
    }

    public func removeCacheEntry(for url: URL) {
        removeCalls.append(url)
        storage.removeValue(forKey: url)
        behaviors.removeValue(forKey: url)
    }

    public func removeAll() async throws {
        storage.removeAll()
        behaviors.removeAll()
    }
}
