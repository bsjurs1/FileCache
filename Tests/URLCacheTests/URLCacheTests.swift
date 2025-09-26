import Testing
import Foundation
@testable import URLCache

//TODO: - Add tests and fill in more in readme
@Test func testInit() async throws {
    let cache = try URLCache(policy: .init(maxItems: 20, expiration: .never))
}
