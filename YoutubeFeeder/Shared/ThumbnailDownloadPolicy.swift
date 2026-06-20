import Foundation

struct ThumbnailDownloadDescriptor: Equatable {
    let sourceURL: URL
    let suggestedFilename: String
}

enum ThumbnailDownloadPolicy {
    static func descriptor(for video: CachedVideo, fileManager: FileManager = .default) -> ThumbnailDownloadDescriptor? {
        guard let localFilename = video.thumbnailLocalFilename, !localFilename.isEmpty else { return nil }

        let sourceURL = FeedCachePaths.thumbnailURL(filename: localFilename, fileManager: fileManager)
        return ThumbnailDownloadDescriptor(
            sourceURL: sourceURL,
            suggestedFilename: suggestedFilename(title: video.title, fallback: video.id, sourceURL: sourceURL)
        )
    }

    static func suggestedFilename(title: String, fallback: String, sourceURL: URL) -> String {
        let basename = sanitizedBasename(title, fallback: fallback)
        let pathExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        return "\(basename).\(pathExtension)"
    }

    static func sanitizedBasename(_ rawValue: String, fallback: String) -> String {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmedValue.isEmpty ? fallback : trimmedValue
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")

        let sanitizedScalars = source.unicodeScalars.map { scalar -> Character in
            if invalidCharacters.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) {
                return "-"
            }
            return Character(scalar)
        }

        let sanitized = String(sanitizedScalars)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return sanitized.isEmpty ? "thumbnail" : sanitized
    }
}

enum ThumbnailDownloadExporter {
    enum ExportError: Error {
        case downloadsDirectoryUnavailable
    }

    static func exportedFileURL(
        for descriptor: ThumbnailDownloadDescriptor,
        fileManager: FileManager = .default
    ) throws -> URL {
        let exportDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("YoutubeFeederThumbnailDownloads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let destinationURL = exportDirectory.appendingPathComponent(descriptor.suggestedFilename)
        try fileManager.copyItem(at: descriptor.sourceURL, to: destinationURL)
        return destinationURL
    }

    static func downloadedFileURL(
        for descriptor: ThumbnailDownloadDescriptor,
        downloadsDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let downloadsDirectory = downloadsDirectory ?? fileManager.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first else {
            throw ExportError.downloadsDirectoryUnavailable
        }

        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        let destinationURL = availableDestinationURL(
            in: downloadsDirectory,
            filename: descriptor.suggestedFilename,
            fileManager: fileManager
        )
        try fileManager.copyItem(at: descriptor.sourceURL, to: destinationURL)
        return destinationURL
    }

    private static func availableDestinationURL(
        in directory: URL,
        filename: String,
        fileManager: FileManager
    ) -> URL {
        let originalURL = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: originalURL.path) else { return originalURL }

        let extensionSeparatorIndex = filename.lastIndex(of: ".")
        let basename = extensionSeparatorIndex.map { String(filename[..<$0]) } ?? filename
        let pathExtension = extensionSeparatorIndex.map { String(filename[filename.index(after: $0)...]) }

        var candidateIndex = 2
        while true {
            let candidateFilename = pathExtension.map { "\(basename) \(candidateIndex).\($0)" } ?? "\(basename) \(candidateIndex)"
            let candidateURL = directory.appendingPathComponent(candidateFilename)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            candidateIndex += 1
        }
    }
}
