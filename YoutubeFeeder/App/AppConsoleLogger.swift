import Foundation

enum AppConsoleLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case error = "ERROR"
}

struct AppConsoleLogger {
    static let appLifecycle = AppConsoleLogger(scope: "app.lifecycle")
    static let youtubeSearch = AppConsoleLogger(scope: "youtube.search")

    let scope: String

    private static let prefix = "[YoutubeFeeder]"
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func debug(_ event: String, message: String? = nil, metadata: [String: String] = [:]) {
        emit(level: .debug, event: event, message: message, metadata: metadata)
    }

    func info(_ event: String, message: String? = nil, metadata: [String: String] = [:]) {
        emit(level: .info, event: event, message: message, metadata: metadata)
    }

    func notice(_ event: String, message: String? = nil, metadata: [String: String] = [:]) {
        emit(level: .notice, event: event, message: message, metadata: metadata)
    }

    func error(_ event: String, message: String? = nil, metadata: [String: String] = [:]) {
        emit(level: .error, event: event, message: message, metadata: metadata)
    }

    private func emit(level: AppConsoleLogLevel, event: String, message: String?, metadata: [String: String]) {
        let timestamp = Self.timestampFormatter.string(from: .now)
        let renderedMetadata = metadata
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Self.quoted($0.value))" }
            .joined(separator: " ")
        let renderedMessage = message.map { "message=\(Self.quoted($0))" } ?? ""
        let suffix = [renderedMetadata, renderedMessage]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if suffix.isEmpty {
            print("\(Self.prefix) \(timestamp) \(level.rawValue) \(scope).\(event)")
        } else {
            print("\(Self.prefix) \(timestamp) \(level.rawValue) \(scope).\(event) \(suffix)")
        }
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func sanitizedKeyword(_ keyword: String, limit: Int = 48) -> String {
        let normalized = keyword
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(max(limit - 3, 0))) + "..."
    }

    static func responsePreview(_ data: Data, limit: Int = 160) -> String {
        let raw = String(decoding: data, as: UTF8.self)
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

    static func mainThreadFlag() -> String {
        Thread.isMainThread ? "true" : "false"
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
