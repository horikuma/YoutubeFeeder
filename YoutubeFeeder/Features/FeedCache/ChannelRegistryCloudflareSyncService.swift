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
        let logger = AppConsoleLogger.cloudflareSync
        let startedAt = Date()
        logger.info("service_start")

        guard let endpointURL else {
            logger.error(
                "endpoint_missing",
                metadata: ["elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
            )
            throw ChannelRegistryCloudflareSyncError.endpointMissing
        }

        let records = ChannelRegistryStore.loadChannelRecords()
        let payload = ChannelRegistryCloudflareSyncPayload(
            formatVersion: 1,
            syncedAt: now(),
            channels: records
        )
        logger.info(
            "store_loaded",
            metadata: [
                "channels": String(records.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let body: Data
        do {
            body = try encoder.encode(payload)
        } catch {
            logger.error(
                "payload_encode_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "channels": String(records.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            throw error
        }

        logger.info(
            "payload_encoded",
            metadata: [
                "body_bytes": String(body.count),
                "channels": String(records.count),
                "format_version": String(payload.formatVersion)
            ]
        )

        var request = URLRequest(
            url: endpointURL.appendingPathComponent("channel-registry"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        logger.info(
            "http_request_start",
            metadata: [
                "body_bytes": String(body.count),
                "endpoint_host": request.url?.host ?? "",
                "endpoint_path": request.url?.path ?? "",
                "method": request.httpMethod ?? ""
            ]
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await dataLoader(request)
        } catch let error as CancellationError {
            logger.notice(
                "http_request_cancelled",
                metadata: ["elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
            )
            throw error
        } catch {
            logger.error(
                "http_request_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: ["elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error(
                "http_response_invalid",
                metadata: [
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    "response_type": String(describing: type(of: response))
                ]
            )
            throw ChannelRegistryCloudflareSyncError.invalidResponse
        }
        logger.info(
            "http_response_received",
            metadata: [
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "response_bytes": String(data.count),
                "status": String(httpResponse.statusCode)
            ]
        )
        guard httpResponse.statusCode == 200 else {
            logger.error(
                "http_status_rejected",
                metadata: [
                    "body_preview": AppConsoleLogger.responsePreview(data),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    "status": String(httpResponse.statusCode)
                ]
            )
            throw ChannelRegistryCloudflareSyncError.httpError(statusCode: httpResponse.statusCode)
        }
        logger.notice(
            "service_complete",
            metadata: [
                "channels": String(records.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "status": String(httpResponse.statusCode)
            ]
        )
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
