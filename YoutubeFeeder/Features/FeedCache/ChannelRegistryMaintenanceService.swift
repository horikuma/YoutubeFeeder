import Foundation

struct FeedChannelRegistrationExecution {
    let channels: [String]
    let feedback: ChannelRegistrationFeedback
}

struct FeedChannelRemovalExecution {
    let channels: [String]
    let feedback: ChannelRemovalFeedback
}

struct FeedChannelImportExecution {
    let channels: [String]
    let feedback: ChannelRegistryTransferFeedback
}

struct FeedChannelCSVImportExecution {
    let channels: [String]
    let importedChannelIDs: [String]
    let feedback: ChannelCSVImportFeedback
}

struct ChannelRegistryMaintenanceService {
    let readService: FeedCacheReadService
    let writer: FeedCacheWriteService
    let feedService: YouTubeFeedService
    let channelResolver: YouTubeChannelResolver
    let remoteSearchService: RemoteVideoSearchService

    func addChannel(input: String) async throws -> FeedChannelRegistrationExecution {
        let resolvedChannel = try await channelResolver.resolve(input: input)
        let didAdd = try ChannelRegistryStore.addChannelID(resolvedChannel.channelID)
        let channels = ChannelRegistryStore.loadAllChannelIDs()

        let latestFeedError: String?
        let cachedItem: ChannelBrowseItem?
        do {
            let result = try await feedService.fetchLatestFeed(for: resolvedChannel.channelID)
            _ = await writer.recordSuccessCachingThumbnails(
                channelID: resolvedChannel.channelID,
                videos: result.videos,
                metadata: result.metadata
            )
            latestFeedError = nil
        } catch {
            latestFeedError = error.localizedDescription
        }

        let registeredAtByChannelID = [resolvedChannel.channelID: ChannelRegistryStore.registrationDate(for: resolvedChannel.channelID)]
        cachedItem = await readService.loadChannelBrowseItems(
            channelIDs: [resolvedChannel.channelID],
            registeredAtByChannelID: registeredAtByChannelID
        ).first

        let channelTitle = cachedItem?.channelTitle.isEmpty == false ? cachedItem?.channelTitle : nil
        return FeedChannelRegistrationExecution(
            channels: channels,
            feedback: ChannelRegistrationFeedback(
                status: didAdd ? .added : .alreadyRegistered,
                channelID: resolvedChannel.channelID,
                channelTitle: channelTitle ?? resolvedChannel.channelID,
                latestVideoTitle: cachedItem?.latestVideo?.title,
                latestPublishedAt: cachedItem?.latestPublishedAt,
                cachedVideoCount: cachedItem?.cachedVideoCount ?? 0,
                latestFeedError: latestFeedError
            )
        )
    }

    func removeChannel(channelID: String, maintenanceItems: [ChannelMaintenanceItem], videos: [CachedVideo]) async -> FeedChannelRemovalExecution? {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return nil }

        let channelTitle = maintenanceItems.first(where: { $0.channelID == normalizedChannelID })?.channelTitle
            ?? videos.first(where: { $0.channelID == normalizedChannelID })?.channelTitle
            ?? normalizedChannelID

        guard (try? ChannelRegistryStore.removeChannelID(normalizedChannelID)) == true else {
            return nil
        }

        let channels = ChannelRegistryStore.loadAllChannelIDs()
        let cleanup = await writer.performConsistencyMaintenance(activeChannelIDs: channels, force: true)
        return FeedChannelRemovalExecution(
            channels: channels,
            feedback: ChannelRemovalFeedback(
                channelID: normalizedChannelID,
                channelTitle: channelTitle,
                removedVideoCount: cleanup?.removedVideoCount ?? 0,
                removedThumbnailCount: cleanup?.removedThumbnailCount ?? 0
            )
        )
    }

    func exportChannelRegistry(backend: ChannelRegistryTransferBackend) throws -> ChannelRegistryTransferFeedback {
        let result = try ChannelRegistryTransferStore.export(backend: backend)
        return ChannelRegistryTransferFeedback(
            action: .export,
            backend: result.backend,
            channelCount: result.channelCount,
            path: result.fileURL.path(percentEncoded: false),
            refreshMessage: nil
        )
    }

    func importChannelRegistry(backend: ChannelRegistryTransferBackend, usesMockData: Bool) throws -> FeedChannelImportExecution {
        let result = try ChannelRegistryTransferStore.import(backend: backend)
        let channels = ChannelRegistryStore.loadAllChannelIDs()
        let refreshMessage = usesMockData
            ? "UI テストモードでは最新情報の再取得を省略しました。"
            : "最新情報の再取得をバックグラウンドで開始しました。"
        return FeedChannelImportExecution(
            channels: channels,
            feedback: ChannelRegistryTransferFeedback(
                action: .import,
                backend: result.backend,
                channelCount: result.channelCount,
                path: result.fileURL.path(percentEncoded: false),
                refreshMessage: refreshMessage
            )
        )
    }

    func importChannelsCSV(data: Data, fileURL: URL, usesMockData: Bool) throws -> FeedChannelCSVImportExecution {
        let result = try ChannelRegistryCSVImportService.importChannels(data: data, fileURL: fileURL)
        let channels = ChannelRegistryStore.loadAllChannelIDs()
        let refreshMessage = usesMockData
            ? "UI テストモードでは最新情報の再取得を省略しました。"
            : "新規追加チャンネルの最新情報の再取得をバックグラウンドで開始しました。"

        return FeedChannelCSVImportExecution(
            channels: channels,
            importedChannelIDs: result.importedChannelIDs,
            feedback: ChannelCSVImportFeedback(
                totalRowCount: result.totalRowCount,
                importedCount: result.importedCount,
                alreadyRegisteredCount: result.alreadyRegisteredCount,
                path: result.fileURL.path(percentEncoded: false),
                refreshMessage: refreshMessage
            )
        )
    }

    func resetAllSettings() async throws -> LocalStateResetFeedback {
        let removedChannelCount = try ChannelRegistryStore.reset()
        let clearedSearchCacheCount = await remoteSearchService.clearAll()
        let clearedCache = await writer.resetAllStoredData()

        return LocalStateResetFeedback(
            removedChannelCount: removedChannelCount,
            removedVideoCount: clearedCache.removedVideoCount,
            removedThumbnailCount: clearedCache.removedThumbnailCount,
            removedSearchCacheCount: clearedSearchCacheCount
        )
    }
}
