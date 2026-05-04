import XCTest
@testable import YoutubeFeeder

@MainActor
final class FeedCacheCoordinatorRemoteSearchTests: LoggedTestCase {
    func testLoadVideosForChannelDeduplicatesSameVideoIDAcrossFeedCacheAndRemoteSearch() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_DUPLICATE"
        let duplicateVideoID = "hxKe2aDUjZE"
        let olderDate = ISO8601DateFormatter().date(from: "2026-03-20T03:00:00Z")!
        let newerDate = ISO8601DateFormatter().date(from: "2026-03-21T03:00:00Z")!

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path
        ]) {
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(
                FeedCacheSnapshot(
                    savedAt: newerDate,
                    channels: [
                        CachedChannelState(
                            channelID: channelID,
                            channelTitle: "Local Channel",
                            lastAttemptAt: olderDate,
                            lastCheckedAt: olderDate,
                            lastSuccessAt: olderDate,
                            latestPublishedAt: olderDate,
                            cachedVideoCount: 1,
                            lastError: nil,
                            etag: nil,
                            lastModified: nil
                        )
                    ],
                    videos: [
                        CachedVideo(
                            id: duplicateVideoID,
                            channelID: channelID,
                            channelTitle: "Local Channel",
                            title: "local copy",
                            publishedAt: olderDate,
                            videoURL: URL(string: "https://example.com/watch?v=local"),
                            thumbnailRemoteURL: nil,
                            thumbnailLocalFilename: nil,
                            fetchedAt: olderDate,
                            searchableText: "local copy",
                            durationSeconds: 120,
                            viewCount: 10
                        )
                    ]
                )
            )

            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "duplicate",
                videos: [
                    CachedVideo(
                        id: duplicateVideoID,
                        channelID: channelID,
                        channelTitle: "Remote Channel",
                        title: "remote copy",
                        publishedAt: newerDate,
                        videoURL: URL(string: "https://example.com/watch?v=remote"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: newerDate,
                        searchableText: "remote copy",
                        durationSeconds: 180,
                        viewCount: 99
                    )
                ],
                totalCount: 1,
                fetchedAt: newerDate
            )

            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let videos = await coordinator.loadVideosForChannel(channelID)

            XCTAssertEqual(videos.count, 1)
            XCTAssertEqual(videos.first?.id, duplicateVideoID)
            XCTAssertEqual(videos.first?.title, "remote copy")
            XCTAssertEqual(videos.first?.channelTitle, "Remote Channel")
            XCTAssertEqual(videos.first?.publishedAt, newerDate)
        }
    }

    func testOpenChannelVideosUsesChannelFallbackWhenRemoteSearchHasOnlyOneVideo() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_REMOTE_FALLBACK"
        let selectedVideoID = "remote-only-1"
        let now = ISO8601DateFormatter().date(from: "2026-03-21T03:00:00Z")!

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "fallback-test",
                videos: [
                    CachedVideo(
                        id: selectedVideoID,
                        channelID: channelID,
                        channelTitle: "Remote Channel",
                        title: "single remote result",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=\(selectedVideoID)"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now,
                        searchableText: "single remote result",
                        durationSeconds: 180,
                        viewCount: 99
                    )
                ],
                totalCount: 1,
                fetchedAt: now
            )

            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let videos = await coordinator.openChannelVideos(
                ChannelVideosRouteContext(
                    channelID: channelID,
                    preferredChannelTitle: "Remote Channel",
                    selectedVideoID: selectedVideoID,
                    prefersAutomaticRefresh: true,
                    routeSource: .remoteSearch
                )
            )

            XCTAssertGreaterThan(videos.count, 1)
            XCTAssertTrue(videos.contains { $0.id == selectedVideoID })
        }
    }

    func testForceRefreshPersistsRemoteSearchResultToCache() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let freshResult = await coordinator.refresh(intent: .remoteSearch(
                keyword: "ゆっくり実況",
                limit: 100
            ))
            let cachedSnapshot = await coordinator.loadSnapshot(
                keyword: "ゆっくり実況",
                limit: 100
            )
            guard case let .remoteSearch(freshSearchResult) = freshResult else {
                return XCTFail("expected remote search refresh result")
            }

            XCTAssertEqual(freshSearchResult.videos.first?.id, "remote-refresh-001")
            XCTAssertEqual(cachedSnapshot.videos.first?.id, "remote-refresh-001")
            XCTAssertEqual(cachedSnapshot.totalCount, 2)
            XCTAssertEqual(cachedSnapshot.source, .remoteCache)
            XCTAssertNotNil(cachedSnapshot.fetchedAt)
        }
    }

    func testForceRefreshCompletesRemoteRefreshWhenVideoDetailsContainExcludedItems() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let keyword = "duration-missing-refresh"
        let staleFetchedAt = ISO8601DateFormatter().date(from: "2026-03-01T03:00:00Z")!
        let staleVideo = Self.staleRemoteSearchVideo(fetchedAt: staleFetchedAt)

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1",
            "YOUTUBEFEEDER_UI_TEST_USE_MOCK": "0",
            "YOUTUBEFEEDER_YOUTUBE_API_KEY": "test-key"
        ]) {
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }

            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: keyword,
                videos: [staleVideo],
                totalCount: 1,
                fetchedAt: staleFetchedAt
            )

            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies(
                    store: FeedCacheStore(),
                    feedService: YouTubeFeedService(),
                    channelResolver: YouTubeChannelResolver(),
                    searchService: Self.remoteRefreshSearchService(),
                    remoteSearchCacheStore: remoteCacheStore,
                    channelRegistrySyncService: ChannelRegistryCloudflareSyncService(endpointURL: nil)
                )
            )

            let freshResult = await coordinator.refresh(intent: .remoteSearch(
                keyword: keyword,
                limit: 100
            ))
            let cachedSnapshot = await coordinator.loadSnapshot(
                keyword: keyword,
                limit: 100
            )
            guard case let .remoteSearch(freshSearchResult) = freshResult else {
                return XCTFail("expected remote search refresh result")
            }

            XCTAssertEqual(freshSearchResult.source, .remoteCache)
            XCTAssertNil(freshSearchResult.errorMessage)
            XCTAssertEqual(freshSearchResult.videos.first?.id, "fresh-playable")
            XCTAssertFalse(freshSearchResult.videos.contains { $0.id == "fresh-missing-duration" })
            XCTAssertEqual(cachedSnapshot.source, .remoteCache)
            XCTAssertEqual(cachedSnapshot.videos.first?.id, "fresh-playable")
        }
    }

    func testForceRefreshPersistsEvenIfCallerTaskIsCancelled() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let refreshTask = Task { @MainActor in
                await coordinator.searchRemoteVideos(
                    keyword: "ゆっくり実況",
                    limit: 100,
                    forceRefresh: true
                )
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
            refreshTask.cancel()
            _ = await refreshTask.value
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            let cachedSnapshot = await coordinator.loadRemoteSearchSnapshot(
                keyword: "ゆっくり実況",
                limit: 100
            )

            XCTAssertEqual(cachedSnapshot.videos.first?.id, "remote-refresh-001")
            XCTAssertEqual(cachedSnapshot.totalCount, 2)
            XCTAssertEqual(cachedSnapshot.source, .remoteCache)
            XCTAssertNotNil(cachedSnapshot.fetchedAt)
        }
    }

    func testClearRemoteSearchHistoryClearsCachedSnapshot() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            _ = await coordinator.refresh(intent: .remoteSearch(keyword: "ゆっくり実況", limit: 100))
            let beforeClear = await coordinator.loadSnapshot(keyword: "ゆっくり実況", limit: 100)
            await coordinator.clearRemoteSearchHistory(keyword: "ゆっくり実況")
            let afterClear = await coordinator.loadSnapshot(keyword: "ゆっくり実況", limit: 100)

            XCTAssertFalse(beforeClear.videos.isEmpty)
            XCTAssertEqual(afterClear.videos.count, 0)
            XCTAssertEqual(afterClear.totalCount, 0)
        }
    }

    private func withEnvironment<T>(
        _ overrides: [String: String],
        operation: () async throws -> T
    ) async throws -> T {
        var previousValues: [String: String?] = [:]
        for key in overrides.keys {
            previousValues[key] = ProcessInfo.processInfo.environment[key]
        }

        for (key, value) in overrides {
            setenv(key, value, 1)
        }

        defer {
            FeedCacheSQLiteDatabase.resetShared()
            for (key, previousValue) in previousValues {
                if let previousValue {
                    setenv(key, previousValue, 1)
                } else {
                    unsetenv(key)
                }
            }
        }

        return try await operation()
    }

    nonisolated private static func staleRemoteSearchVideo(fetchedAt: Date) -> CachedVideo {
        CachedVideo(
            id: "stale-cache-video",
            channelID: "UC_STALE",
            channelTitle: "Stale Channel",
            title: "stale cached result",
            publishedAt: fetchedAt,
            videoURL: URL(string: "https://example.com/watch?v=stale"),
            thumbnailRemoteURL: nil,
            thumbnailLocalFilename: nil,
            fetchedAt: fetchedAt,
            searchableText: "stale cached result",
            durationSeconds: 600,
            viewCount: 1
        )
    }

    nonisolated private static func remoteRefreshSearchService() -> YouTubeSearchService {
        YouTubeSearchService { request in
            guard let url = request.url else {
                throw YouTubeSearchError.invalidResponse
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (try remoteSearchResponseData(for: url), response)
        }
    }

    nonisolated private static func remoteSearchResponseData(for url: URL) throws -> Data {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw YouTubeSearchError.invalidResponse
        }

        switch components.path {
        case "/youtube/v3/search":
            return searchListResponseJSON(
                items: [
                    searchListItemJSON(id: "fresh-playable", publishedAt: "2026-03-21T03:00:00Z"),
                    searchListItemJSON(id: "fresh-missing-duration", publishedAt: "2026-03-21T02:00:00Z")
                ]
            )
        case "/youtube/v3/videos":
            return videoDetailsResponseJSON(
                items: [
                    videoDetailsItemJSON(id: "fresh-playable", duration: "PT27M10S"),
                    videoDetailsItemJSON(id: "fresh-missing-duration", duration: nil)
                ]
            )
        default:
            throw YouTubeSearchError.invalidResponse
        }
    }

    nonisolated private static func searchListResponseJSON(items: [String]) -> Data {
        Data("""
        {
          "items": [
            \(items.joined(separator: ",\n"))
          ],
          "pageInfo": {
            "totalResults": \(items.count)
          }
        }
        """.utf8)
    }

    nonisolated private static func searchListItemJSON(id: String, publishedAt: String) -> String {
        """
        {
          "id": {
            "videoId": "\(id)"
          },
          "snippet": {
            "publishedAt": "\(publishedAt)",
            "channelId": "UC_REFRESH",
            "channelTitle": "Refresh Channel",
            "title": "Search item \(id)",
            "liveBroadcastContent": "none",
            "thumbnails": {
              "high": { "url": "https://example.com/\(id).jpg" }
            }
          }
        }
        """
    }

    nonisolated private static func videoDetailsResponseJSON(items: [String]) -> Data {
        Data("""
        {
          "items": [
            \(items.joined(separator: ",\n"))
          ]
        }
        """.utf8)
    }

    nonisolated private static func videoDetailsItemJSON(id: String, duration: String?) -> String {
        let contentDetails = if let duration {
            """
            "contentDetails": {
              "duration": "\(duration)"
            },
            """
        } else {
            """
            "contentDetails": {},
            """
        }

        return """
        {
          "id": "\(id)",
          \(contentDetails)
          "snippet": {
            "publishedAt": "2026-03-21T03:00:00Z",
            "channelId": "UC_REFRESH",
            "channelTitle": "Refresh Channel",
            "title": "Detail item \(id)",
            "liveBroadcastContent": "none",
            "thumbnails": {
              "high": { "url": "https://example.com/\(id).jpg" }
            }
          }
        }
        """
    }
}
