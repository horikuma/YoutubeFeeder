import Combine
import SwiftUI

@MainActor
final class ChannelBrowseViewModel: ObservableObject {
    let coordinator: FeedCacheCoordinator
    let sortDescriptor: ChannelBrowseSortDescriptor

    @Published var state = ChannelBrowseLogic()

    var nextPageToken: String?
    var didRequestLoadMore = false
    var hasStartedPaging = false
    var playlistSnapshot = FeedCachePlaylistSnapshot.empty

    var playlistsSnapshot: FeedCachePlaylistSnapshot {
        playlistSnapshot
    }

    init(
        coordinator: FeedCacheCoordinator,
        sortDescriptor: ChannelBrowseSortDescriptor
    ) {
        self.coordinator = coordinator
        self.sortDescriptor = sortDescriptor
    }

    func onAppear() {
        StartupDiagnostics.shared.mark("channelListShown")
    }

    func maintenanceItemsDidChange() {
        Task {
            let snapshot = await coordinator.loadSnapshot()
            RuntimeDiagnostics.shared.record(
                "channel_list_received_update",
                detail: "チャンネル一覧が maintenanceItems の更新を受信",
                metadata: [
                    "itemCount": String(snapshot.maintenanceItems.count),
                    "sort": sortDescriptor.shortLabel
                ]
            )
            applyChannelBrowseSnapshot(snapshot)
        }
    }

    func loadChannelBrowseItems() async {
        let snapshot = await coordinator.loadSnapshot()
        applyChannelBrowseSnapshot(snapshot)
    }

    private func applyChannelBrowseSnapshot(_ snapshot: FeedCacheSnapshot) {
        let items = snapshot.channelBrowseItems(sortDescriptor: sortDescriptor)
        withAnimation(.easeOut(duration: 0.25)) {
            state.setItems(items)
        }
        applyDefaultSelectionIfNeeded()
    }

    func refreshChannelBrowseItems() async {
        _ = await coordinator.refresh(intent: .home)
        await loadChannelBrowseItems()
    }

    func confirmPendingRemoval() async {
        guard let pendingChannelRemoval = state.pendingChannelRemoval else { return }
        if case let .channelRemoval(feedback) = await coordinator.refresh(intent: .removeChannel(
            channelID: pendingChannelRemoval.channelID
        )) {
            state.clearPendingRemoval()
            applyRemovalFeedback(feedback)
        } else {
            state.clearPendingRemoval()
        }
    }

    func requestRemoval(for item: ChannelBrowseItem) {
        state.requestRemoval(for: item)
    }

    func clearPendingRemoval() {
        state.clearPendingRemoval()
    }

    func applyRemovalFeedback(_ feedback: ChannelRemovalFeedback) {
        state.applyRemovalFeedback(feedback)
        Task {
            await loadChannelBrowseItems()
        }
    }

    func selectChannel(_ channelID: String) {
        state.selectChannel(channelID)
        nextPageToken = nil
        hasStartedPaging = false
        didRequestLoadMore = false
        switch state.displayMode(for: channelID) {
        case .videos:
            loadVideosIfNeeded(for: channelID)
        case .playlists:
            loadPlaylistsIfNeeded(for: channelID)
        }
    }

    func applyDefaultSelectionIfNeeded() {
        if let selectedChannelID = state.selectedChannelID,
           state.items.contains(where: { $0.channelID == selectedChannelID }) {
            switch state.displayMode(for: selectedChannelID) {
            case .videos:
                loadVideosIfNeeded(for: selectedChannelID)
            case .playlists:
                loadPlaylistsIfNeeded(for: selectedChannelID)
            }
            return
        }
        guard let firstChannelID = state.applyDefaultSelectionIfNeeded() else { return }
        nextPageToken = nil
        hasStartedPaging = false
        didRequestLoadMore = false
        switch state.displayMode(for: firstChannelID) {
        case .videos:
            loadVideosIfNeeded(for: firstChannelID)
        case .playlists:
            loadPlaylistsIfNeeded(for: firstChannelID)
        }
    }

    func setDisplayMode(_ mode: ChannelBrowseDisplayMode) {
        guard let channelID = state.selectedChannelID else { return }
        state.setDisplayMode(mode, for: channelID)
        if mode == .videos {
            loadVideosIfNeeded(for: channelID)
        } else {
            loadPlaylistsIfNeeded(for: channelID)
        }
    }

    func requestLoadMoreIfNeeded(for channelID: String?) {
        guard let channelID else { return }
        guard state.selectedChannelID == channelID else { return }
        guard !didRequestLoadMore else { return }
        guard nextPageToken != nil || !hasStartedPaging else { return }
        didRequestLoadMore = true
        RuntimeDiagnostics.shared.record(
            "channel_split_detail_load_more_requested",
            detail: "分割表示のチャンネル動画一覧の末端到達で追加取得要求を受け付けた",
            metadata: [
                "channelID": channelID,
                "videoCount": String(state.videosForSelectedChannel().count)
            ]
        )
        Task {
            if case let .channelVideoPage(page) = await coordinator.refresh(intent: .channelVideosNextPage(
                channelID: channelID
            )) {
                if state.selectedChannelID == channelID {
                    state.appendSelectedChannelVideos(page.videos)
                    nextPageToken = page.nextPageToken
                    hasStartedPaging = true
                }
            }
            didRequestLoadMore = false
        }
    }

    private func loadVideosIfNeeded(for channelID: String) {
        guard state.beginLoadingVideos(for: channelID) else { return }
        Task {
            if case let .channelVideos(loadedVideos) = await coordinator.refresh(intent: .channelVideos(
                channelID: channelID
            )) {
                withAnimation(.easeOut(duration: 0.25)) {
                    state.finishLoadingVideos(loadedVideos, for: channelID)
                }
            }
            nextPageToken = nil
            hasStartedPaging = false
            didRequestLoadMore = false
            if state.selectedChannelID == channelID,
               let refreshSource = state.selectedChannelRefreshSource {
                RuntimeDiagnostics.shared.record(
                    "channel_split_detail_reload_finished",
                    detail: "分割表示の右ペイン動画一覧が一覧更新に追随した",
                    metadata: [
                        "channelID": channelID,
                        "refresh_source": refreshSource,
                        "videoCount": String(state.videosForSelectedChannel().count)
                    ]
                )
                state.selectedChannelRefreshSource = nil
            }
        }
    }

}

extension ChannelBrowseViewModel {
    func loadPlaylistsIfNeeded(for channelID: String, forceReload: Bool = false) {
        guard forceReload || !state.hasLoadedPlaylists(for: channelID) else {
            logPlaylistLoadSkip(channelID: channelID)
            if let selectedPlaylistID = state.selectedPlaylistID(for: channelID),
               state.playlistVideosPage(for: selectedPlaylistID) == nil {
                loadPlaylistVideosIfNeeded(for: selectedPlaylistID)
            }
            return
        }

        Task {
            await loadPlaylists(channelID: channelID, forceReload: forceReload)
        }
    }

    func loadPlaylistVideosIfNeeded(for playlistID: String, forceReload: Bool = false) {
        guard forceReload || state.playlistVideosPage(for: playlistID) == nil else { return }

        Task {
            await loadPlaylistVideos(playlistID: playlistID, forceReload: forceReload)
        }
    }

    private func loadPlaylistSnapshot() async -> FeedCachePlaylistSnapshot {
        let snapshot = await coordinator.loadSnapshot()
        playlistSnapshot = snapshot.playlists
        return snapshot.playlists
    }

    private func applyPlaylistSnapshot(_ snapshot: FeedCachePlaylistSnapshot, for channelID: String) {
        playlistSnapshot = snapshot
        if let playlists = snapshot.playlistsByChannelID[channelID] {
            state.refreshPlaylists(playlists, for: channelID)
        }
        if let selectedPlaylistID = state.selectedPlaylistID(for: channelID),
           let page = snapshot.playlistPagesByPlaylistID[selectedPlaylistID] {
            state.refreshPlaylistVideos(page)
        }
    }

    private func loadPlaylists(channelID: String, forceReload: Bool) async {
        let startedAt = Date()
        logPlaylistLoadStart(channelID: channelID, forceReload: forceReload)
        var snapshot = await loadPlaylistSnapshot()
        snapshot = await fetchPlaylistSnapshotIfNeeded(
            snapshot,
            channelID: channelID,
            forceReload: forceReload,
            startedAt: startedAt
        )
        withAnimation(.easeOut(duration: 0.25)) {
            applyPlaylistSnapshot(snapshot, for: channelID)
        }
        logPlaylistLoadApplyComplete(channelID: channelID, startedAt: startedAt)
        if let selectedPlaylistID = state.selectedPlaylistID(for: channelID),
           state.playlistVideosPage(for: selectedPlaylistID) == nil {
            loadPlaylistVideosIfNeeded(for: selectedPlaylistID)
        }
    }

    private func fetchPlaylistSnapshotIfNeeded(
        _ snapshot: FeedCachePlaylistSnapshot,
        channelID: String,
        forceReload: Bool,
        startedAt: Date
    ) async -> FeedCachePlaylistSnapshot {
        guard forceReload || snapshot.playlistsByChannelID[channelID] == nil else {
            logPlaylistLoadCacheHit(snapshot, channelID: channelID)
            return snapshot
        }
        let playlists = await coordinator.loadChannelPlaylists(channelID: channelID)
        let refreshedSnapshot = await loadPlaylistSnapshot()
        logPlaylistLoadFetchComplete(channelID: channelID, items: playlists.count, startedAt: startedAt)
        return refreshedSnapshot
    }

    private func loadPlaylistVideos(playlistID: String, forceReload: Bool) async {
        let startedAt = Date()
        logPlaylistVideosStart(playlistID: playlistID, forceReload: forceReload)
        var snapshot = await loadPlaylistSnapshot()
        if forceReload || snapshot.playlistPagesByPlaylistID[playlistID] == nil {
            _ = await coordinator.loadPlaylistVideosPage(playlistID: playlistID, pageToken: nil)
            snapshot = await loadPlaylistSnapshot()
            logPlaylistVideosFetchComplete(playlistID: playlistID, startedAt: startedAt)
        }
        applyPlaylistVideosSnapshot(snapshot, playlistID: playlistID, startedAt: startedAt)
    }

    private func applyPlaylistVideosSnapshot(
        _ snapshot: FeedCachePlaylistSnapshot,
        playlistID: String,
        startedAt: Date
    ) {
        guard let page = snapshot.playlistPagesByPlaylistID[playlistID] else {
            logPlaylistVideosEmpty(playlistID: playlistID, startedAt: startedAt)
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            playlistSnapshot = snapshot
            state.refreshPlaylistVideos(page)
        }
        logPlaylistVideosApplyComplete(page: page, startedAt: startedAt)
    }

    private func logPlaylistLoadSkip(channelID: String) {
        AppConsoleLogger.appLifecycle.debug(
            "playlist_load_view_skip",
            metadata: [
                "channelID": channelID,
                "reason": "already_loaded"
            ]
        )
    }

    private func logPlaylistLoadStart(channelID: String, forceReload: Bool) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_load_view_start",
            metadata: [
                "channelID": channelID,
                "forceReload": forceReload ? "true" : "false"
            ]
        )
    }

    private func logPlaylistLoadCacheHit(_ snapshot: FeedCachePlaylistSnapshot, channelID: String) {
        AppConsoleLogger.appLifecycle.debug(
            "playlist_load_view_cache_hit",
            metadata: [
                "channelID": channelID,
                "items": String(snapshot.playlistsByChannelID[channelID]?.count ?? 0)
            ]
        )
    }

    private func logPlaylistLoadFetchComplete(channelID: String, items: Int, startedAt: Date) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_load_view_fetch_complete",
            metadata: [
                "channelID": channelID,
                "items": String(items),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }

    private func logPlaylistLoadApplyComplete(channelID: String, startedAt: Date) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_load_view_apply_complete",
            metadata: [
                "channelID": channelID,
                "items": String(state.playlists(for: channelID).count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }

    private func logPlaylistVideosStart(playlistID: String, forceReload: Bool) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_videos_view_start",
            metadata: [
                "playlistID": playlistID,
                "forceReload": forceReload ? "true" : "false"
            ]
        )
    }

    private func logPlaylistVideosFetchComplete(playlistID: String, startedAt: Date) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_videos_view_fetch_complete",
            metadata: [
                "playlistID": playlistID,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }

    private func logPlaylistVideosApplyComplete(page: PlaylistBrowseVideosPage, startedAt: Date) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_videos_view_apply_complete",
            metadata: [
                "playlistID": page.playlistID,
                "videos": String(page.videos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }

    private func logPlaylistVideosEmpty(playlistID: String, startedAt: Date) {
        AppConsoleLogger.appLifecycle.info(
            "playlist_videos_view_empty",
            metadata: [
                "playlistID": playlistID,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }
}
