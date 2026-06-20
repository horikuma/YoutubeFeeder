import Foundation

enum ThumbnailDownloadSharePreparation {
    static func exportedShareURL(
        for video: CachedVideo,
        descriptor: ThumbnailDownloadDescriptor
    ) -> URL? {
        if AppInteractionPlatform.current.usesPrimaryClickForMenus {
            saveToDownloads(for: video, descriptor: descriptor)
            return nil
        }

        let startedAt = Date()
        AppConsoleLogger.browseTileInteraction.info(
            "thumbnail_download_share_prepare_start",
            metadata: logMetadata(video: video, descriptor: descriptor)
        )

        do {
            let exportURL = try ThumbnailDownloadExporter.exportedFileURL(for: descriptor)
            var metadata = logMetadata(video: video, descriptor: descriptor)
            metadata["export_filename"] = exportURL.lastPathComponent
            metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            AppConsoleLogger.browseTileInteraction.info(
                "thumbnail_download_share_prepare_succeeded",
                metadata: metadata
            )
            return exportURL
        } catch {
            var metadata = logMetadata(video: video, descriptor: descriptor)
            metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            AppConsoleLogger.browseTileInteraction.error(
                "thumbnail_download_share_prepare_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
            return nil
        }
    }

    private static func saveToDownloads(
        for video: CachedVideo,
        descriptor: ThumbnailDownloadDescriptor
    ) {
        let startedAt = Date()
        AppConsoleLogger.browseTileInteraction.info(
            "thumbnail_download_to_downloads_start",
            metadata: logMetadata(video: video, descriptor: descriptor)
        )

        do {
            let downloadedURL = try ThumbnailDownloadExporter.downloadedFileURL(for: descriptor)
            var metadata = logMetadata(video: video, descriptor: descriptor)
            metadata["downloaded_filename"] = downloadedURL.lastPathComponent
            metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            AppConsoleLogger.browseTileInteraction.info(
                "thumbnail_download_to_downloads_succeeded",
                metadata: metadata
            )
        } catch {
            var metadata = logMetadata(video: video, descriptor: descriptor)
            metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            AppConsoleLogger.browseTileInteraction.error(
                "thumbnail_download_to_downloads_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
        }
    }

    private static func logMetadata(
        video: CachedVideo,
        descriptor: ThumbnailDownloadDescriptor
    ) -> [String: String] {
        [
            "videoID": video.id,
            "channelID": video.channelID,
            "source_filename": descriptor.sourceURL.lastPathComponent,
            "suggested_filename": descriptor.suggestedFilename
        ]
    }
}
