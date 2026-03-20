import Foundation

enum FeedCachePersistenceCoders {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISO8601Formatter = ISO8601DateFormatter()

    static func makeEncoder(prettyPrinted: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            if let timestamp = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }

            let value = try container.decode(String.self)
            if let date = iso8601Formatter.date(from: value) ?? fallbackISO8601Formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date value: \(value)"
            )
        }
        return decoder
    }

    static func makeSummaryEncoder() -> PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }

    static func makeSummaryDecoder() -> PropertyListDecoder {
        PropertyListDecoder()
    }
}
