import XCTest
@testable import YoutubeFeeder

final class YouTubeSearchServiceTests: LoggedTestCase {
    func testVideoDetailsPartIncludesStatistics() {
        XCTAssertEqual(
            YouTubeSearchService.videoDetailsPartParameter,
            "snippet,contentDetails,statistics,liveStreamingDetails"
        )
    }

    func testMergeCandidatesKeepsLatestPublishedAtAndSortsDescending() {
        let older = ISO8601DateFormatter().date(from: "2026-03-15T01:00:00Z")!
        let newer = ISO8601DateFormatter().date(from: "2026-03-15T02:00:00Z")!

        let merged = YouTubeSearchService.mergeCandidates(
            [
                SearchCandidate(id: "video-1", publishedAt: older),
                SearchCandidate(id: "video-2", publishedAt: newer),
                SearchCandidate(id: "video-1", publishedAt: newer)
            ]
        )

        XCTAssertEqual(merged.map(\.id), ["video-1", "video-2"])
        XCTAssertEqual(merged.first?.publishedAt, newer)
    }

    func testFilterPlayableVideosExcludesLiveEntries() {
        let json = Self.videoDetailsResponseJSON(items: [
            Self.videoDetailsItemJSON(id: "video-1", duration: "PT27M10S"),
            Self.videoDetailsItemJSON(id: "video-2", duration: "PT45M00S", liveBroadcastContent: "live", includeLiveStreamingDetails: true)
        ])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try? decoder.decode(VideoListResponse.self, from: json)

        let filtered = YouTubeSearchService.filterPlayableVideos(response?.items ?? [])
        XCTAssertEqual(filtered.map(\.id), ["video-1"])
        XCTAssertEqual(filtered.first?.durationSeconds, 1_630)
        XCTAssertEqual(filtered.first?.viewCount, 12_345)
    }

    func testVideoListResponseDecodesItemsWithMissingContentDetailsDuration() throws {
        let json = Self.videoDetailsResponseJSON(items: [
            Self.videoDetailsItemJSON(id: "video-1", duration: "PT27M10S"),
            Self.videoDetailsItemJSON(id: "video-2", duration: nil),
            Self.videoDetailsItemJSON(id: "video-3", duration: nil, publishedAt: "2026-03-15T00:00:00Z", channelID: "UC333", channelTitle: "Three", title: "Missing content details")
        ])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(VideoListResponse.self, from: json)

        XCTAssertEqual(response.items.map(\.id), ["video-1", "video-2", "video-3"])
    }

    func testFilterPlayableVideosExcludesItemsMissingDuration() throws {
        let json = Self.videoDetailsResponseJSON(items: [
            Self.videoDetailsItemJSON(id: "video-1", duration: "PT27M10S"),
            Self.videoDetailsItemJSON(id: "video-2", duration: nil),
            Self.videoDetailsItemJSON(id: "video-3", duration: nil, publishedAt: "2026-03-15T00:00:00Z", channelID: "UC333", channelTitle: "Three", title: "Missing content details")
        ])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(VideoListResponse.self, from: json)
        let filtered = YouTubeSearchService.filterPlayableVideos(response.items)

        XCTAssertEqual(filtered.map(\.id), ["video-1"])
        XCTAssertEqual(filtered.first?.durationSeconds, 1_630)
    }

    func testFetchVideoDetailsContinuesConvertibleItemsAcrossBatchesWhenExcludedItemsPresent() async throws {
        let recorder = VideoDetailsRequestRecorder()
        let service = YouTubeSearchService { request in
            guard let url = request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  components.path == "/youtube/v3/videos",
                  let idValue = components.queryItems?.first(where: { $0.name == "id" })?.value
            else {
                throw YouTubeSearchError.invalidResponse
            }

            let ids = idValue.split(separator: ",").map(String.init)
            await recorder.record(ids)

            let data = if ids.count == 50 {
                Self.videoDetailsResponseJSON(
                    items: [
                        Self.videoDetailsItemJSON(id: ids[0], duration: "PT27M10S"),
                        Self.videoDetailsItemJSON(id: ids[1], duration: nil)
                    ]
                )
            } else {
                Self.videoDetailsResponseJSON(
                    items: [
                        Self.videoDetailsItemJSON(id: ids[0], duration: "PT45M00S")
                    ]
                )
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }
        let ids = (1 ... 51).map { "video-\(String(format: "%03d", $0))" }

        let videos = try await service.fetchVideoDetails(videoIDs: ids, apiKey: "test-key")
        let requestedIDs = await recorder.snapshot()

        XCTAssertEqual(requestedIDs.map(\.count), [50, 1])
        XCTAssertEqual(videos.map(\.id), ["video-001", "video-051"])
        XCTAssertEqual(videos.map(\.durationSeconds), [1_630, 2_700])
    }

    func testFetchChannelVideosPageUsesUploadsPlaylistAndPlaylistItemsPageToken() async throws {
        let recorder = ChannelVideosRequestRecorder()
        let service = makeChannelVideosService(
            recording: recorder,
            uploadsPlaylistID: "UU123",
            playlistVideoIDs: ["video-1", "video-2"],
            playlistNextPageToken: "NEXT_PAGE",
            videoDetails: [
                Self.videoDetailsItemJSON(id: "video-1", duration: "PT27M10S"),
                Self.videoDetailsItemJSON(id: "video-2", duration: "PT45M00S")
            ]
        )

        let page = try await service.fetchChannelVideosPage(
            channelID: "UC123",
            pageToken: "PAGE-2",
            limit: 2
        )
        let requests = await recorder.snapshot()

        XCTAssertEqual(requests.map(\.path), [
            "/youtube/v3/channels",
            "/youtube/v3/playlistItems",
            "/youtube/v3/videos"
        ])
        XCTAssertEqual(requests[0].queryValue(named: "id"), "UC123")
        XCTAssertEqual(requests[1].queryValue(named: "playlistId"), "UU123")
        XCTAssertEqual(requests[1].queryValue(named: "pageToken"), "PAGE-2")
        XCTAssertEqual(requests[1].queryValue(named: "maxResults"), "2")
        XCTAssertEqual(requests[2].queryValue(named: "id"), "video-1,video-2")
        XCTAssertEqual(page.videos.map(\.id), ["video-1", "video-2"])
        XCTAssertEqual(page.totalCount, 3)
        XCTAssertEqual(page.nextPageToken, "NEXT_PAGE")
    }

    func testFetchChannelVideosPageFiltersShortVideos() async throws {
        let service = makeChannelVideosService(
            uploadsPlaylistID: "UU123",
            playlistVideoIDs: ["video-short", "video-long"],
            playlistNextPageToken: nil,
            videoDetails: [
                Self.videoDetailsItemJSON(id: "video-short", duration: "PT10S"),
                Self.videoDetailsItemJSON(id: "video-long", duration: "PT27M10S")
            ]
        )

        let page = try await service.fetchChannelVideosPage(channelID: "UC123", pageToken: nil, limit: 2)

        XCTAssertEqual(page.videos.map(\.id), ["video-long"])
        XCTAssertEqual(page.totalCount, 2)
        XCTAssertNil(page.nextPageToken)
    }

    private static func videoDetailsResponseJSON(items: [String]) -> Data {
        Data("""
        {
          "items": [
            \(items.joined(separator: ",\n"))
          ]
        }
        """.utf8)
    }

    private static func videoDetailsItemJSON(
        id: String,
        duration: String?,
        publishedAt: String = "2026-03-15T02:00:00Z",
        channelID: String = "UC111",
        channelTitle: String = "One",
        title: String = "Playable \(id)",
        liveBroadcastContent: String = "none",
        includeLiveStreamingDetails: Bool = false
    ) -> String {
        let contentDetails = if let duration {
            """
            "contentDetails": {
              "duration": "\(duration)"
            },
            """
        } else {
            """
            "contentDetails": {},
            """
        }

        return """
        {
          "id": "\(id)",
          \(contentDetails)
          "snippet": {
            "publishedAt": "\(publishedAt)",
            "channelId": "\(channelID)",
            "channelTitle": "\(channelTitle)",
            "title": "\(title)",
            "liveBroadcastContent": "\(liveBroadcastContent)",
            "thumbnails": {
              "high": { "url": "https://example.com/\(id).jpg" }
            }
          }
          \(includeLiveStreamingDetails ? ",\n  \"liveStreamingDetails\": {}" : "")
        }
        """
    }

    private static func channelsListResponseJSON(uploadsPlaylistID: String) -> Data {
        Data("""
        {
          "items": [
            {
              "contentDetails": {
                "relatedPlaylists": {
                  "uploads": "\(uploadsPlaylistID)"
                }
              }
            }
          ]
        }
        """.utf8)
    }

    private static func playlistItemsResponseJSON(videoIDs: [String], nextPageToken: String?) -> Data {
        let items = videoIDs.map { videoID in
            """
            {
              "contentDetails": {
                "videoId": "\(videoID)"
              }
            }
            """
        }

        let nextPageTokenJSON = if let nextPageToken {
            """
            "nextPageToken": "\(nextPageToken)",
            """
        } else {
            ""
        }

        let totalResults = videoIDs.count + (nextPageToken == nil ? 0 : 1)

        return Data("""
        {
          \(nextPageTokenJSON)
          "pageInfo": {
            "totalResults": \(totalResults)
          },
          "items": [
            \(items.joined(separator: ",\n"))
          ]
        }
        """.utf8)
    }

    private static func httpResponse(for url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private static func makeChannelVideosService(
        recording recorder: ChannelVideosRequestRecorder,
        uploadsPlaylistID: String = "UU123",
        playlistVideoIDs: [String] = ["video-1", "video-2"],
        playlistNextPageToken: String? = "NEXT_PAGE",
        videoDetails: [String]
    ) -> YouTubeSearchService {
        YouTubeSearchService { request in
            guard let url = request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                throw YouTubeSearchError.invalidResponse
            }

            await recorder.record(path: components.path, queryItems: components.queryItems ?? [])

            switch components.path {
            case "/youtube/v3/channels":
                return (
                    Self.channelsListResponseJSON(uploadsPlaylistID: uploadsPlaylistID),
                    Self.httpResponse(for: url)
                )
            case "/youtube/v3/playlistItems":
                return (
                    Self.playlistItemsResponseJSON(
                        videoIDs: playlistVideoIDs,
                        nextPageToken: playlistNextPageToken
                    ),
                    Self.httpResponse(for: url)
                )
            case "/youtube/v3/videos":
                return (
                    Self.videoDetailsResponseJSON(items: videoDetails),
                    Self.httpResponse(for: url)
                )
            default:
                throw YouTubeSearchError.invalidResponse
            }
        }
    }
}

private actor VideoDetailsRequestRecorder {
    private var requestedIDs: [[String]] = []

    func record(_ ids: [String]) {
        requestedIDs.append(ids)
    }

    func snapshot() -> [[String]] {
        requestedIDs
    }
}

private actor ChannelVideosRequestRecorder {
    struct CapturedRequest {
        let path: String
        let queryItems: [URLQueryItem]
    }

    private var requests: [CapturedRequest] = []

    func record(path: String, queryItems: [URLQueryItem]) {
        requests.append(CapturedRequest(path: path, queryItems: queryItems))
    }

    func snapshot() -> [CapturedRequest] {
        requests
    }
}

private extension ChannelVideosRequestRecorder.CapturedRequest {
    func queryValue(named name: String) -> String? {
        queryItems.first(where: { $0.name == name })?.value
    }
}
