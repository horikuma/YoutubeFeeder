import Foundation

struct YouTubeSearchService {
    nonisolated static let videoDetailsPartParameter = "snippet,contentDetails,statistics,liveStreamingDetails"

    private let transport: YouTubeSearchServiceTransport

    init(
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.transport = YouTubeSearchServiceTransport(dataLoader: dataLoader)
    }

    var isConfigured: Bool {
        AppLaunchMode.current.usesMockData || resolvedAPIKey != nil
    }

    func searchVideos(keyword: String, limit: Int = 100) async throws -> YouTubeSearchResponse {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        var stage = "prepare"
        logRequestStart(keywordPreview: keywordPreview, limit: limit, logger: logger)

        do {
            if AppLaunchMode.current.usesMockData {
                var mockSearchParams = MockSearchParams(
                    keyword: keyword,
                    limit: limit,
                    keywordPreview: keywordPreview,
                    startedAt: startedAt,
                    logger: logger,
                    stage: stage
                )
                let response = try await performMockSearch(params: &mockSearchParams)
                stage = mockSearchParams.stage
                return response
            }

            let apiKey = try resolveAPIKey(keywordPreview: keywordPreview, logger: logger)
            let selection = try await fetchSelectedVideoIDs(
                keyword: keyword,
                limit: limit,
                apiKey: apiKey,
                stage: &stage
            )
            stage = "video_details"
            let detailedVideos = try await transport.fetchVideoDetails(videoIDs: selection.videoIDs, apiKey: apiKey)
            stage = "merge_details"
            let videos = YouTubeSearchServiceProcessing.mergeDetailedVideos(detailedVideos, preferredOrder: selection.videoIDs)
            let response = YouTubeSearchResponse(videos: videos, totalCount: videos.count, fetchedAt: .now)
            logger.info(
                "request_complete",
                metadata: selection.completionMetadata(
                    keywordPreview: keywordPreview,
                    videoCount: videos.count,
                    startedAt: startedAt
                )
            )
            return response
        } catch {
            handleSearchFailure(error, keywordPreview: keywordPreview, stage: stage, startedAt: startedAt, logger: logger)
            throw error
        }
    }

    func searchChannelVideos(channelID: String, limit: Int = 50) async throws -> YouTubeSearchResponse {
        let page = try await fetchChannelVideosPage(channelID: channelID, pageToken: nil, limit: limit)
        return YouTubeSearchResponse(videos: page.videos, totalCount: page.totalCount, fetchedAt: page.fetchedAt)
    }

    func fetchChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int = 50
    ) async throws -> YouTubeChannelVideosPage {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = YouTubeSearchServiceProcessing.mockChannelVideosPageResponse(channelID: channelID, limit: limit)
                logger.info(
                    "channel_request_complete",
                    metadata: [
                        "channelID": channelID,
                        "videos": String(response.videos.count),
                        "source": "mock",
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                    ]
                )
                return response
            }

            let apiKey = try resolveAPIKey(keywordPreview: channelID, logger: logger)
            stage = "channel_playlist"
            let page = try await transport.fetchChannelVideosPage(
                channelID: channelID,
                pageToken: pageToken,
                limit: min(limit, 50),
                apiKey: apiKey
            )
            logger.info(
                "channel_request_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(page.videos.count),
                    "selected_ids": String(page.videos.count),
                    "next_page_token": page.nextPageToken ?? "",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return page
        } catch {
            handleSearchFailure(error, keywordPreview: channelID, stage: stage, startedAt: startedAt, logger: logger)
            throw error
        }
    }

    private func logRequestStart(keywordPreview: String, limit: Int, logger: AppConsoleLogger) {
        logger.info(
            "request_start",
            metadata: [
                "keyword": keywordPreview,
                "limit": String(limit),
                "mode": AppLaunchMode.current.usesMockData ? "mock" : "live"
            ]
        )
    }

    private struct MockSearchParams {
        let keyword: String
        let limit: Int
        let keywordPreview: String
        let startedAt: Date
        let logger: AppConsoleLogger
        var stage: String
    }

    private func performMockSearch(params: inout MockSearchParams) async throws -> YouTubeSearchResponse {
        params.stage = "mock_delay"
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        params.stage = "mock_response"
        let response = YouTubeSearchServiceProcessing.mockSearchResponse(keyword: params.keyword, limit: params.limit)
        params.logger.info(
            "request_complete",
            metadata: [
                "keyword": params.keywordPreview,
                "videos": String(response.videos.count),
                "source": "mock",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: params.startedAt)
            ]
        )
        return response
    }

    private func resolveAPIKey(keywordPreview: String, logger: AppConsoleLogger) throws -> String {
        guard let apiKey = resolvedAPIKey else {
            logger.error(
                "config_missing",
                message: YouTubeSearchError.apiKeyMissing.localizedDescription,
                metadata: ["keyword": keywordPreview]
            )
            throw YouTubeSearchError.apiKeyMissing
        }
        return apiKey
    }

    private func fetchSelectedVideoIDs(
        keyword: String,
        limit: Int,
        apiKey: String,
        stage: inout String
    ) async throws -> CandidateSelection {
        stage = "candidate_medium"
        let mediumCandidates = try await transport.searchCandidates(
            keyword: keyword,
            duration: "medium",
            apiKey: apiKey,
            maxResults: 50
        )
        stage = "candidate_long"
        let longCandidates = try await transport.searchCandidates(
            keyword: keyword,
            duration: "long",
            apiKey: apiKey,
            maxResults: 50
        )
        stage = "merge_candidates"
        let mergedCandidates = YouTubeSearchServiceProcessing.mergeCandidates(mediumCandidates + longCandidates)
        return CandidateSelection(
            mediumCandidateCount: mediumCandidates.count,
            longCandidateCount: longCandidates.count,
            videoIDs: Array(mergedCandidates.map(\.id).prefix(limit))
        )
    }

    private func handleSearchFailure(
        _ error: Error,
        keywordPreview: String,
        stage: String,
        startedAt: Date,
        logger: AppConsoleLogger
    ) {
        let metadata = [
            "keyword": keywordPreview,
            "stage": stage,
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
        ]
        if RemoteSearchErrorPolicy.isCancellation(error) {
            logger.info("request_cancelled", metadata: metadata)
        } else {
            logger.error(
                "request_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
        }
    }

    private var resolvedAPIKey: String? {
        let environmentKey = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_YOUTUBE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

        let plistKey = Bundle.main.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String
        if let plistKey {
            let trimmed = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") {
                return trimmed
            }
        }

        return nil
    }
}

private struct CandidateSelection {
    let mediumCandidateCount: Int
    let longCandidateCount: Int
    let videoIDs: [String]

    func completionMetadata(keywordPreview: String, videoCount: Int, startedAt: Date) -> [String: String] {
        [
            "keyword": keywordPreview,
            "medium_candidates": String(mediumCandidateCount),
            "long_candidates": String(longCandidateCount),
            "selected_ids": String(videoIDs.count),
            "videos": String(videoCount),
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
        ]
    }
}
