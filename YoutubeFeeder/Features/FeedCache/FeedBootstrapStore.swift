import Foundation

struct FeedBootstrapSnapshot {
    var progress: CacheProgress
    var maintenanceItems: [ChannelMaintenanceItem]
}

enum FeedBootstrapStore {
    static func load(channels: [String], fileManager: FileManager = .default) -> FeedBootstrapSnapshot {
        let url = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(FeedBootstrapSnapshot.self, from: data) {
            return merged(snapshot: snapshot, channels: channels)
        }

        return merged(
            snapshot: FeedBootstrapSnapshot(
                progress: CacheProgress(
                    totalChannels: channels.count,
                    cachedChannels: 0,
                    cachedVideos: 0,
                    cachedThumbnails: 0,
                    currentChannelID: nil,
                    currentChannelNumber: nil,
                    lastUpdatedAt: nil,
                    isRunning: false,
                    lastError: nil
                ),
                maintenanceItems: channels.map {
                    ChannelMaintenanceItem(
                        id: $0,
                        channelID: $0,
                        channelTitle: nil,
                        lastSuccessAt: nil,
                        lastCheckedAt: nil,
                        latestPublishedAt: nil,
                        cachedVideoCount: 0,
                        lastError: nil,
                        freshness: .neverFetched
                    )
                }
            ),
            channels: channels
        )
    }

    private static func merged(snapshot: FeedBootstrapSnapshot, channels: [String]) -> FeedBootstrapSnapshot {
        let existingItems = Dictionary(snapshot.maintenanceItems.map { ($0.channelID, $0) }, uniquingKeysWith: { _, rhs in rhs })
        let mergedItems = channels.map { channelID in
            existingItems[channelID] ?? ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: nil,
                lastSuccessAt: nil,
                lastCheckedAt: nil,
                latestPublishedAt: nil,
                cachedVideoCount: 0,
                lastError: nil,
                freshness: .neverFetched
            )
        }

        let currentChannelID = snapshot.progress.currentChannelID.flatMap { channels.contains($0) ? $0 : nil }
        let currentChannelNumber = currentChannelID.flatMap { channelID in
            channels.firstIndex(of: channelID).map { $0 + 1 }
        }

        return FeedBootstrapSnapshot(
            progress: CacheProgress(
                totalChannels: channels.count,
                cachedChannels: min(snapshot.progress.cachedChannels, channels.count),
                cachedVideos: snapshot.progress.cachedVideos,
                cachedThumbnails: snapshot.progress.cachedThumbnails,
                currentChannelID: currentChannelID,
                currentChannelNumber: currentChannelNumber,
                lastUpdatedAt: snapshot.progress.lastUpdatedAt,
                isRunning: snapshot.progress.isRunning,
                lastError: snapshot.progress.lastError
            ),
            maintenanceItems: mergedItems
        )
    }
}

nonisolated extension FeedBootstrapSnapshot: Codable {}
