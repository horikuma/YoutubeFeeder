import Foundation

@MainActor
final class FeedCacheCoordinatorBrowseWorkflow {
    unowned let coordinator: FeedCacheCoordinator

    init(coordinator: FeedCacheCoordinator) {
        self.coordinator = coordinator
    }

    func loadChannelBrowseItems(sortDescriptor: ChannelBrowseSortDescriptor = .default) async -> [ChannelBrowseItem] {
        let channelIDs = coordinator.maintenanceItems.map(\.channelID).isEmpty ? coordinator.channels : coordinator.maintenanceItems.map(\.channelID)
        let registeredAtByChannelID = dictionaryKeepingLastValue(
            ChannelRegistryStore.loadAllChannels().map { ($0.channelID, $0.addedAt) }
        )
        return await coordinator.readService.loadChannelBrowseItems(
            channelIDs: channelIDs,
            registeredAtByChannelID: registeredAtByChannelID,
            sortDescriptor: sortDescriptor
        )
    }

    func loadVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        await coordinator.readService.loadMergedVideosForChannel(channelID)
    }

    func loadChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> ChannelVideoPageResult {
        do {
            let page = try await coordinator.remoteSearchService.refreshChannelVideosPage(
                channelID: channelID,
                pageToken: pageToken,
                limit: limit
            )
            await coordinator.writeService.saveChannelNextPageToken(page.nextPageToken, channelID: channelID)
            return page
        } catch {
            RuntimeDiagnostics.shared.record(
                "channel_page_load_failed",
                detail: "チャンネル動画のページ取得に失敗",
                metadata: [
                    "channelID": channelID,
                    "pageToken": pageToken ?? "",
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            return ChannelVideoPageResult(videos: [], totalCount: 0, fetchedAt: .now, nextPageToken: pageToken)
        }
    }

    func loadChannelPlaylists(channelID: String, limit: Int = 50) async -> [PlaylistBrowseItem] {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return [] }

        let startedAt = Date()
        do {
            let playlists = try await coordinator.channelPlaylistBrowseService.loadPlaylists(
                channelID: normalizedChannelID,
                limit: limit
            )
            await coordinator.writeService.savePlaylistItems(playlists, channelID: normalizedChannelID)
            AppConsoleLogger.appLifecycle.info(
                "channel_playlist_list_complete",
                metadata: [
                    "channelID": normalizedChannelID,
                    "items": String(playlists.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return playlists
        } catch {
            RuntimeDiagnostics.shared.record(
                "channel_playlist_list_failed",
                detail: "チャンネルのプレイリスト一覧取得に失敗",
                metadata: [
                    "channelID": normalizedChannelID,
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            AppConsoleLogger.appLifecycle.error(
                "channel_playlist_list_failed",
                metadata: [
                    "channelID": normalizedChannelID,
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            return []
        }
    }

    func loadPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> PlaylistBrowseVideosPage {
        let normalizedPlaylistID = playlistID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPlaylistID.isEmpty else {
            return PlaylistBrowseVideosPage(
                playlistID: playlistID,
                videos: [],
                totalCount: 0,
                fetchedAt: .now,
                nextPageToken: pageToken
            )
        }

        let startedAt = Date()
        do {
            let page = try await coordinator.channelPlaylistBrowseService.loadPlaylistVideosPage(
                playlistID: normalizedPlaylistID,
                pageToken: pageToken,
                limit: limit
            )
            await coordinator.writeService.savePlaylistVideosPage(page)
            logPlaylistVideosPageComplete(playlistID: normalizedPlaylistID, videos: page.videos.count, startedAt: startedAt)
            return page
        } catch {
            return handlePlaylistVideosPageFailure(
                playlistID: normalizedPlaylistID,
                pageToken: pageToken,
                limit: limit,
                error: error
            )
        }
    }

    func playlistContinuousPlayURL(playlistID: String) -> URL? {
        let normalizedPlaylistID = playlistID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPlaylistID.isEmpty else { return nil }
        return coordinator.channelPlaylistBrowseService.continuousPlayURL(playlistID: normalizedPlaylistID)
    }

    func openChannelVideos(_ context: ChannelVideosRouteContext) async -> [CachedVideo] {
        let channelID = context.channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channelID.isEmpty else { return [] }

        let startedAt = Date()
        var mergedVideos = await loadVideosForChannel(channelID)
        guard context.prefersAutomaticRefresh else {
            AppConsoleLogger.appLifecycle.info(
                "channel_videos_open_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(mergedVideos.count),
                    "refreshed": "false",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return mergedVideos
        }

        let shouldRefresh = await shouldAutomaticallyRefreshChannelVideos(context)
        guard shouldRefresh else {
            AppConsoleLogger.appLifecycle.info(
                "channel_videos_open_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(mergedVideos.count),
                    "refreshed": "false",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return mergedVideos
        }

        if case let .channelVideos(refreshedVideos) = await coordinator.refresh(intent: .channel(context)) {
            mergedVideos = refreshedVideos
        }
        mergedVideos = await coordinator.loadRemoteSearchChannelFallbackIfNeeded(context: context, currentVideos: mergedVideos)
        AppConsoleLogger.appLifecycle.info(
            "channel_videos_open_complete",
            metadata: [
                "channelID": channelID,
                "videos": String(mergedVideos.count),
                "refreshed": "true",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
        return mergedVideos
    }

    private func logPlaylistVideosPageComplete(playlistID: String, videos: Int, startedAt: Date) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_videos_page_complete",
            metadata: [
                "playlistID": playlistID,
                "videos": String(videos),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }

    private func handlePlaylistVideosPageFailure(
        playlistID: String,
        pageToken: String?,
        limit: Int,
        error: Error
    ) -> PlaylistBrowseVideosPage {
        RuntimeDiagnostics.shared.record(
            "playlist_videos_page_failed",
            detail: "プレイリスト内動画のページ取得に失敗",
            metadata: [
                "playlistID": playlistID,
                "pageToken": pageToken ?? "",
                "limit": String(limit),
                "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
            ]
        )
        AppConsoleLogger.appLifecycle.error(
            "playlist_videos_page_failed",
            metadata: [
                "playlistID": playlistID,
                "pageToken": pageToken ?? "",
                "limit": String(limit),
                "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
            ]
        )
        return PlaylistBrowseVideosPage(
            playlistID: playlistID,
            videos: [],
            totalCount: 0,
            fetchedAt: .now,
            nextPageToken: pageToken
        )
    }

    func shouldAutomaticallyRefreshChannelVideos(_ context: ChannelVideosRouteContext) async -> Bool {
        let channelID = context.channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channelID.isEmpty else { return false }
        guard context.prefersAutomaticRefresh else { return false }

        let cachedVideos = await coordinator.readService.loadVideos(
            query: VideoQuery(limit: .max, channelID: channelID, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true)
        )
        return ChannelVideosAutoRefreshPolicy.shouldRefresh(
            cachedChannelVideos: cachedVideos,
            selectedVideoID: context.selectedVideoID,
            routeSource: context.routeSource
        )
    }

    func dictionaryKeepingLastValue<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
        Dictionary(pairs, uniquingKeysWith: { _, rhs in rhs })
    }
}
