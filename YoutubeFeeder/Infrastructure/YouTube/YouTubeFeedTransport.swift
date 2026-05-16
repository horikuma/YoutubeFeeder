import Foundation

struct YouTubeFeedTransport {
    let requestScheduler: RequestScheduler?

    func fetchScheduledData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let requestScheduler {
            return try await requestScheduler.enqueue {
                try await URLSession.shared.data(for: request)
            }
        }

        return try await URLSession.shared.data(for: request)
    }

    var resolvedAPIKey: String? {
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

struct YouTubeFeedBatching {
    static func chunked<Element>(_ elements: [Element], into size: Int) -> [[Element]] {
        guard size > 0 else { return [elements] }

        var result: [[Element]] = []
        var index = elements.startIndex
        while index < elements.endIndex {
            let nextIndex = elements.index(index, offsetBy: size, limitedBy: elements.endIndex) ?? elements.endIndex
            result.append(Array(elements[index ..< nextIndex]))
            index = nextIndex
        }

        return result
    }
}
