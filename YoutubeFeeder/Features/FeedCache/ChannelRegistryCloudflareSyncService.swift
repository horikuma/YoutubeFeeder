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
        let context = SyncContext(logger: AppConsoleLogger.cloudflareSync, startedAt: Date(), syncID: String(UUID().uuidString.prefix(8)))
        context.logger.info("service_start")

        guard let endpointURL else {
            context.logger.error(
                "endpoint_missing",
                metadata: ["elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.startedAt)]
            )
            throw ChannelRegistryCloudflareSyncError.endpointMissing
        }

        let payloadContext = loadSyncPayloadContext(context: context)
        let body = try encodeSyncPayload(payloadContext)
        let request = makeSyncRequest(body: body, endpointURL: endpointURL)
        let (data, httpResponse, afterResponseChannelIDs) = try await sendSyncRequest(
            request,
            context: payloadContext,
            body: body
        )
        guard httpResponse.statusCode == 200 else {
            context.logger.error(
                "http_status_rejected",
                metadata: [
                    "body_preview": AppConsoleLogger.responsePreview(data),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.startedAt),
                    "status": String(httpResponse.statusCode),
                    "sync_id": context.syncID
                ]
            )
            throw ChannelRegistryCloudflareSyncError.httpError(statusCode: httpResponse.statusCode)
        }
        logSyncCompletion(context: payloadContext, data: data, httpResponse: httpResponse, afterResponseChannelIDs: afterResponseChannelIDs)
    }

    private func loadSyncPayloadContext(context: SyncContext) -> SyncPayloadContext {
        let records = ChannelRegistryStore.loadChannelRecords()
        let beforeRequestChannelIDs = records.map(\.channelID)
        let payload = ChannelRegistryCloudflareSyncPayload(
            formatVersion: 1,
            syncedAt: now(),
            channels: records
        )
        context.logger.info(
            "store_loaded",
            metadata: [
                "channels": String(records.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.startedAt),
                "local_fingerprint": AppConsoleLogger.channelIDsFingerprint(beforeRequestChannelIDs),
                "sync_id": context.syncID
            ]
        )
        return SyncPayloadContext(
            context: context,
            records: records,
            beforeRequestChannelIDs: beforeRequestChannelIDs,
            payload: payload
        )
    }

    private func encodeSyncPayload(_ payloadContext: SyncPayloadContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        do {
            let body = try encoder.encode(payloadContext.payload)
            payloadContext.context.logger.info(
                "payload_encoded",
                metadata: [
                    "body_bytes": String(body.count),
                    "channels": String(payloadContext.records.count),
                    "format_version": String(payloadContext.payload.formatVersion),
                    "local_fingerprint": AppConsoleLogger.channelIDsFingerprint(payloadContext.beforeRequestChannelIDs),
                    "sync_id": payloadContext.context.syncID
                ]
            )
            return body
        } catch {
            payloadContext.context.logger.error(
                "payload_encode_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "channels": String(payloadContext.records.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: payloadContext.context.startedAt),
                    "sync_id": payloadContext.context.syncID
                ]
            )
            throw error
        }
    }

    private func makeSyncRequest(body: Data, endpointURL: URL) -> URLRequest {
        let requestURL = Self.channelRegistryEndpointURL(from: endpointURL)
        var request = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func sendSyncRequest(
        _ request: URLRequest,
        context: SyncPayloadContext,
        body: Data
    ) async throws -> (Data, HTTPURLResponse, [String]) {
        logSyncRequestStart(context: context, request: request, body: body)
        let (data, httpResponse, afterResponseChannelIDs) = try await performSyncHTTPRequest(request, context: context)
        logSyncHTTPResponse(context: context, data: data, httpResponse: httpResponse)
        logSyncStoreRecheck(context: context, afterResponseChannelIDs: afterResponseChannelIDs)
        return (data, httpResponse, afterResponseChannelIDs)
    }

    private func performSyncHTTPRequest(
        _ request: URLRequest,
        context: SyncPayloadContext
    ) async throws -> (Data, HTTPURLResponse, [String]) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await dataLoader(request)
        } catch let error as CancellationError {
            context.context.logger.info(
                "http_request_cancelled",
                metadata: [
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.context.startedAt),
                    "sync_id": context.context.syncID
                ]
            )
            throw error
        } catch {
            context.context.logger.error(
                "http_request_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.context.startedAt),
                    "sync_id": context.context.syncID
                ]
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            context.context.logger.error(
                "http_response_invalid",
                metadata: [
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.context.startedAt),
                    "response_type": String(describing: type(of: response)),
                    "sync_id": context.context.syncID
                ]
            )
            throw ChannelRegistryCloudflareSyncError.invalidResponse
        }
        return (data, httpResponse, ChannelRegistryStore.loadAllChannelIDs())
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

    static func channelRegistryEndpointURL(from endpointURL: URL) -> URL {
        if endpointURL.lastPathComponent == "channel-registry" {
            return endpointURL
        }
        return endpointURL.appendingPathComponent("channel-registry")
    }
}

    private struct SyncPayloadContext {
        let context: SyncContext
        let records: [RegisteredChannelRecord]
        let beforeRequestChannelIDs: [String]
        let payload: ChannelRegistryCloudflareSyncPayload
}

private func logSyncRequestStart(
    context: SyncPayloadContext,
    request: URLRequest,
    body: Data
) {
    context.context.logger.info(
        "http_request_start",
        metadata: [
            "body_bytes": String(body.count),
            "endpoint_host": request.url?.host ?? "",
            "endpoint_path": request.url?.path ?? "",
            "method": request.httpMethod ?? "",
            "sync_id": context.context.syncID
        ]
    )
}

private func logSyncHTTPResponse(
    context: SyncPayloadContext,
    data: Data,
    httpResponse: HTTPURLResponse
) {
    context.context.logger.info(
        "http_response_received",
        metadata: [
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.context.startedAt),
            "response_bytes": String(data.count),
            "status": String(httpResponse.statusCode),
            "sync_id": context.context.syncID
        ]
    )
}

private func logSyncStoreRecheck(
    context: SyncPayloadContext,
    afterResponseChannelIDs: [String]
) {
    context.context.logger.info(
        "local_store_rechecked_after_response",
        metadata: [
            "after_count": String(afterResponseChannelIDs.count),
            "after_fingerprint": AppConsoleLogger.channelIDsFingerprint(afterResponseChannelIDs),
            "before_count": String(context.beforeRequestChannelIDs.count),
            "before_fingerprint": AppConsoleLogger.channelIDsFingerprint(context.beforeRequestChannelIDs),
            "changed_during_sync": afterResponseChannelIDs == context.beforeRequestChannelIDs ? "false" : "true",
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.context.startedAt),
            "sync_id": context.context.syncID
        ]
    )
}

private func logSyncCompletion(
    context: SyncPayloadContext,
    data: Data,
    httpResponse: HTTPURLResponse,
    afterResponseChannelIDs: [String]
) {
    context.context.logger.info(
        "service_complete",
        metadata: [
            "channels": String(context.records.count),
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: context.context.startedAt),
            "local_store_changed_during_sync": afterResponseChannelIDs == context.beforeRequestChannelIDs ? "false" : "true",
            "status": String(httpResponse.statusCode),
            "sync_id": context.context.syncID
    ]
    )
}

private struct SyncContext {
    let logger: AppConsoleLogger
    let startedAt: Date
    let syncID: String
}
