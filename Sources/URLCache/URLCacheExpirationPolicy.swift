//
//  URLCacheExpirationPolicy.swift
//
//  Created by Bjarte Sjursen on 25/09/2025.
//

import Foundation

/// Expiration policy for `URLCache` objects, deciding how long it will take before elements are pruned from the cache.
public enum URLCacheExpirationPolicy {
    /// Elements will never expire from the cache
    case never
    /// Elements will expire from the cache after the provided number of `seconds`
    case timeInterval(TimeInterval)
    /// Elements will expire from the cache after the provided `years, months, days, seconds`
    case dateComponents(DateComponents)
}

extension URLCacheExpirationPolicy {
    /// Calculates the expiration date based on the policy and a starting point.
    /// - Parameters:
    ///   - startDate: Date when the cached item was created.
    ///   - calendar: Calendar used for `.dateComponents` calculations (defaults to `.current`).
    /// - Returns: The computed expiration `Date`, or `nil` for policies that never expire.
    public func expirationDate(
        since startDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .never:
            return nil
        case .timeInterval(let interval):
            return startDate.addingTimeInterval(interval)
        case .dateComponents(let components):
            return calendar.date(byAdding: components, to: startDate)
        }
    }
}
