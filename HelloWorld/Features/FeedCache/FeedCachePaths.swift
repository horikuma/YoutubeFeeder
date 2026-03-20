import Foundation

enum FeedCachePaths {
    nonisolated static func baseDirectory(fileManager: FileManager = .default) -> URL {
        if let override = ProcessInfo.processInfo.environment["HELLOWORLD_FEEDCACHE_BASE_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("FeedCache", isDirectory: true)
    }

    nonisolated static func thumbnailsDirectory(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("thumbnails", isDirectory: true)
    }

    nonisolated static func thumbnailURL(filename: String, fileManager: FileManager = .default) -> URL {
        thumbnailsDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }

    nonisolated static func bootstrapURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("maintenance-bootstrap.json")
    }

    nonisolated static func cacheURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("cache.json")
    }

    nonisolated static func cacheSummaryURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("cache-summary.plist")
    }

    nonisolated static func channelRegistryURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("channel-registry.json")
    }

    nonisolated static func remoteSearchCacheURL(keyword: String, fileManager: FileManager = .default) -> URL {
        let sanitizedKeyword = keyword
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .replacingOccurrences(of: "[^0-9a-z]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let filename = sanitizedKeyword.isEmpty ? "remote-search.json" : "remote-search-\(sanitizedKeyword).json"
        return baseDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }

    nonisolated static func remoteSearchCacheSummaryURL(keyword: String, fileManager: FileManager = .default) -> URL {
        let cacheURL = remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)
        let filename = cacheURL.deletingPathExtension().lastPathComponent + "-summary.plist"
        return baseDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }
}
