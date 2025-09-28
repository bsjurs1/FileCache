//
//  FileCache.swift
//
//  Created by Bjarte Sjursen on 25/09/2025.
//

import Foundation
import Observation

/// A simple cache utility that will fetch files over the network and store them on disk based on the provided `FileCachePolicy`.
/// When files are requested the `FileCache` will always check if the url has been requested before, and return the stored object.
@Observable
public class FileCache {
    private let policy: FileCachePolicy
    private let fileManager: FileManager
    private let cacheDirectoryURL: URL
    private let indexURL: URL
    private var index: [URL: FileCacheObject] = [:] {
        didSet {
            guard index != oldValue else { return }
            saveIndex()
        }
    }
    
    /// Creates a new instance of `FileCache`
    /// - Parameters:
    ///   - policy: tells the cache how long to retain data
    ///   - fileManager: provide the desired filemanager to use for the cache
    public init(
        policy: FileCachePolicy,
        fileManager: FileManager = .default
    ) throws {
        self.policy = policy
        self.fileManager = fileManager

        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw FileCacheError.unableToCreateDocumentsURL
        }

        let cacheDirectoryURL = documentsURL.appendingPathComponent("FileCache")
        self.cacheDirectoryURL = cacheDirectoryURL
        self.indexURL = cacheDirectoryURL.appendingPathComponent("index.json")

        try createCacheDirectoryIfNeeded()
        self.index = loadIndex()
        pruneExpiredEntries()
    }
    
    private func createCacheDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: cacheDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private func loadIndex() -> [URL: FileCacheObject] {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode(
                [URL: FileCacheObject].self,
                from: data
            )
        } catch {
            return [:]
        }
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }

    private func isExpired(
        _ cacheObject: FileCacheObject,
        comparedTo date: Date = Date()
    ) -> Bool {
        guard let expirationDate = policy.expiration.expirationDate(
            since: cacheObject.createdAt
        ) else {
            return false
        }
        return expirationDate <= date
    }
    
    private func deleteCacheFile(at diskURL: URL) {
        if fileManager.fileExists(atPath: diskURL.path) {
            try? fileManager.removeItem(at: diskURL)
        }
    }

    /// Removes cache entry for file fetched from the provided url
    ///   - url: the universal resource locator pointing to a binary blob to fetch
    public func removeCacheEntry(for url: URL) {
        guard let cacheObject = index[url] else { return }
        deleteCacheFile(at: cacheObject.diskURL)
        index.removeValue(forKey: url)
    }

    private func store(
        _ data: Data,
        for url: URL
    ) throws {
        let fileType = url.pathExtension
        let uuidString = UUID().uuidString
        let filename = [uuidString, fileType].joined(separator: ".")
        let fileURL = cacheDirectoryURL.appendingPathComponent(filename)
        try data.write(to: fileURL, options: [.atomic])
        let now = Date()
        index[url] = FileCacheObject(createdAt: now, diskURL: fileURL)
    }

    private func pruneExpiredEntries(currentDate: Date = Date()) {
        guard !index.isEmpty else { return }

        var updatedIndex = index
        var hasRemovals = false

        for (url, cacheObject) in index {
            if isExpired(cacheObject, comparedTo: currentDate) {
                deleteCacheFile(at: cacheObject.diskURL)
                updatedIndex.removeValue(forKey: url)
                hasRemovals = true
            }
        }

        guard hasRemovals else { return }
        index = updatedIndex
    }

    /// Fetch a file using the provided url.
    /// When files are requested the `FileCache` will always check if the url has been requested before, and return the stored object if it exists on disk.
    /// - Parameters:
    ///   - url: the universal resource locator pointing to a binary blob to fetch
    public func fetch(_ url: URL) async throws -> Data {
        if let cacheObject = index[url] {
            if isExpired(cacheObject) {
                removeCacheEntry(for: url)
            } else if let data = try? Data(contentsOf: cacheObject.diskURL) {
                return data
            } else {
                removeCacheEntry(for: url)
            }
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        removeOldestCacheEntryIfNeeded()
        try store(data, for: url)
        return data
    }
    
    /// Get the local file url for a cached resource
    /// - Parameters:
    ///   - url: the universal resource locator pointing to a remote binary blob
    public func getFileURLForCachedResource(at url: URL) -> URL? {
        index[url]?.diskURL
    }

    private func removeOldestCacheEntryIfNeeded() {
        if policy.maxItems < index.count {
            removeOldestCacheEntry()
        }
    }
    
    private func removeOldestCacheEntry() {
        guard !index.isEmpty else { return }
        let oldestEntry = index.min { lhs, rhs in
            lhs.value.createdAt < rhs.value.createdAt
        }
        guard let (url, cacheObject) = oldestEntry else { return }
        deleteCacheFile(at: cacheObject.diskURL)
        index.removeValue(forKey: url)
    }
    
    /// Remove all entries from the cache
    public func removeAll() async throws {
        if fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            try fileManager.removeItem(at: cacheDirectoryURL)
        }
        try createCacheDirectoryIfNeeded()
        index = [:]
    }
}
