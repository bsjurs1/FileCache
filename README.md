# URLCache 

URLCache is a simple and modern Swift based tool to make it easy to fetch and cache data using the async/await pattern on Apple platforms.

A simple example of how to use it looks like this:

```
import URLCache

let cache = try URLCache(policy: .init(maxItems: 100, expiration: .never))
let data = try await cache.fetch(url)
```

The `URLCache` has a few public methods that you can use:

`fetch(_ url: URL)`

A more comprehensive practical usage example is something like this:

```
struct PDFDownloadClient {
    private let cache: URLCache

    init() throws {
        self.cache = try URLCache(policy: .init(maxItems: 100, expiration: .never))
    }
    
    func fetchPDF(url: URL) async throws -> PDFDocument {
        let data = try await cache.fetch(url)
        guard let document = PDFDocument(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return document
    }
}
```
