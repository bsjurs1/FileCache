import Testing
import Foundation
@testable import URLCache

@Test func testInit() async throws {
    let cache = try URLCache(policy: .init(maxItems: 20, expiration: .never))
}
