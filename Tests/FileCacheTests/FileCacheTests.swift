import Testing
import Foundation
@testable import FileCache

struct FileCacheTests {
    @Test func initializationFailsWhenDocumentsDirectoryIsMissing() {
        let policy = FileCachePolicy(maxItems: 1, expiration: .never)
        let fileManager = MissingDocumentsFileManager()

        do {
            _ = try FileCache(policy: policy, fileManager: fileManager)
            Issue.record("Expected initialization to throw an error")
        } catch let error as FileCacheError {
            #expect(error == .unableToCreateDocumentsURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func fetchStoresDataOnDisk() async throws {
        let fileManager = TemporaryFileManager()
        defer { fileManager.cleanup() }

        prepareMockURLProtocol()

        let cache = try FileCache(policy: .init(maxItems: 10, expiration: .never), fileManager: fileManager)
        let url = URL(string: "https://example.com/resource")!
        let payload = Data("payload".utf8)
        MockURLProtocol.enqueueResponse(for: url, data: payload)

        let data = try await cache.fetch(url)
        #expect(data == payload)

        let cacheDirectory = fileManager.documentsURL.appendingPathComponent("FileCache")
        let indexURL = cacheDirectory.appendingPathComponent("index.json")
        #expect(FileManager.default.fileExists(atPath: indexURL.path))

        let decodedIndex = try loadIndex(at: indexURL)
        #expect(decodedIndex[url] != nil)
        #expect(MockURLProtocol.requestCount(for: url) == 1)
    }

    @Test func fetchUsesStoredDataWhenNotExpired() async throws {
        let fileManager = TemporaryFileManager()
        defer { fileManager.cleanup() }

        prepareMockURLProtocol()

        let cache = try FileCache(policy: .init(maxItems: 10, expiration: .never), fileManager: fileManager)
        let url = URL(string: "https://example.com/static")!
        let payload = Data("static".utf8)
        MockURLProtocol.enqueueResponse(for: url, data: payload)

        let first = try await cache.fetch(url)
        #expect(first == payload)

        let second = try await cache.fetch(url)
        #expect(second == payload)
        #expect(MockURLProtocol.requestCount(for: url) == 1)
    }

    @Test func fetchRefetchesWhenEntryExpires() async throws {
        let fileManager = TemporaryFileManager()
        defer { fileManager.cleanup() }

        prepareMockURLProtocol()

        let cache = try FileCache(policy: .init(maxItems: 10, expiration: .timeInterval(0)), fileManager: fileManager)
        let url = URL(string: "https://example.com/ephemeral")!
        let firstPayload = Data("first".utf8)
        let secondPayload = Data("second".utf8)
        MockURLProtocol.enqueueResponse(for: url, data: firstPayload)
        MockURLProtocol.enqueueResponse(for: url, data: secondPayload)

        let first = try await cache.fetch(url)
        #expect(first == firstPayload)

        let second = try await cache.fetch(url)
        #expect(second == secondPayload)
        #expect(MockURLProtocol.requestCount(for: url) == 2)
    }

    @Test func removeCacheEntryDeletesDiskArtifacts() async throws {
        let fileManager = TemporaryFileManager()
        defer { fileManager.cleanup() }

        prepareMockURLProtocol()

        let cache = try FileCache(policy: .init(maxItems: 10, expiration: .never), fileManager: fileManager)
        let url = URL(string: "https://example.com/removable")!
        let payload = Data("removable".utf8)
        MockURLProtocol.enqueueResponse(for: url, data: payload)

        _ = try await cache.fetch(url)

        let cacheDirectory = fileManager.documentsURL.appendingPathComponent("FileCache")
        let indexURL = cacheDirectory.appendingPathComponent("index.json")
        var decodedIndex = try loadIndex(at: indexURL)
        #expect(decodedIndex[url] != nil)
        let diskURL = decodedIndex[url]!.diskURL
        #expect(FileManager.default.fileExists(atPath: diskURL.path))

        cache.removeCacheEntry(for: url)
        decodedIndex = try loadIndex(at: indexURL)
        #expect(decodedIndex[url] == nil)
        #expect(!FileManager.default.fileExists(atPath: diskURL.path))

        let updatedPayload = Data("updated".utf8)
        MockURLProtocol.enqueueResponse(for: url, data: updatedPayload)

        let data = try await cache.fetch(url)
        #expect(data == updatedPayload)
        #expect(MockURLProtocol.requestCount(for: url) == 2)
    }

    @Test func removeAllClearsCacheDirectory() async throws {
        let fileManager = TemporaryFileManager()
        defer { fileManager.cleanup() }

        prepareMockURLProtocol()

        let cache = try FileCache(policy: .init(maxItems: 10, expiration: .never), fileManager: fileManager)
        let firstURL = URL(string: "https://example.com/first")!
        let secondURL = URL(string: "https://example.com/second")!
        MockURLProtocol.enqueueResponse(for: firstURL, data: Data("first".utf8))
        MockURLProtocol.enqueueResponse(for: secondURL, data: Data("second".utf8))

        _ = try await cache.fetch(firstURL)
        _ = try await cache.fetch(secondURL)

        try await cache.removeAll()

        let cacheDirectory = fileManager.documentsURL.appendingPathComponent("FileCache")
        let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        #expect(contents.count == 1)
        let indexURL = cacheDirectory.appendingPathComponent("index.json")
        #expect(FileManager.default.fileExists(atPath: indexURL.path))
        let decodedIndex = try loadIndex(at: indexURL)
        #expect(decodedIndex.isEmpty)
    }

    @Test func cachePersistsAcrossInstances() async throws {
        let fileManager = TemporaryFileManager()
        defer { fileManager.cleanup() }

        prepareMockURLProtocol()

        let url = URL(string: "https://example.com/persistent")!
        let payload = Data("persistent".utf8)
        MockURLProtocol.enqueueResponse(for: url, data: payload)

        do {
            let cache = try FileCache(policy: .init(maxItems: 10, expiration: .never), fileManager: fileManager)
            let first = try await cache.fetch(url)
            #expect(first == payload)
        }

        let secondCache = try FileCache(policy: .init(maxItems: 10, expiration: .never), fileManager: fileManager)
        let second = try await secondCache.fetch(url)
        #expect(second == payload)
        #expect(MockURLProtocol.requestCount(for: url) == 1)
    }
}

private func loadIndex(at url: URL) throws -> [URL: FileCacheObject] {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([URL: FileCacheObject].self, from: data)
}

private let mockURLProtocolRegistration: Void = {
    MockURLProtocol.register()
    return ()
}()

private func prepareMockURLProtocol() {
    _ = mockURLProtocolRegistration
}

private final class MissingDocumentsFileManager: FileManager {
    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        []
    }
}

private final class TemporaryFileManager: FileManager {
    let documentsURL: URL
    private let rootURL: URL
    private var cleanedUp = false

    override init() {
        let baseURL = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("FileCacheTests-\(UUID().uuidString)")
        self.rootURL = baseURL
        self.documentsURL = baseURL
        super.init()
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        if directory == .documentDirectory {
            return [documentsURL]
        }
        return super.urls(for: directory, in: domainMask)
    }

    func cleanup() {
        guard !cleanedUp else { return }
        try? FileManager.default.removeItem(at: rootURL)
        cleanedUp = true
    }

    deinit {
        cleanup()
    }
}

private final class MockURLProtocol: URLProtocol {
    fileprivate struct Response {
        let response: HTTPURLResponse
        let data: Data
    }

    fileprivate enum MockError: Error {
        case missingHandler
    }

    private static let state = MockURLProtocolState()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let result = Self.state.nextResponse(for: url)

        switch result {
        case .success(let response):
            client?.urlProtocol(self, didReceive: response.response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }

    static func enqueueResponse(for url: URL, data: Data, statusCode: Int = 200, headers: [String: String]? = nil) {
        let response = Response(
            response: HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!,
            data: data
        )
        state.enqueue(.success(response), for: url)
    }

    static func enqueueError(for url: URL, error: Error) {
        state.enqueue(.failure(error), for: url)
    }

    static func requestCount(for url: URL) -> Int {
        state.requestCount(for: url)
    }

    static func register() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    static func teardown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        state.reset()
    }
}

private final class MockURLProtocolState: @unchecked Sendable {
    private var handlers: [URL: [Result<MockURLProtocol.Response, Error>]] = [:]
    private var counts: [URL: Int] = [:]
    private let lock = NSLock()

    func enqueue(_ result: Result<MockURLProtocol.Response, Error>, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        handlers[url, default: []].append(result)
    }

    func nextResponse(for url: URL) -> Result<MockURLProtocol.Response, Error> {
        lock.lock()
        defer { lock.unlock() }
        var queue = handlers[url] ?? []
        let result: Result<MockURLProtocol.Response, Error>
        if queue.isEmpty {
            result = .failure(MockURLProtocol.MockError.missingHandler)
        } else {
            result = queue.removeFirst()
            handlers[url] = queue
        }
        counts[url, default: 0] += 1
        return result
    }

    func requestCount(for url: URL) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[url] ?? 0
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
        counts.removeAll()
    }
}
