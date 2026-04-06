import Foundation

extension FeedCacheCoordinator {
    func prewarmRemoteSearchSnapshot(keyword: String, limit: Int = 100) {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else { return }
        guard remoteSearchSnapshotCache[normalizedKeyword] == nil else { return }
        guard remoteSearchPrewarmTasks[normalizedKeyword] == nil else { return }

        remoteSearchPrewarmTasks[normalizedKeyword] = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let result = await self.loadRemoteSearchSnapshot(keyword: normalizedKeyword, limit: limit)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.remoteSearchSnapshotCache[normalizedKeyword] = result
                self.remoteSearchPrewarmTasks[normalizedKeyword] = nil
            }
        }
    }

    func loadRemoteSearchSnapshot(keyword: String, limit: Int = 100) async -> VideoSearchResult {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else {
            return VideoSearchResult(keyword: normalizedKeyword, videos: [], totalCount: 0, source: .remoteCache)
        }

        if let cached = remoteSearchSnapshotCache[normalizedKeyword] {
            return limitedRemoteSearchResult(cached, limit: limit)
        }

        let logger = AppConsoleLogger.youtubeSearch

        if AppLaunchMode.current.usesMockData {
            if let cached = await readService.loadRemoteSearchSnapshot(
                keyword: normalizedKeyword,
                limit: limit,
                cacheLifetime: remoteSearchCacheLifetime,
                allowExpired: true
            ) {
                remoteSearchSnapshotCache[normalizedKeyword] = cached
                logger.info(
                    "snapshot_hit",
                    metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "source": cached.source.label, "videos": String(cached.videos.count)]
                )
                return cached
            }
            let local = await searchVideos(keyword: normalizedKeyword, limit: limit)
            logger.info(
                "snapshot_mock_local",
                metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "videos": String(local.videos.count)]
            )
            let result = VideoSearchResult(
                keyword: normalizedKeyword,
                videos: local.videos,
                totalCount: local.totalCount,
                source: .mockData,
                fetchedAt: .now,
                expiresAt: Date().addingTimeInterval(remoteSearchCacheLifetime)
            )
            remoteSearchSnapshotCache[normalizedKeyword] = result
            return result
        }

        if let cached = await readService.loadRemoteSearchSnapshot(
            keyword: normalizedKeyword,
            limit: limit,
            cacheLifetime: remoteSearchCacheLifetime,
            allowExpired: true
        ) {
            remoteSearchSnapshotCache[normalizedKeyword] = cached
            logger.info(
                "snapshot_hit",
                metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "source": cached.source.label, "videos": String(cached.videos.count)]
            )
            return cached
        }

        logger.info(
            "snapshot_miss",
            metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "limit": String(limit)]
        )
        let result = VideoSearchResult(keyword: normalizedKeyword, videos: [], totalCount: 0, source: .remoteCache)
        remoteSearchSnapshotCache[normalizedKeyword] = result
        return result
    }

    func searchRemoteVideos(keyword: String, limit: Int = 100, forceRefresh: Bool = false) async -> VideoSearchResult {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else {
            return VideoSearchResult(keyword: normalizedKeyword, videos: [], totalCount: 0, source: .remoteCache)
        }

        let logger = AppConsoleLogger.youtubeSearch
        logger.info(
            "coordinator_search_start",
            metadata: [
                "keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword),
                "limit": String(limit),
                "force_refresh": forceRefresh ? "true" : "false",
            ]
        )

        if AppLaunchMode.current.usesMockData {
            if forceRefresh {
                return await performManagedRemoteRefresh(
                    keyword: normalizedKeyword,
                    limit: limit,
                    logger: logger,
                    fallbackOnFailure: "snapshot"
                )
            }
            return await loadRemoteSearchSnapshot(keyword: normalizedKeyword, limit: limit)
        }

        if !forceRefresh {
            return await loadRemoteSearchSnapshot(keyword: normalizedKeyword, limit: limit)
        }

        let result = await performManagedRemoteRefresh(
            keyword: normalizedKeyword,
            limit: limit,
            logger: logger,
            fallbackOnFailure: "none"
        )
        remoteSearchSnapshotCache[normalizedKeyword] = result
        return result
    }

    func clearRemoteSearchHistory(keyword: String) async {
        await writeService.clearRemoteSearch(keyword: keyword)
        clearRemoteSearchSnapshot(keyword: keyword)
        await refreshHomeSystemStatus()
    }

    func loadRemoteSearchChannelFallbackIfNeeded(
        context: ChannelVideosRouteContext,
        currentVideos: [CachedVideo]
    ) async -> [CachedVideo] {
        guard context.routeSource == .remoteSearch else { return currentVideos }
        guard currentVideos.count <= 1 else { return currentVideos }
        guard remoteSearchService.isConfigured else { return currentVideos }

        let startedAt = Date()
        AppConsoleLogger.youtubeSearch.info(
            "channel_fallback_start",
            metadata: [
                "channelID": context.channelID,
                "existing_videos": String(currentVideos.count),
            ]
        )

        do {
            let payload = try await remoteSearchService.refreshChannelVideos(channelID: context.channelID, limit: 50)
            await writeService.saveRemoteSearchChannelVideos(
                channelID: context.channelID,
                videos: payload.videos,
                fetchedAt: payload.fetchedAt
            )
            let reloadedVideos = await loadVideosForChannel(context.channelID)
            AppConsoleLogger.youtubeSearch.notice(
                "channel_fallback_complete",
                metadata: [
                    "channelID": context.channelID,
                    "videos": String(reloadedVideos.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return reloadedVideos
        } catch {
            AppConsoleLogger.youtubeSearch.error(
                "channel_fallback_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "channelID": context.channelID,
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return currentVideos
        }
    }

    func performManagedRemoteRefresh(
        keyword: String,
        limit: Int,
        logger: AppConsoleLogger,
        fallbackOnFailure: String
    ) async -> VideoSearchResult {
        let key = RemoteSearchTaskKey(keyword: keyword, limit: limit)

        let task: Task<VideoSearchResult, Never>
        if let existingTask = remoteSearchTasks[key] {
            task = existingTask
        } else {
            task = Task { [remoteSearchService, readService, writeService, remoteSearchCacheLifetime] in
                do {
                    let payload = try await remoteSearchService.refresh(keyword: keyword, limit: limit)
                    await writeService.mergeRemoteSearch(
                        keyword: keyword,
                        videos: payload.videos,
                        fetchedAt: payload.fetchedAt
                    )
                    return await readService.loadRemoteSearchSnapshot(
                        keyword: keyword,
                        limit: limit,
                        cacheLifetime: remoteSearchCacheLifetime,
                        allowExpired: true
                    ) ?? VideoSearchResult(
                        keyword: keyword,
                        videos: payload.videos,
                        totalCount: payload.totalCount,
                        source: .remoteAPI,
                        fetchedAt: payload.fetchedAt,
                        expiresAt: payload.fetchedAt.addingTimeInterval(remoteSearchCacheLifetime)
                    )
                } catch {
                    return await Self.resolveRemoteRefreshFailure(
                        error: error,
                        keyword: keyword,
                        limit: limit,
                        logger: logger,
                        readService: readService,
                        remoteSearchCacheLifetime: remoteSearchCacheLifetime,
                        fallbackOnFailure: fallbackOnFailure
                    )
                }
            }
            remoteSearchTasks[key] = task
        }

        let result = await task.value
        remoteSearchTasks[key] = nil
        remoteSearchSnapshotCache[keyword] = result
        await refreshHomeSystemStatus()
        return result
    }

    func limitedRemoteSearchResult(_ result: VideoSearchResult, limit: Int) -> VideoSearchResult {
        VideoSearchResult(
            keyword: result.keyword,
            videos: Array(result.videos.prefix(limit)),
            totalCount: result.totalCount,
            source: result.source,
            fetchedAt: result.fetchedAt,
            expiresAt: result.expiresAt,
            errorMessage: result.errorMessage
        )
    }

    func clearRemoteSearchSnapshot(keyword: String) {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        remoteSearchSnapshotCache[normalizedKeyword] = nil
        remoteSearchPrewarmTasks[normalizedKeyword]?.cancel()
        remoteSearchPrewarmTasks[normalizedKeyword] = nil
    }

    func resetRemoteSearchSnapshotCache() {
        remoteSearchSnapshotCache.removeAll()
        for task in remoteSearchPrewarmTasks.values {
            task.cancel()
        }
        remoteSearchPrewarmTasks.removeAll()
    }

    nonisolated static func resolveRemoteRefreshFailure(
        error: Error,
        keyword: String,
        limit: Int,
        logger: AppConsoleLogger,
        readService: FeedCacheReadService,
        remoteSearchCacheLifetime: TimeInterval,
        fallbackOnFailure: String
    ) async -> VideoSearchResult {
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        if RemoteSearchErrorPolicy.isCancellation(error) {
            return await resolveCancelledRemoteRefreshFailure(
                error: error,
                keyword: keyword,
                limit: limit,
                keywordPreview: keywordPreview,
                logger: logger,
                readService: readService,
                remoteSearchCacheLifetime: remoteSearchCacheLifetime
            )
        }

        if let cached = await readService.loadRemoteSearchSnapshot(
            keyword: keyword,
            limit: limit,
            cacheLifetime: remoteSearchCacheLifetime,
            allowExpired: true
        ) {
            logger.error(
                "refresh_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "keyword": keywordPreview,
                    "fallback": "stale_cache",
                    "videos": String(cached.videos.count),
                ]
            )
            return VideoSearchResult(
                keyword: cached.keyword,
                videos: cached.videos,
                totalCount: cached.totalCount,
                source: .staleRemoteCache,
                fetchedAt: cached.fetchedAt,
                expiresAt: cached.expiresAt,
                errorMessage: RemoteSearchErrorPolicy.userMessage(for: error)
            )
        }

        logger.error(
            "refresh_failed",
            message: AppConsoleLogger.errorSummary(error),
            metadata: ["keyword": keywordPreview, "fallback": fallbackOnFailure]
        )
        return VideoSearchResult(
            keyword: keyword,
            videos: [],
            totalCount: 0,
            source: .remoteAPI,
            errorMessage: RemoteSearchErrorPolicy.userMessage(for: error)
        )
    }

    nonisolated static func resolveCancelledRemoteRefreshFailure(
        error: Error,
        keyword: String,
        limit: Int,
        keywordPreview: String,
        logger: AppConsoleLogger,
        readService: FeedCacheReadService,
        remoteSearchCacheLifetime: TimeInterval
    ) async -> VideoSearchResult {
        if let cached = await readService.loadRemoteSearchSnapshot(
            keyword: keyword,
            limit: limit,
            cacheLifetime: remoteSearchCacheLifetime,
            allowExpired: true
        ) {
            logger.notice("refresh_cancelled", metadata: cancelledRefreshMetadata(
                keywordPreview: keywordPreview,
                fallback: cached.source == .staleRemoteCache ? "stale_cache" : "cache",
                cachedVideoCount: cached.videos.count,
                error: error
            ))
            return VideoSearchResult(
                keyword: cached.keyword,
                videos: cached.videos,
                totalCount: cached.totalCount,
                source: cached.source,
                fetchedAt: cached.fetchedAt,
                expiresAt: cached.expiresAt
            )
        }

        logger.notice("refresh_cancelled", metadata: cancelledRefreshMetadata(
            keywordPreview: keywordPreview,
            fallback: "empty",
            cachedVideoCount: nil,
            error: error
        ))
        return VideoSearchResult(
            keyword: keyword,
            videos: [],
            totalCount: 0,
            source: .remoteCache
        )
    }

    nonisolated static func cancelledRefreshMetadata(
        keywordPreview: String,
        fallback: String,
        cachedVideoCount: Int?,
        error: Error
    ) -> [String: String] {
        var metadata: [String: String] = [
            "keyword": keywordPreview,
            "fallback": fallback,
            "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
        ]
        if let cachedVideoCount {
            metadata["videos"] = String(cachedVideoCount)
        }
        return metadata
    }
}

struct RemoteSearchTaskKey: Hashable {
    let keyword: String
    let limit: Int
}
