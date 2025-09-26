//
//  URLCacheObject.swift
//
//  Created by Bjarte Sjursen on 25/09/2025.
//

import Foundation

public struct URLCacheObject: Codable, Equatable {
    let createdAt: Date
    let diskURL: URL
}
