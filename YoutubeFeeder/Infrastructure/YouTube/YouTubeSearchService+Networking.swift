import Foundation

extension YouTubeSearchService {
    func loadData(
        for request: URLRequest,
        endpoint: String,
        metadata: [String: String]
    ) async throws -> Data {
        let startedAt = Date()
        let logger = AppConsoleLogger.youtubeSearch
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await dataLoader(request)
        } catch {
            let transportMetadata = transportFailureMetadata(metadata, endpoint: endpoint, startedAt: startedAt, error: error)
            logTransportFailure(error, metadata: transportMetadata, logger: logger)
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("response_invalid", message: "HTTP response を取得できませんでした。", metadata: invalidResponseMetadata(
                metadata,
                endpoint: endpoint,
                startedAt: startedAt
            ))
            throw YouTubeSearchError.invalidResponse
        }

        let responseMetadata = successMetadata(
            metadata,
            endpoint: endpoint,
            startedAt: startedAt,
            response: httpResponse,
            data: data
        )

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            logger.error(
                "http_failure",
                message: "YouTube API が失敗しました。",
                metadata: responseMetadata.merging(
                    ["body_preview": AppConsoleLogger.responsePreview(data)],
                    uniquingKeysWith: { _, new in new }
                )
            )
            throw YouTubeSearchError.httpError(statusCode: httpResponse.statusCode)
        }

        logger.info("http_success", metadata: responseMetadata)
        return data
    }

    func decodeResponse<Response: Decodable>(
        _ type: Response.Type,
        from data: Data,
        endpoint: String,
        metadata: [String: String]
    ) throws -> Response {
        do {
            return try JSONDecoder.youtubeAPI.decode(type, from: data)
        } catch {
            let decodeMetadata = metadata.merging(
                ["endpoint": endpoint, "body_preview": AppConsoleLogger.responsePreview(data)],
                uniquingKeysWith: { _, new in new }
            )
            AppConsoleLogger.youtubeSearch.error(
                "decode_failure",
                message: AppConsoleLogger.errorSummary(error),
                metadata: decodeMetadata
            )
            throw error
        }
    }

    private func transportFailureMetadata(
        _ metadata: [String: String],
        endpoint: String,
        startedAt: Date,
        error: Error
    ) -> [String: String] {
        metadata.merging(
            [
                "endpoint": endpoint,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
            ],
            uniquingKeysWith: { _, new in new }
        )
    }

    private func logTransportFailure(
        _ error: Error,
        metadata: [String: String],
        logger: AppConsoleLogger
    ) {
        if RemoteSearchErrorPolicy.isCancellation(error) {
            logger.info("http_cancelled", metadata: metadata)
        } else {
            logger.error(
                "http_transport_failure",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
        }
    }

    private func invalidResponseMetadata(
        _ metadata: [String: String],
        endpoint: String,
        startedAt: Date
    ) -> [String: String] {
        metadata.merging(
            ["endpoint": endpoint, "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)],
            uniquingKeysWith: { _, new in new }
        )
    }

    private func successMetadata(
        _ metadata: [String: String],
        endpoint: String,
        startedAt: Date,
        response: HTTPURLResponse,
        data: Data
    ) -> [String: String] {
        metadata.merging(
            [
                "endpoint": endpoint,
                "status": String(response.statusCode),
                "bytes": String(data.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        ) { _, new in new }
    }
}
