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

    static func compactByteCount(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
