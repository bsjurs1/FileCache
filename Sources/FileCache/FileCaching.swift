//
//  FileCaching.swift
//
//  Created by Bjarte Sjursen on 05/10/2025.
//

import Foundation

/// Abstraction for file caching so production code can use `FileCache`
/// while tests and previews can use an in-memory implementation.
public protocol FileCaching: AnyObject, Observable {
    @discardableResult
    func fetch(_ url: URL) async throws -> Data
    func add(_ data: Data, for url: URL) throws
    func getFileURLForCachedResource(at url: URL) -> URL?
    func removeCacheEntry(for url: URL)
    func removeAll() async throws
}
