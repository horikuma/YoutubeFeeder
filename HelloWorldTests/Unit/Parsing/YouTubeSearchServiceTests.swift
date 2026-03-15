import XCTest
@testable import HelloWorld

final class YouTubeSearchServiceTests: XCTestCase {
    func testMergeCandidatesKeepsLatestPublishedAtAndSortsDescending() {
        let older = ISO8601DateFormatter().date(from: "2026-03-15T01:00:00Z")!
        let newer = ISO8601DateFormatter().date(from: "2026-03-15T02:00:00Z")!

        let merged = YouTubeSearchService.mergeCandidates(
            [
                SearchCandidate(id: "video-1", publishedAt: older),
                SearchCandidate(id: "video-2", publishedAt: newer),
                SearchCandidate(id: "video-1", publishedAt: newer),
            ]
        )

        XCTAssertEqual(merged.map(\.id), ["video-1", "video-2"])
        XCTAssertEqual(merged.first?.publishedAt, newer)
    }

    func testFilterPlayableVideosExcludesLiveEntries() {
        let json = """
        {
          "items": [
            {
              "id": "video-1",
              "snippet": {
                "publishedAt": "2026-03-15T02:00:00Z",
                "channelId": "UC111",
                "channelTitle": "One",
                "title": "Playable",
                "liveBroadcastContent": "none",
                "thumbnails": {
                  "high": { "url": "https://example.com/1.jpg" }
                }
              }
            },
            {
              "id": "video-2",
              "snippet": {
                "publishedAt": "2026-03-15T01:00:00Z",
                "channelId": "UC222",
                "channelTitle": "Two",
                "title": "Live now",
                "liveBroadcastContent": "live",
                "thumbnails": {
                  "high": { "url": "https://example.com/2.jpg" }
                }
              },
              "liveStreamingDetails": {}
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try? decoder.decode(VideoListResponse.self, from: json)

        let filtered = YouTubeSearchService.filterPlayableVideos(response?.items ?? [])
        XCTAssertEqual(filtered.map(\.id), ["video-1"])
    }
}
