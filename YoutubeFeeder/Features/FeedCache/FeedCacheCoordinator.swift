import Foundation
import Combine

@MainActor
final class FeedCacheCoordinator: ObservableObject {
    nonisolated static let maximumConcurrentChannelRefreshes = 3

    @Published var progress: CacheProgress
    @Published var maintenanceItems: [ChannelMaintenanceItem] = []
    @Published var videos: [CachedVideo] = []
    @Published var refreshProgress: CacheRefreshProgress = .idle
    @Published var manualRefreshCount: Int = 0
    @Published var lastManualChannelRefreshID: String?
    @Published var homeSystemStatus = HomeSystemStatus.empty(keyword: FeedCacheCoordinator.homeSearchKeyword)

    var channels: [String]
    let readService: FeedCacheReadService
    let writeService: FeedCacheWriteService
    let channelSyncService: FeedChannelSyncService
    let remoteSearchService: RemoteVideoSearchService
    let channelPlaylistBrowseService: ChannelPlaylistBrowseService
    let homeSystemStatusService: HomeSystemStatusService
    let channelRegistryMaintenanceService: ChannelRegistryMaintenanceService
    let channelRegistrySyncService: ChannelRegistryCloudflareSyncService
    var manualRefreshTask: Task<FeedRefreshCycleResult?, Never>?
    var automaticRefreshTask: Task<Void, Never>?
    var importRefreshTask: Task<Void, Never>?
    var freshnessInterval: TimeInterval
    var videoQuery = VideoQuery()
    var remoteSearchTasks: [RemoteSearchTaskKey: Task<VideoSearchResult, Never>] = [:]
    var remoteSearchSnapshotCache: [String: VideoSearchResult] = [:]
    var remoteSearchPrewarmTasks: [String: Task<Void, Never>] = [:]
    let remoteSearchCacheLifetime: TimeInterval = 12 * 60 * 60
    private lazy var support = FeedCacheCoordinatorSupport(coordinator: self)
    private lazy var browseSupport = FeedCacheCoordinatorBrowseSupport(coordinator: self)
    private lazy var refreshSupport = FeedCacheCoordinatorRefreshSupport(coordinator: self)
    lazy var refreshContinuation = FeedCacheCoordinatorRefreshWorkflow(coordinator: self)

    static let homeSearchKeyword = "ゆっくり実況"

    var isChannelRefreshRunning: Bool {
        manualRefreshTask != nil
            || importRefreshTask != nil
    }

    init(
        channels: [String],
        dependencies: FeedCacheDependencies,
        freshnessInterval: TimeInterval? = nil
    ) {
        let remoteSearchService = RemoteVideoSearchService(
            searchService: dependencies.searchService
        )
        let channelPlaylistBrowseService = ChannelPlaylistBrowseService(
            playlistService: dependencies.playlistService
        )
        let readService = FeedCacheReadService(
            store: dependencies.store,
            remoteSearchCacheStore: dependencies.remoteSearchCacheStore
        )
        let writeService = FeedCacheWriteService(
            store: dependencies.store,
            remoteSearchCacheStore: dependencies.remoteSearchCacheStore
        )
        self.channels = channels
        self.readService = readService
        self.writeService = writeService
        self.channelSyncService = FeedChannelSyncService(writer: writeService, feedService: dependencies.feedService)
        self.remoteSearchService = remoteSearchService
        self.channelPlaylistBrowseService = channelPlaylistBrowseService
        self.homeSystemStatusService = HomeSystemStatusService(
            readService: readService,
            apiKeyConfigured: remoteSearchService.isConfigured,
            homeSearchKeyword: Self.homeSearchKeyword,
            remoteSearchCacheLifetime: remoteSearchCacheLifetime
        )
        self.channelRegistrySyncService = dependencies.channelRegistrySyncService
        self.channelRegistryMaintenanceService = ChannelRegistryMaintenanceService(
            readService: readService,
            writer: writeService,
            feedService: dependencies.feedService,
            channelResolver: dependencies.channelResolver
        )
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        self.progress = bootstrap.progress
        self.maintenanceItems = bootstrap.maintenanceItems
    }

    func bootstrapMaintenance() async { await refreshSupport.bootstrapMaintenance() }

    func loadSnapshot() async -> FeedCacheSnapshot {
        var snapshot = await readService.loadSnapshot()
        snapshot.registeredChannelIDs = channels
        snapshot.maintenanceItems = maintenanceItems
        snapshot.registeredAtByChannelID = Dictionary(
            ChannelRegistryStore.loadAllChannels().map { ($0.channelID, $0.addedAt) },
            uniquingKeysWith: { _, rhs in rhs }
        )
        return snapshot
    }

    func refresh(intent: FeedCacheIntent) async -> FeedCacheResult {
        switch intent {
        case .home:
            await refreshCacheManually()
            return .home
        case let .channel(context):
            await refreshChannelManually(context.channelID)
            return .channelVideos(await loadVideosForChannel(context.channelID))
        case let .channelVideos(channelID):
            return .channelVideos(await loadVideosForChannel(channelID))
        case let .channelVideosNextPage(channelID):
            let snapshot = await loadSnapshot()
            let page = await loadChannelVideosPage(
                channelID: channelID,
                pageToken: snapshot.nextPageToken(for: channelID),
                limit: 50
            )
            return .channelVideoPage(page)
        case let .removeChannel(channelID):
            guard let feedback = await removeChannel(channelID) else {
                return .home
            }
            await writeService.saveChannelNextPageToken(nil, channelID: channelID)
            return .channelRemoval(feedback)
        case let .remoteSearch(keyword, limit):
            return .remoteSearch(await search(keyword: keyword, limit: limit, forceRefresh: true))
        }
    }

    func refreshCacheManually() async { await refreshSupport.refreshCacheManually() }

    func refreshChannelManually(_ channelID: String) async { await refreshSupport.refreshChannelManually(channelID) }

    func performRefreshAction(_ action: FeedRefreshAction) async -> FeedRefreshResult {
        await refresh(intent: action)
    }

    func loadVideosFromCache() {
        Task {
            videos = await readService.loadVideos(query: videoQuery)
        }
    }

    func loadChannelBrowseItems(sortDescriptor: ChannelBrowseSortDescriptor = .default) async -> [ChannelBrowseItem] { await browseSupport.loadChannelBrowseItems(sortDescriptor: sortDescriptor) }

    func loadVideosForChannel(_ channelID: String) async -> [CachedVideo] { await browseSupport.loadVideosForChannel(channelID) }

    func loadChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> ChannelVideoPageResult {
        await browseSupport.loadChannelVideosPage(channelID: channelID, pageToken: pageToken, limit: limit)
    }

    func loadChannelPlaylists(channelID: String, limit: Int = 50) async -> [PlaylistBrowseItem] {
        await browseSupport.loadChannelPlaylists(channelID: channelID, limit: limit)
    }

    func loadPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> PlaylistBrowseVideosPage {
        await browseSupport.loadPlaylistVideosPage(playlistID: playlistID, pageToken: pageToken, limit: limit)
    }

    func playlistContinuousPlayURL(playlistID: String) -> URL? {
        browseSupport.playlistContinuousPlayURL(playlistID: playlistID)
    }

    func openChannelVideos(_ context: ChannelVideosRouteContext) async -> [CachedVideo] {
        await browseSupport.openChannelVideos(context)
    }

    func shouldAutomaticallyRefreshChannelVideos(_ context: ChannelVideosRouteContext) async -> Bool {
        await browseSupport.shouldAutomaticallyRefreshChannelVideos(context)
    }

    func searchVideos(keyword: String, limit: Int = 20) async -> VideoSearchResult {
        await search(keyword: keyword, limit: limit)
    }

    func search(keyword: String, limit: Int = 20) async -> VideoSearchResult {
        await readService.searchVideos(keyword: keyword, limit: limit)
    }

    func processChannel(
        _ channelID: String,
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool = false
    ) async -> FeedChannelProcessResult {
        await support.processChannel(channelID, states: states, forceNetworkFetch: forceNetworkFetch)
    }

    func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        support.prioritizedChannelIDs(states: states)
    }

    func dictionaryKeepingLastValue<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
        support.dictionaryKeepingLastValue(pairs)
    }

    func dropChannelRefreshTriggerIfRunning(
        _ trigger: String,
        metadata additionalMetadata: [String: String] = [:]
    ) -> Bool {
        support.dropChannelRefreshTriggerIfRunning(trigger, metadata: additionalMetadata)
    }

    func performConsistencyMaintenanceIfNeeded(force: Bool) async -> CacheConsistencyMaintenanceResult? {
        await support.performConsistencyMaintenanceIfNeeded(force: force)
    }

    func syncRegisteredChannelsFromStore(reason: String) {
        support.syncRegisteredChannelsFromStore(reason: reason)
    }

    func refreshHomeSystemStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async {
        await support.refreshHomeSystemStatus(snapshot: snapshot, currentProgress: currentProgress)
    }

    func startChannelRegistrySyncIfNeeded() {
        support.startChannelRegistrySyncIfNeeded()
    }
}
