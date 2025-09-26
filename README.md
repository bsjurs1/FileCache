# FileCache

Disk-backed caching for async/await-powered network fetches on Apple platforms. `FileCache` wraps `URLSession` to transparently persist responses, enforce eviction policies, and keep your code focused on data processing instead of cache management.

## Features
- Async `fetch(_:)` that returns cached data instantly when available and refreshes transparently when needed
- Pluggable eviction policy via `FileCachePolicy` with size (`maxItems`) and expiration controls (`.never`, `.timeInterval`, `.dateComponents`)
- Automatic pruning of expired entries plus manual invalidation helpers (`removeCacheEntry`, `removeAll`)
- Persistent on-disk storage under the app's Documents directory so caches survive app restarts
- Safe defaults with the option to inject a custom `FileManager` for testing or advanced scenarios

## Requirements
- Swift 5.5 or newer
- iOS 15, macOS 12, tvOS 15, or watchOS 8 minimum deployment targets

## Installation
Add `FileCache` to your project using Swift Package Manager.

### Package.swift
```swift
// Inside dependencies
.package(url: "https://github.com/bsjurs1/FileCache", branch: "main"),

// Inside your target
.target(
    name: "MyFeature",
    dependencies: [
        .product(name: "FileCache", package: "FileCache")
    ]
)
```

### Xcode
1. In Xcode, choose **File ▸ Add Packages…**
2. Paste the repository URL (`https://github.com/bsjurs1/FileCache`)
3. Pick the `main` branch (or a tagged release when available) and add the library to your targets

## Quick Start
```swift
import FileCache

let cache = try FileCache(policy: .init(maxItems: 100, expiration: .never))
let url = URL(string: "https://example.com/resource.pdf")!
let data = try await cache.fetch(url)
```
The first call fetches data from the network and stores it to disk. Subsequent calls return the cached bytes as long as the entry has not expired.

## Configuration
`FileCachePolicy` controls how long entries are kept around:

```swift
let policy = FileCachePolicy(
    maxItems: 50, // keep up to 50 unique URLs before evicting the oldest
    expiration: .timeInterval(60 * 60 * 24) // expire a day after caching
)
let cache = try FileCache(policy: policy)
```

Supported expiration options:
- `.never`: entries stay until manually removed or evicted by `maxItems`
- `.timeInterval(TimeInterval)`: expire a fixed number of seconds after creation
- `.dateComponents(DateComponents)`: expire using calendar math (e.g. "after 1 month")

For more advanced setups, the initializer also accepts a custom `FileManager`, letting you direct storage to test-specific directories or shared containers.

## Manual Cache Management
```swift
// Remove a single item (also deletes the file on disk)
cache.removeCacheEntry(for: url)

// Flush everything and recreate the cache directory
try await cache.removeAll()
```

`fetch(_:)` throws standard `URLError`s when the network request fails. Initialization can throw `FileCacheError.unableToCreateDocumentsURL` if the cache directory cannot be created.

## How It Works
- Cached payloads are stored under `Documents/FileCache/` and tracked via a JSON index for quick lookups.
- Each call to `fetch(_:)` checks the index first; valid entries are loaded directly from disk.
- Expired entries are pruned lazily during fetches and at initialization.
- When the cache exceeds `maxItems`, the oldest entry is evicted automatically before storing the new response.

## Testing
This package ships with a comprehensive suite powered by the Swift Testing library. Run them with:
```bash
swift test
```

The tests cover persistence, eviction, expiration, manual invalidation, and error handling to serve as both verification and usage examples.

## License
FileCache is available under the MIT license. See the [`LICENSE`](LICENSE) file for details.
