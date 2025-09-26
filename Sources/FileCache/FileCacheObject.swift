//
//  FileCacheObject.swift
//
//  Created by Bjarte Sjursen on 25/09/2025.
//

import Foundation

public struct FileCacheObject: Codable, Equatable {
    let createdAt: Date
    let diskURL: URL

    public init(createdAt: Date, diskURL: URL) {
        self.createdAt = createdAt
        self.diskURL = diskURL
    }
}
