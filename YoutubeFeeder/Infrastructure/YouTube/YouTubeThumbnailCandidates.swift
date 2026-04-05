import Foundation

enum YouTubeThumbnailCandidates {
    static let filenames = [
        "maxresdefault.jpg",
        "sddefault.jpg",
        "hqdefault.jpg",
        "mqdefault.jpg",
        "default.jpg",
    ]

    static func urls(for videoID: String) -> [URL] {
        guard !videoID.isEmpty else { return [] }
        return filenames.compactMap { filename in
            URL(string: "https://i.ytimg.com/vi/\(videoID)/\(filename)")
        }
    }

    static func preferredURL(for videoID: String) -> URL? {
        urls(for: videoID).first
    }

    static func cacheFilename(for videoID: String) -> String? {
        guard !videoID.isEmpty else { return nil }
        return "\(videoID).jpg"
    }
}
