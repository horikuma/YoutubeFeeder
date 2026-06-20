import XCTest
@testable import YoutubeFeeder

final class ThumbnailDownloadPolicyTests: LoggedTestCase {
    func testDescriptorUsesCachedThumbnailAndVideoTitleFilename() throws {
        let fileManager = FileManager.default
        try withFeedCacheBaseDirectory(temporaryDirectory().appendingPathComponent("FeedCache", isDirectory: true)) {
            let video = makeVideo(
                title: "Sample/Video:Title?",
                thumbnailLocalFilename: "video-1.webp"
            )

            let descriptor = try XCTUnwrap(ThumbnailDownloadPolicy.descriptor(for: video, fileManager: fileManager))

            XCTAssertEqual(descriptor.sourceURL.lastPathComponent, "video-1.webp")
            XCTAssertEqual(descriptor.suggestedFilename, "Sample-Video-Title-.webp")
        }
    }

    func testDescriptorReturnsNilWithoutCachedThumbnail() {
        let video = makeVideo(title: "Sample", thumbnailLocalFilename: nil)

        XCTAssertNil(ThumbnailDownloadPolicy.descriptor(for: video))
    }

    func testSuggestedFilenameFallsBackToVideoIDAndJpgExtension() {
        let filename = ThumbnailDownloadPolicy.suggestedFilename(
            title: "   ",
            fallback: "video-1",
            sourceURL: URL(fileURLWithPath: "/tmp/video-1")
        )

        XCTAssertEqual(filename, "video-1.jpg")
    }

    func testExporterCopiesThumbnailToSuggestedFilename() throws {
        let fileManager = FileManager.default
        let temporaryRoot = temporaryDirectory()
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let sourceURL = temporaryRoot.appendingPathComponent("source.jpg")
        try Data("thumbnail".utf8).write(to: sourceURL)

        let exportURL = try ThumbnailDownloadExporter.exportedFileURL(
            for: ThumbnailDownloadDescriptor(sourceURL: sourceURL, suggestedFilename: "Video Title.jpg"),
            fileManager: fileManager
        )

        XCTAssertEqual(exportURL.lastPathComponent, "Video Title.jpg")
        XCTAssertEqual(try Data(contentsOf: exportURL), Data("thumbnail".utf8))
    }

    func testExporterCopiesThumbnailToDownloadsDirectory() throws {
        let fileManager = FileManager.default
        let temporaryRoot = temporaryDirectory()
        let downloadsDirectory = temporaryRoot.appendingPathComponent("Downloads", isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let sourceURL = temporaryRoot.appendingPathComponent("source.jpg")
        try Data("thumbnail".utf8).write(to: sourceURL)

        let downloadedURL = try ThumbnailDownloadExporter.downloadedFileURL(
            for: ThumbnailDownloadDescriptor(sourceURL: sourceURL, suggestedFilename: "Video Title.jpg"),
            downloadsDirectory: downloadsDirectory,
            fileManager: fileManager
        )

        XCTAssertEqual(downloadedURL.deletingLastPathComponent(), downloadsDirectory)
        XCTAssertEqual(downloadedURL.lastPathComponent, "Video Title.jpg")
        XCTAssertEqual(try Data(contentsOf: downloadedURL), Data("thumbnail".utf8))
    }

    func testExporterUsesNumberedFilenameWhenDownloadsFileExists() throws {
        let fileManager = FileManager.default
        let temporaryRoot = temporaryDirectory()
        let downloadsDirectory = temporaryRoot.appendingPathComponent("Downloads", isDirectory: true)
        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        let sourceURL = temporaryRoot.appendingPathComponent("source.jpg")
        try Data("thumbnail".utf8).write(to: sourceURL)
        try Data("existing".utf8).write(to: downloadsDirectory.appendingPathComponent("Video Title.jpg"))

        let downloadedURL = try ThumbnailDownloadExporter.downloadedFileURL(
            for: ThumbnailDownloadDescriptor(sourceURL: sourceURL, suggestedFilename: "Video Title.jpg"),
            downloadsDirectory: downloadsDirectory,
            fileManager: fileManager
        )

        XCTAssertEqual(downloadedURL.lastPathComponent, "Video Title 2.jpg")
        XCTAssertEqual(try Data(contentsOf: downloadedURL), Data("thumbnail".utf8))
    }

    private func makeVideo(title: String, thumbnailLocalFilename: String?) -> CachedVideo {
        CachedVideo(
            id: "video-1",
            channelID: "UC_TEST",
            channelTitle: "Test Channel",
            title: title,
            publishedAt: Date(timeIntervalSince1970: 1_000),
            videoURL: URL(string: "https://www.youtube.com/watch?v=video-1"),
            thumbnailRemoteURL: nil,
            thumbnailLocalFilename: thumbnailLocalFilename,
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            searchableText: title,
            durationSeconds: 600,
            viewCount: 100
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
