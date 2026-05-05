import Foundation

struct ResolvedYouTubeChannel: Hashable {
    let channelID: String
}

enum ChannelResolutionError: LocalizedError {
    case invalidInput
    case unresolvedChannelID

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "チャンネル ID、@handle、YouTube のチャンネル URL、または動画 URL を入力してください。"
        case .unresolvedChannelID:
            return "チャンネル ID を解決できませんでした。入力内容を確認してください。"
        }
    }
}

enum YouTubeChannelInput {
    static func directChannelID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if matchesChannelID(trimmed) {
            return trimmed
        }

        guard let url = URL(string: trimmed), let host = url.host()?.lowercased() else {
            return nil
        }

        guard host.contains("youtube.com") else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        if let channelIndex = components.firstIndex(of: "channel"), components.indices.contains(channelIndex + 1) {
            let candidate = components[channelIndex + 1]
            return matchesChannelID(candidate) ? candidate : nil
        }

        return components.first(where: { matchesChannelID($0) })
    }

    static func normalizedVideoURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            let host = url.host()?.lowercased()
        else {
            return nil
        }

        guard scheme == "http" || scheme == "https" else {
            return nil
        }

        if host == "youtu.be" {
            let components = url.pathComponents.filter { $0 != "/" }
            guard let videoID = components.first, !videoID.isEmpty else {
                return nil
            }
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        guard host.contains("youtube.com") else {
            return nil
        }

        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if url.path == "/watch",
           let videoID = urlComponents.queryItems?.first(where: { $0.name == "v" })?.value,
           !videoID.isEmpty {
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        let components = url.pathComponents.filter { $0 != "/" }
        if components.first == "shorts", components.count > 1 {
            return URL(string: "https://www.youtube.com/watch?v=\(components[1])")
        }

        return nil
    }

    static func lookupURL(from input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChannelResolutionError.invalidInput
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        guard !handle.isEmpty else {
            throw ChannelResolutionError.invalidInput
        }

        guard let url = URL(string: "https://www.youtube.com/@\(handle)") else {
            throw ChannelResolutionError.invalidInput
        }

        return url
    }

    static func extractChannelID(from html: String) -> String? {
        let patterns = [
            #""externalId":"(UC[0-9A-Za-z_-]{22})""#,
            #""channelId":"(UC[0-9A-Za-z_-]{22})""#,
            #""browseId":"(UC[0-9A-Za-z_-]{22})""#,
            #"https://www\.youtube\.com/channel/(UC[0-9A-Za-z_-]{22})"#
        ]

        for pattern in patterns {
            if let match = firstMatch(in: html, pattern: pattern) {
                return match
            }
        }

        return nil
    }

    private static func matchesChannelID(_ value: String) -> Bool {
        value.range(of: #"^UC[0-9A-Za-z_-]{22}$"#, options: .regularExpression) != nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[captureRange])
    }
}

struct YouTubeChannelResolver {
    func resolve(input: String) async throws -> ResolvedYouTubeChannel {
        if let directChannelID = YouTubeChannelInput.directChannelID(from: input) {
            return ResolvedYouTubeChannel(channelID: directChannelID)
        }

        let lookupURL: URL
        if let normalizedVideoURL = YouTubeChannelInput.normalizedVideoURL(from: input) {
            lookupURL = normalizedVideoURL
        } else {
            lookupURL = try YouTubeChannelInput.lookupURL(from: input)
        }
        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        let html = String(bytes: data, encoding: .utf8) ?? ""

        guard let channelID = YouTubeChannelInput.extractChannelID(from: html) else {
            throw ChannelResolutionError.unresolvedChannelID
        }

        return ResolvedYouTubeChannel(channelID: channelID)
    }
}
