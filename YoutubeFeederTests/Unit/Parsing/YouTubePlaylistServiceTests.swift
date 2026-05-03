import XCTest
@testable import YoutubeFeeder

final class YouTubePlaylistServiceTests: LoggedTestCase {
    func testPlaylistsListResponseDecodesItems() throws {
        let json = """
        {
          "items": [
            {
              "id": "PL-001",
              "snippet": {
                "publishedAt": "2026-03-20T02:00:00Z",
                "channelId": "UC111",
                "channelTitle": "One",
                "title": "Playlist One",
                "description": "Description One",
                "thumbnails": {
                  "medium": { "url": "https://example.com/playlist-1.jpg" }
                }
              },
              "contentDetails": {
                "itemCount": 12
              }
            }
          ],
          "pageInfo": {
            "totalResults": 1
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.youtubeAPI.decode(PlaylistsListResponse.self, from: json)

        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items.first?.id, "PL-001")
        XCTAssertEqual(response.items.first?.snippet.channelID, "UC111")
        XCTAssertEqual(response.items.first?.contentDetails?.itemCount, 12)
        XCTAssertEqual(response.pageInfo?.totalResults, 1)
    }

    func testPlaylistItemsListResponseDecodesNextPageToken() throws {
        let json = """
        {
          "items": [
            {
              "contentDetails": {
                "videoId": "video-001"
              }
            }
          ],
          "nextPageToken": "PAGE-2",
          "pageInfo": {
            "totalResults": 1
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.youtubeAPI.decode(PlaylistItemsListResponse.self, from: json)

        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items.first?.contentDetails?.videoID, "video-001")
        XCTAssertEqual(response.nextPageToken, "PAGE-2")
        XCTAssertEqual(response.pageInfo?.totalResults, 1)
    }

    func testFetchPlaylistsUsesPlaylistsEndpointWithoutSearchEndpoint() async throws {
        let recorder = PlaylistRequestRecorder()
        try await withEnvironment([
            "YOUTUBEFEEDER_UI_TEST_MODE": "1",
            "YOUTUBEFEEDER_UI_TEST_USE_MOCK": "0",
            "YOUTUBEFEEDER_YOUTUBE_API_KEY": "test-key"
        ]) {
            let service = YouTubePlaylistService { request in
                try await recorder.record(request)
                guard let url = request.url else {
                    throw YouTubeSearchError.invalidResponse
                }
                return (
                    Self.playlistsResponseData(),
                    Self.httpResponse(for: url)
                )
            }

            let playlists = try await service.fetchPlaylists(channelID: "UC_TEST", limit: 50)
            let requests = await recorder.snapshot()

            XCTAssertEqual(playlists.count, 1)
            XCTAssertEqual(playlists.first?.id, "PL-001")
            XCTAssertEqual(requests.map(\.path), ["/youtube/v3/playlists"])
            XCTAssertEqual(requests.first?.queryValue(named: "channelId"), "UC_TEST")
            XCTAssertEqual(requests.first?.queryValue(named: "maxResults"), "50")
            XCTAssertNil(requests.first?.queryValue(named: "q"))
        }
    }

    func testFetchPlaylistVideosPageUsesPlaylistItemsAndVideosEndpointsWithoutSearchEndpoint() async throws {
        let recorder = PlaylistRequestRecorder()
        try await withEnvironment([
            "YOUTUBEFEEDER_UI_TEST_MODE": "1",
            "YOUTUBEFEEDER_UI_TEST_USE_MOCK": "0",
            "YOUTUBEFEEDER_YOUTUBE_API_KEY": "test-key"
        ]) {
            let service = YouTubePlaylistService { request in
                try await recorder.record(request)
                guard let url = request.url,
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                else {
                    throw YouTubeSearchError.invalidResponse
                }

                switch components.path {
                case "/youtube/v3/playlistItems":
                    return (
                        Self.playlistItemsResponseData(),
                        Self.httpResponse(for: url)
                    )
                case "/youtube/v3/videos":
                    return (
                        Self.videoDetailsResponseData(),
                        Self.httpResponse(for: url)
                    )
                default:
                    throw YouTubeSearchError.invalidResponse
                }
            }

            let page = try await service.fetchPlaylistVideosPage(
                playlistID: "PL-001",
                pageToken: "PAGE-1",
                limit: 50
            )
            let requests = await recorder.snapshot()

            XCTAssertEqual(page.playlistID, "PL-001")
            XCTAssertEqual(page.videos.map(\.id), ["video-001"])
            XCTAssertEqual(page.totalCount, 1)
            XCTAssertEqual(page.nextPageToken, "PAGE-2")
            XCTAssertEqual(requests.map(\.path), ["/youtube/v3/playlistItems", "/youtube/v3/videos"])
            XCTAssertEqual(requests.first?.queryValue(named: "playlistId"), "PL-001")
            XCTAssertEqual(requests.first?.queryValue(named: "pageToken"), "PAGE-1")
            XCTAssertEqual(requests.first?.queryValue(named: "maxResults"), "50")
            XCTAssertEqual(requests.last?.queryValue(named: "id"), "video-001")
            XCTAssertNil(requests.first(where: { $0.path == "/youtube/v3/search" }))
        }
    }

    func testContinuousPlayURLUsesCanonicalPlaylistURL() {
        let service = YouTubePlaylistService()

        XCTAssertEqual(
            service.continuousPlayURL(playlistID: "PL-001")?.absoluteString,
            "https://www.youtube.com/playlist?list=PL-001"
        )
    }

    private func withEnvironment<T>(
        _ overrides: [String: String],
        operation: () async throws -> T
    ) async throws -> T {
        var previousValues: [String: String?] = [:]
        for key in overrides.keys {
            previousValues[key] = ProcessInfo.processInfo.environment[key]
        }

        for (key, value) in overrides {
            setenv(key, value, 1)
        }

        defer {
            for (key, previousValue) in previousValues {
                if let previousValue {
                    setenv(key, previousValue, 1)
                } else {
                    unsetenv(key)
                }
            }
        }

        return try await operation()
    }

    private static func playlistsResponseData() -> Data {
        """
        {
          "items": [
            {
              "id": "PL-001",
              "snippet": {
                "publishedAt": "2026-03-20T02:00:00Z",
                "channelId": "UC111",
                "channelTitle": "One",
                "title": "Playlist One",
                "description": "Description One",
                "thumbnails": {
                  "medium": { "url": "https://example.com/playlist-1.jpg" }
                }
              },
              "contentDetails": {
                "itemCount": 12
              }
            }
          ],
          "pageInfo": {
            "totalResults": 1
          }
        }
        """.data(using: .utf8)!
    }

    private static func playlistItemsResponseData() -> Data {
        """
        {
          "items": [
            {
              "contentDetails": {
                "videoId": "video-001"
              }
            }
          ],
          "nextPageToken": "PAGE-2",
          "pageInfo": {
            "totalResults": 1
          }
        }
        """.data(using: .utf8)!
    }

    private static func videoDetailsResponseData() -> Data {
        """
        {
          "items": [
            {
              "id": "video-001",
              "contentDetails": {
                "duration": "PT27M10S"
              },
              "statistics": {
                "viewCount": "12345"
              },
              "snippet": {
                "publishedAt": "2026-03-20T01:00:00Z",
                "channelId": "UC111",
                "channelTitle": "One",
                "title": "Playlist Video One",
                "liveBroadcastContent": "none",
                "thumbnails": {
                  "high": { "url": "https://example.com/video-1.jpg" }
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!
    }

    private static func httpResponse(for url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
}

private actor PlaylistRequestRecorder {
    struct CapturedRequest {
        let path: String
        let queryItems: [URLQueryItem]

        func queryValue(named name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }
    }

    private var requests: [CapturedRequest] = []

    func record(_ request: URLRequest) throws {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw YouTubeSearchError.invalidResponse
        }
        requests.append(CapturedRequest(path: components.path, queryItems: components.queryItems ?? []))
    }

    func snapshot() -> [CapturedRequest] {
        requests
    }
}
