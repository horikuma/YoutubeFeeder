import Foundation

struct FeedChannelProcessResult {
    let errorMessage: String?
    let fetchedVideoCount: Int?
    let uncachedVideoCount: Int
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
    }
}
