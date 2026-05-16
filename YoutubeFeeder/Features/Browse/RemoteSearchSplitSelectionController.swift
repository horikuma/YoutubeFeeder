import Foundation

@MainActor
final class RemoteSearchSplitSelectionController {
    private weak var owner: RemoteSearchResultsViewModel?
    private let coordinator: FeedCacheCoordinator
    private let presentationMode: RemoteSearchPresentationMode
    private var splitLoadTask: Task<Void, Never>?

    init(
        owner: RemoteSearchResultsViewModel,
        coordinator: FeedCacheCoordinator,
        presentationMode: RemoteSearchPresentationMode
    ) {
        self.owner = owner
        self.coordinator = coordinator
        self.presentationMode = presentationMode
    }

    deinit {
        splitLoadTask?.cancel()
    }

    func cancel() {
        splitLoadTask?.cancel()
    }

    func selectSplitChannel(_ context: ChannelVideosRouteContext) {
        cancel()
        beginSplitSelection(context)
        splitLoadTask = Task { [weak self] in
            await self?.performImmediateSplitSelection(context)
        }
    }

    func refreshSplitSelection() async {
        guard let owner, let splitContext = owner.splitContext else { return }
        if case let .channelVideos(reloadedVideos) = await coordinator.performRefreshAction(.channel(splitContext)) {
            owner.splitVideos = reloadedVideos
            owner.splitVisibleCount = min(20, owner.splitVideos.count)
        }
    }

    func loadSplitMoreIfNeeded() {
        guard let owner else { return }
        guard owner.splitVisibleCount < owner.splitVideos.count else { return }
        owner.splitVisibleCount = min(owner.splitVisibleCount + 20, owner.splitVideos.count)
    }

    func clearSplitSelection() {
        guard let owner else { return }
        owner.splitContext = nil
        owner.splitVideos = []
        owner.splitVisibleCount = 20
        owner.isSplitLoading = false
        owner.presentationState.splitContext = nil
    }

    func applyDefaultSplitSelectionIfNeeded() {
        guard let owner else { return }
        guard owner.browsePresentation.usesSplitLayout else {
            clearSplitSelection()
            return
        }
        guard let context = owner.presentationState.splitContext else {
            cancel()
            clearSplitSelection()
            return
        }
        if owner.splitContext == context { return }
        scheduleDeferredSplitSelection(context)
    }

    private func beginSplitSelection(_ context: ChannelVideosRouteContext) {
        guard let owner else { return }
        owner.splitContext = context
        owner.splitVideos = []
        owner.splitVisibleCount = 20
        owner.isSplitLoading = true
        owner.presentationState.splitContext = context
    }

    private func finishSplitSelection(_ context: ChannelVideosRouteContext, videos: [CachedVideo]) {
        guard let owner, owner.splitContext == context else { return }
        owner.splitVideos = videos
        owner.splitVisibleCount = min(20, videos.count)
        owner.isSplitLoading = false
    }

    private func scheduleDeferredSplitSelection(_ context: ChannelVideosRouteContext) {
        cancel()
        beginSplitSelection(context)
        let scheduledAt = Date()
        recordDeferredSplitSelectionScheduled(context)

        splitLoadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.performDeferredSplitSelection(context, scheduledAt: scheduledAt)
        }
    }

    private func performImmediateSplitSelection(_ context: ChannelVideosRouteContext) async {
        let startedAt = Date()
        AppConsoleLogger.remoteSearchSplitLoad.info(
            "remote_search_split_load_started",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "scheduled_wait_ms": "0",
                "mode": presentationMode.rawValue
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_started",
            detail: "YouTube検索右ペインの読込を開始",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "mode": presentationMode.rawValue
            ]
        )

        let loadedVideos = await coordinator.openChannelVideos(context)
        guard !Task.isCancelled else { return }

        let publishStartedAt = Date()
        finishSplitSelection(context, videos: loadedVideos)

        AppConsoleLogger.remoteSearchSplitLoad.info(
            "remote_search_split_load_completed",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "publish_ms": AppConsoleLogger.elapsedMilliseconds(from: publishStartedAt, to: Date()),
                "mode": presentationMode.rawValue
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_completed",
            detail: "YouTube検索右ペインの読込を完了",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue
            ]
        )
    }

    private func recordDeferredSplitSelectionScheduled(_ context: ChannelVideosRouteContext) {
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_scheduled",
            detail: "YouTube検索右ペインの初期読込を予約",
            metadata: [
                "channelID": context.channelID,
                "delay_ms": "150",
                "mode": presentationMode.rawValue
            ]
        )
    }

    private func performDeferredSplitSelection(_ context: ChannelVideosRouteContext, scheduledAt: Date) async {
        let startedAt = Date()
        recordDeferredSplitSelectionStarted(context, scheduledAt: scheduledAt, startedAt: startedAt)
        let loadedVideos = await coordinator.openChannelVideos(context)
        guard !Task.isCancelled else { return }

        let publishStartedAt = Date()
        finishSplitSelection(context, videos: loadedVideos)
        recordDeferredSplitSelectionCompleted(
            context,
            loadedVideos: loadedVideos,
            startedAt: startedAt,
            publishStartedAt: publishStartedAt
        )
    }

    private func recordDeferredSplitSelectionStarted(
        _ context: ChannelVideosRouteContext,
        scheduledAt: Date,
        startedAt: Date
    ) {
        AppConsoleLogger.appLifecycle.info(
            "remote_search_split_load_started",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "scheduled_wait_ms": AppConsoleLogger.elapsedMilliseconds(from: scheduledAt, to: startedAt),
                "mode": presentationMode.rawValue
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_started",
            detail: "YouTube検索右ペインの読込を開始",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "mode": presentationMode.rawValue
            ]
        )
    }

    private func recordDeferredSplitSelectionCompleted(
        _ context: ChannelVideosRouteContext,
        loadedVideos: [CachedVideo],
        startedAt: Date,
        publishStartedAt: Date
    ) {
        AppConsoleLogger.appLifecycle.info(
            "remote_search_split_load_completed",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "publish_ms": AppConsoleLogger.elapsedMilliseconds(from: publishStartedAt, to: Date()),
                "mode": presentationMode.rawValue
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_completed",
            detail: "YouTube検索右ペインの読込を完了",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue
            ]
        )
    }
}
