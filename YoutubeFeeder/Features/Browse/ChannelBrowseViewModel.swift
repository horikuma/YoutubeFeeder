import Combine
import SwiftUI

@MainActor
final class ChannelBrowseViewModel: ObservableObject {
    let coordinator: FeedCacheCoordinator
    let sortDescriptor: ChannelBrowseSortDescriptor

    @Published var state = ChannelBrowseLogic()

    private var nextPageToken: String?
    private var didRequestLoadMore = false
    private var hasStartedPaging = false
    private var playlistSnapshot = FeedCachePlaylistSnapshot.empty

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
        RuntimeDiagnostics.shared.record(
            "channel_list_received_update",
            detail: "チャンネル一覧が maintenanceItems の更新を受信",
            metadata: [
                "itemCount": String(coordinator.maintenanceItems.count),
                "sort": sortDescriptor.shortLabel
            ]
        )
        Task {
            await loadChannelBrowseItems()
        }
    }

    func loadChannelBrowseItems() async {
        let items = await coordinator.loadChannelBrowseItems(sortDescriptor: sortDescriptor)
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
        if let feedback = await coordinator.removeChannel(pendingChannelRemoval.channelID) {
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
        loadCurrentChannelContentIfNeeded(for: channelID)
    }

    func applyDefaultSelectionIfNeeded() {
        if let selectedChannelID = state.selectedChannelID,
           state.items.contains(where: { $0.channelID == selectedChannelID }) {
            loadCurrentChannelContentIfNeeded(for: selectedChannelID)
            return
        }
        guard let firstChannelID = state.applyDefaultSelectionIfNeeded() else { return }
        nextPageToken = nil
        hasStartedPaging = false
        didRequestLoadMore = false
        loadCurrentChannelContentIfNeeded(for: firstChannelID)
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

    func clearSelectedPlaylist() {
        guard let channelID = state.selectedChannelID else { return }
        state.selectPlaylist(nil, for: channelID)
    }

    func selectPlaylist(_ playlistID: String) {
        guard let channelID = state.selectedChannelID else { return }
        state.selectPlaylist(playlistID, for: channelID)
        loadPlaylistVideosIfNeeded(for: playlistID)
    }

    func refreshSelectedChannel() async {
        guard let selectedChannelID = state.selectedChannelID else { return }
        switch state.displayMode(for: selectedChannelID) {
        case .videos:
            let selectedItem = state.items.first(where: { $0.channelID == selectedChannelID })
            RuntimeDiagnostics.shared.record(
                "channel_refresh_gesture",
                detail: "スプリット表示の動画一覧で下スワイプ更新",
                metadata: [
                    "channelID": selectedChannelID,
                    "screen": "splitChannelVideos"
                ]
            )
            if case let .channelVideos(refreshedVideos) = await coordinator.refresh(intent: .channel(
                ChannelVideosRouteContext(
                    channelID: selectedChannelID,
                    preferredChannelTitle: selectedItem?.channelTitle,
                    selectedVideoID: state.videosForSelectedChannel().first?.id,
                    prefersAutomaticRefresh: false,
                    routeSource: .channelBrowse
                )
            )) {
                withAnimation(.easeOut(duration: 0.25)) {
                    state.refreshSelectedChannelVideos(refreshedVideos)
                }
            }
            nextPageToken = nil
            hasStartedPaging = false
            didRequestLoadMore = false
            RuntimeDiagnostics.shared.record(
                "channel_refresh_view_reload_finished",
                detail: "スプリット表示の動画一覧リロード完了",
                metadata: [
                    "channelID": selectedChannelID,
                    "videoCount": String(state.videosForSelectedChannel().count)
                ]
            )
        case .playlists:
            let snapshot = await loadPlaylistSnapshot()
            withAnimation(.easeOut(duration: 0.25)) {
                applyPlaylistSnapshot(snapshot, for: selectedChannelID)
            }
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
            let page = await coordinator.loadChannelVideosPage(
                channelID: channelID,
                pageToken: nextPageToken,
                limit: 50
            )
            if state.selectedChannelID == channelID {
                state.appendSelectedChannelVideos(page.videos)
                nextPageToken = page.nextPageToken
                hasStartedPaging = true
            }
            didRequestLoadMore = false
        }
    }

    func displayMode(for channelID: String) -> ChannelBrowseDisplayMode {
        state.displayMode(for: channelID)
    }

    func videosForSelectedChannel() -> [CachedVideo] {
        state.videosForSelectedChannel()
    }

    func selectedChannelID() -> String? {
        state.selectedChannelID
    }

    func selectedPlaylistID() -> String? {
        guard let selectedChannelID = state.selectedChannelID else { return nil }
        return state.selectedPlaylistID(for: selectedChannelID)
    }

    func selectedPlaylist() -> PlaylistBrowseItem? {
        guard let selectedChannelID = state.selectedChannelID else { return nil }
        return state.selectedPlaylist(for: selectedChannelID)
    }

    func selectedPlaylistVideos() -> [PlaylistBrowseVideo] {
        guard let selectedChannelID = state.selectedChannelID else { return [] }
        return state.selectedPlaylistVideos(for: selectedChannelID)
    }

    func selectedPlaylistPage() -> PlaylistBrowseVideosPage? {
        selectedPlaylistID().flatMap { state.playlistVideosPage(for: $0) }
    }

    func selectedTitle() -> String {
        state.selectedTitle()
    }

    func tipsSummary() -> ChannelBrowseTipsSummary {
        ChannelBrowseTipsSummary.build(items: state.items, sortDescriptor: sortDescriptor)
    }

    func playlistPreviewVideo(for item: PlaylistBrowseItem) -> CachedVideo {
        CachedVideo(
            id: item.firstVideoID ?? item.playlistID,
            channelID: item.channelID,
            channelTitle: item.channelTitle,
            channelDisplayTitle: item.channelTitle,
            title: item.title,
            publishedAt: item.publishedAt,
            videoURL: playlistSnapshot.playlistContinuousPlayURLsByPlaylistID[item.playlistID]
                ?? URL(string: "https://www.youtube.com/playlist?list=\(item.playlistID)"),
            thumbnailRemoteURL: item.firstVideoThumbnailURL ?? item.thumbnailURL,
            thumbnailLocalFilename: nil,
            fetchedAt: .now,
            searchableText: [item.title, item.channelTitle, item.playlistID].joined(separator: "\n").lowercased(),
            durationSeconds: nil,
            viewCount: item.itemCount,
            metadataBadgeText: item.itemCount.map { "\($0)本" }
        )
    }

    func playlistCachedVideo(for video: PlaylistBrowseVideo) -> CachedVideo {
        CachedVideo(
            id: video.id,
            channelID: video.channelID,
            channelTitle: video.channelTitle,
            channelDisplayTitle: video.channelTitle,
            title: video.title,
            publishedAt: video.publishedAt,
            videoURL: video.videoURL,
            thumbnailRemoteURL: video.thumbnailURL,
            thumbnailLocalFilename: nil,
            fetchedAt: .now,
            searchableText: [video.title, video.channelTitle, video.id].joined(separator: "\n").lowercased(),
            durationSeconds: video.durationSeconds,
            viewCount: video.viewCount
        )
    }

    func playlistContinuousPlayURL(for item: PlaylistBrowseItem) -> URL? {
        playlistSnapshot.playlistContinuousPlayURLsByPlaylistID[item.playlistID]
            ?? URL(string: "https://www.youtube.com/playlist?list=\(item.playlistID)")
    }

    func loadCurrentChannelContentIfNeeded(for channelID: String, forceReload: Bool = false) {
        switch state.displayMode(for: channelID) {
        case .videos:
            loadVideosIfNeeded(for: channelID)
        case .playlists:
            loadPlaylistsIfNeeded(for: channelID, forceReload: forceReload)
        }
    }

    private func loadVideosIfNeeded(for channelID: String) {
        guard state.beginLoadingVideos(for: channelID) else { return }
        Task {
            let loadedVideos = await coordinator.loadVideosForChannel(channelID)
            withAnimation(.easeOut(duration: 0.25)) {
                state.finishLoadingVideos(loadedVideos, for: channelID)
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
                        "videoCount": String(loadedVideos.count)
                    ]
                )
                state.selectedChannelRefreshSource = nil
            }
        }
    }

    func loadPlaylistsIfNeeded(for channelID: String, forceReload: Bool = false) {
        guard forceReload || !state.hasLoadedPlaylists(for: channelID) else {
            if let selectedPlaylistID = state.selectedPlaylistID(for: channelID),
               state.playlistVideosPage(for: selectedPlaylistID) == nil {
                loadPlaylistVideosIfNeeded(for: selectedPlaylistID)
            }
            return
        }

        Task {
            let snapshot = await loadPlaylistSnapshot()
            withAnimation(.easeOut(duration: 0.25)) {
                applyPlaylistSnapshot(snapshot, for: channelID)
            }
            if let selectedPlaylistID = state.selectedPlaylistID(for: channelID),
               state.playlistVideosPage(for: selectedPlaylistID) == nil {
                loadPlaylistVideosIfNeeded(for: selectedPlaylistID)
            }
        }
    }

    func loadPlaylistVideosIfNeeded(for playlistID: String, forceReload: Bool = false) {
        guard forceReload || state.playlistVideosPage(for: playlistID) == nil else { return }

        Task {
            let snapshot = await loadPlaylistSnapshot()
            if let page = snapshot.playlistPagesByPlaylistID[playlistID] {
                withAnimation(.easeOut(duration: 0.25)) {
                    playlistSnapshot = snapshot
                    state.refreshPlaylistVideos(page)
                }
            }
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
}
