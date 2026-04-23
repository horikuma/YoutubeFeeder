import Foundation

struct FeedChannelProcessResult {
    let errorMessage: String?
    let fetchedVideoCount: Int?
    let uncachedVideoCount: Int
    let httpStatusCode: Int?

    init(
        errorMessage: String?,
        fetchedVideoCount: Int?,
        uncachedVideoCount: Int,
        httpStatusCode: Int? = nil
    ) {
        self.errorMessage = errorMessage
        self.fetchedVideoCount = fetchedVideoCount
        self.uncachedVideoCount = uncachedVideoCount
        self.httpStatusCode = httpStatusCode
    }
}

struct FeedRefreshCycleResult {
    var lastError: String?
    var successfulChannels = 0
    var failedChannels = 0
    var observedFetchCountChannels = 0
    var zeroFetchedChannels = 0
    var nonZeroFetchedChannels = 0
    var fetchedVideosTotal = 0
    var uncachedVideosTotal = 0
    var cachedVideosBefore = 0
    var cachedVideosAfter = 0
    var httpStatusCounts: [Int: Int] = [:]

    mutating func record(_ result: FeedChannelProcessResult) {
        if let errorMessage = result.errorMessage {
            lastError = errorMessage
            failedChannels += 1
        } else {
            successfulChannels += 1
        }

        if let fetchedVideoCount = result.fetchedVideoCount {
            observedFetchCountChannels += 1
            fetchedVideosTotal += fetchedVideoCount
            if fetchedVideoCount == 0 {
                zeroFetchedChannels += 1
            } else {
                nonZeroFetchedChannels += 1
            }
        }
        uncachedVideosTotal += result.uncachedVideoCount

        if let httpStatusCode = result.httpStatusCode {
            httpStatusCounts[httpStatusCode, default: 0] += 1
        }
    }

    func metadata(
        channelCount: Int,
        forceNetworkFetch: Bool,
        refreshSource: String,
        cachedVideosBefore: Int,
        cachedVideosAfter: Int
    ) -> [String: String] {
        [
            "channel_count": String(channelCount),
            "force_network_fetch": forceNetworkFetch ? "true" : "false",
            "refresh_source": refreshSource,
            "network_fetch_attempted_channels": forceNetworkFetch ? String(channelCount) : "conditional",
            "successful_channels": String(successfulChannels),
            "failed_channels": String(failedChannels),
            "fetch_count_observed_channels": String(observedFetchCountChannels),
            "zero_fetched_channels": String(zeroFetchedChannels),
            "nonzero_fetched_channels": String(nonZeroFetchedChannels),
            "fetched_videos_total": String(fetchedVideosTotal),
            "uncached_videos_total": String(uncachedVideosTotal),
            "http_200_channels": String(httpStatusCounts[200, default: 0]),
            "http_304_channels": String(httpStatusCounts[304, default: 0]),
            "http_404_channels": String(httpStatusCounts[404, default: 0]),
            "http_non_2xx_channels": String(httpStatusCounts.reduce(0) { total, item in
                (200...299).contains(item.key) || item.key == 304 ? total : total + item.value
            }),
            "cached_videos_before": String(cachedVideosBefore),
            "cached_videos_after": String(cachedVideosAfter),
            "cached_videos_delta": String(cachedVideosAfter - cachedVideosBefore),
            "last_error": lastError ?? ""
        ]
    }
}
