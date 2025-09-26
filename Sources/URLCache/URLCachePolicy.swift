//
//  CachePolicy.swift
//
//  Created by Bjarte Sjursen on 25/09/2025.
//

import Foundation

public struct URLCachePolicy {
    let maxItems: Int
    let expiration: URLCacheExpirationPolicy
}
