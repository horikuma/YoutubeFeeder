import Foundation

enum AppConsoleLoggerFormatting {
    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return formatter
    }()

    static func timestamp(for date: Date = .now) -> String {
        timestampFormatter.string(from: date)
    }

    static func renderLine(_ params: AppConsoleLogger.RenderLineParams) -> String {
        let renderedMetadata = params.metadata
            .filter { !$0.value.isEmpty }
            .filter { shouldIncludeMetadataValue($0.value, level: params.level) }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(quoted($0.value))" }
            .joined(separator: " ")
        let renderedMessage = params.message.map { "message=\(quoted($0))" } ?? ""
        let suffix = [renderedMetadata, renderedMessage]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let line = "\(AppConsoleLogger.prefix) \(params.timestamp) \(params.level.rawValue) \(params.scope).\(params.event)"
        if suffix.isEmpty {
            return jsonWrappedLine(line)
        }
        return jsonWrappedLine("\(line) \(suffix)")
    }

    static func sanitizedKeyword(_ keyword: String, limit: Int = 48) -> String {
        let normalized = keyword
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(max(limit - 3, 0))) + "..."
    }

    static func responsePreview(_ data: Data, limit: Int = 160) -> String {
        let raw = String(bytes: data, encoding: .utf8) ?? ""
        let normalized = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "([\\[{])\\s+", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\s+([\\]}])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "<\(data.count) bytes>" }
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(max(limit - 3, 0))) + "..."
    }

    static func errorSummary(_ error: Error, limit: Int = 120) -> String {
        if let decodingError = error as? DecodingError {
            return decodingErrorSummary(decodingError, limit: limit)
        }

        let normalized = error.localizedDescription
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(max(limit - 3, 0))) + "..."
    }

    static func elapsedMilliseconds(since startedAt: Date) -> String {
        String(Int(Date().timeIntervalSince(startedAt) * 1000))
    }

    static func elapsedMilliseconds(from startedAt: Date, to endedAt: Date) -> String {
        String(Int(endedAt.timeIntervalSince(startedAt) * 1000))
    }

    static func traceDurationMilliseconds(since startedAt: Date, to endedAt: Date = .now) -> String {
        elapsedMilliseconds(from: startedAt, to: endedAt)
    }

    static func mainThreadFlag() -> String {
        Thread.isMainThread ? "true" : "false"
    }

    static func channelIDsFingerprint(_ channelIDs: [String]) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in channelIDs.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private static func jsonWrappedLine(_ line: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: ["line": line], options: [.sortedKeys]),
            let string = String(bytes: data, encoding: .utf8)
        else {
            return line
        }

        return string
    }

    private static func shouldIncludeMetadataValue(_ value: String, level: AppConsoleLogLevel) -> Bool {
        guard level == .info else { return true }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !(trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func decodingErrorSummary(_ error: DecodingError, limit: Int) -> String {
        let detail: String
        switch error {
        case let .keyNotFound(key, context):
            detail = "keyNotFound path=\(codingPath(context.codingPath + [key]))"
        case let .valueNotFound(type, context):
            detail = "valueNotFound type=\(type) path=\(codingPath(context.codingPath))"
        case let .typeMismatch(type, context):
            detail = "typeMismatch type=\(type) path=\(codingPath(context.codingPath))"
        case let .dataCorrupted(context):
            detail = "dataCorrupted path=\(codingPath(context.codingPath)) description=\(context.debugDescription)"
        @unknown default:
            detail = error.localizedDescription
        }

        let normalized = detail
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(max(limit - 3, 0))) + "..."
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        let rendered = path.map { key -> String in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }
            return key.stringValue
        }
        return rendered.joined(separator: ".")
    }
}
