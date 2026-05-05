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
