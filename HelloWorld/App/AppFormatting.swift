import Foundation

enum AppFormatting {
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    static func compactViewCount(_ value: Int?) -> String {
        guard let value else { return "--回" }
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM回", Double(value) / 1_000_000).replacingOccurrences(of: ".0", with: "")
        case 10_000...:
            return String(format: "%.1f万回", Double(value) / 10_000).replacingOccurrences(of: ".0", with: "")
        case 1_000...:
            return String(format: "%.1fK回", Double(value) / 1_000).replacingOccurrences(of: ".0", with: "")
        default:
            return "\(value)回"
        }
    }

    static func videoTileBadgeText(index: Int?, durationSeconds: Int?, viewCount: Int?) -> String {
        let indexText = String(index ?? 0)
        let durationText = formattedPlaybackDuration(durationSeconds)
        let bucketText = durationBucketLabel(durationSeconds)
        return "\(indexText) : \(durationText) \(compactViewCount(viewCount)) (\(bucketText))"
    }

    static func compactByteCount(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private static func formattedPlaybackDuration(_ durationSeconds: Int?) -> String {
        guard let durationSeconds, durationSeconds >= 0 else { return "--s" }

        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return "\(hours)h\(minutes)m\(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m\(seconds)s"
        }
        return "\(seconds)s"
    }

    private static func durationBucketLabel(_ durationSeconds: Int?) -> String {
        guard let durationSeconds else { return "--" }
        return durationSeconds >= 20 * 60 ? "L" : "M"
    }
}
