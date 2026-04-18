import Foundation

enum YouTubeFeedResponseDiagnostics {
    static func responseMetadata(
        channelID: String,
        httpResponse: HTTPURLResponse?,
        data: Data,
        elapsedMilliseconds: String
    ) -> [String: String] {
        let text = String(decoding: data.prefix(4096), as: UTF8.self)
        return [
            "channelID": channelID,
            "status": httpResponse.map { String($0.statusCode) } ?? "nil",
            "content_type": httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "",
            "bytes": String(data.count),
            "elapsed_ms": elapsedMilliseconds,
            "has_feed_tag": text.contains("<feed") ? "true" : "false",
            "has_html_tag": containsHTML(in: text) ? "true" : "false",
            "raw_entry_tags": String(countOccurrences(of: "<entry", in: text)),
            "raw_video_id_tags": String(countOccurrences(of: "<yt:videoId", in: text)),
            "body_preview": AppConsoleLogger.responsePreview(data)
        ]
    }

    static func parseMetadata(
        channelID: String,
        httpResponse: HTTPURLResponse?,
        data: Data,
        parsedVideos: [YouTubeVideo]
    ) -> [String: String] {
        let text = String(decoding: data.prefix(4096), as: UTF8.self)
        let rawEntryCount = countOccurrences(of: "<entry", in: text)
        let rawVideoIDCount = countOccurrences(of: "<yt:videoId", in: text)
        return [
            "channelID": channelID,
            "status": httpResponse.map { String($0.statusCode) } ?? "nil",
            "bytes": String(data.count),
            "raw_entry_tags": String(rawEntryCount),
            "raw_video_id_tags": String(rawVideoIDCount),
            "parsed_videos": String(parsedVideos.count),
            "first_video_id": parsedVideos.first?.id ?? "",
            "latest_published_at": dateMetadata(parsedVideos.compactMap(\.publishedAt).max()),
            "diagnosis": zeroVideoDiagnosis(
                statusCode: httpResponse?.statusCode,
                data: data,
                hasHTML: containsHTML(in: text),
                hasFeed: text.contains("<feed"),
                rawEntryCount: rawEntryCount,
                rawVideoIDCount: rawVideoIDCount,
                parsedVideoCount: parsedVideos.count
            )
        ]
    }

    private static func zeroVideoDiagnosis(
        statusCode: Int?,
        data: Data,
        hasHTML: Bool,
        hasFeed: Bool,
        rawEntryCount: Int,
        rawVideoIDCount: Int,
        parsedVideoCount: Int
    ) -> String {
        guard parsedVideoCount == 0 else { return "parsed_videos_present" }
        if data.isEmpty { return "empty_body" }
        if let statusCode, !(200...299).contains(statusCode) { return "non_2xx_response" }
        if hasHTML { return "html_response" }
        if !hasFeed { return "missing_feed_tag" }
        if rawEntryCount == 0 { return "feed_without_entries" }
        if rawVideoIDCount == 0 { return "entries_without_video_ids" }
        return "parser_zero_with_video_ids"
    }

    private static func containsHTML(in text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("<html") || lowercased.contains("<!doctype html")
    }

    private static func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
        }
        return count
    }

    private static func dateMetadata(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return String(format: "%.3f", date.timeIntervalSince1970)
    }
}
