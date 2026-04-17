import Foundation

struct ChannelRegistryCloudflareSyncPayload: Codable, Hashable {
    let formatVersion: Int
    let syncedAt: Date
    let channels: [RegisteredChannelRecord]
}

enum ChannelRegistryCloudflareSyncError: LocalizedError, Equatable {
    case endpointMissing
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .endpointMissing:
            return "Cloudflare Worker の送信先 URL が未設定です。"
        case .invalidResponse:
            return "Cloudflare Worker の応答を読み取れませんでした。"
        case let .httpError(statusCode):
            return "Cloudflare Worker への同期に失敗しました。(status: \(statusCode))"
        }
    }
}

struct ChannelRegistryCloudflareSyncService {
    let endpointURL: URL?
    let dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    let now: @Sendable () -> Date

    init(
        endpointURL: URL? = Self.resolvedEndpointURL(),
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.endpointURL = endpointURL
        self.dataLoader = dataLoader
        self.now = now
    }

    var isConfigured: Bool {
        endpointURL != nil
    }

    func syncChannelRegistry() async throws {
        guard let endpointURL else {
            throw ChannelRegistryCloudflareSyncError.endpointMissing
        }

        let payload = ChannelRegistryCloudflareSyncPayload(
            formatVersion: 1,
            syncedAt: now(),
            channels: ChannelRegistryStore.loadChannelRecords()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let body = try encoder.encode(payload)
        var request = URLRequest(
            url: endpointURL.appendingPathComponent("channel-registry"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await dataLoader(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChannelRegistryCloudflareSyncError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ChannelRegistryCloudflareSyncError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private static func resolvedEndpointURL() -> URL? {
        let environmentKey = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_CLOUDFLARE_WORKER_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentKey, !environmentKey.isEmpty {
            return URL(string: environmentKey)
        }

        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "CloudflareWorkerURL") as? String {
            let trimmed = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") {
                return URL(string: trimmed)
            }
        }

        return nil
    }
}
