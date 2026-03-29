import Foundation

struct ThumbnailEvictionResult: Hashable {
    let filename: String
    let removedBytes: Int64
}

struct ThumbnailTrimResult: Hashable {
    let removedFilenames: [String]
    let removedBytes: Int64
}

struct ThumbnailCacheThresholds: Hashable {
    let maxThumbnailCount: Int?
    let minThumbnailCount: Int?
    let maxThumbnailBytes: Int64?
    let minThumbnailBytes: Int64?
}

struct ThumbnailCacheStatus: Hashable {
    let fileCount: Int
    let totalBytes: Int64

    func exceedsUpperBound(thresholds: ThumbnailCacheThresholds) -> Bool {
        let exceedsCount = thresholds.maxThumbnailCount.map { fileCount > $0 } ?? false
        let exceedsBytes = thresholds.maxThumbnailBytes.map { totalBytes > $0 } ?? false
        return exceedsCount || exceedsBytes
    }

    func exceedsLowerBound(thresholds: ThumbnailCacheThresholds) -> Bool {
        let targetCount = thresholds.minThumbnailCount ?? thresholds.maxThumbnailCount
        let targetBytes = thresholds.minThumbnailBytes ?? thresholds.maxThumbnailBytes
        let exceedsCount = targetCount.map { fileCount > $0 } ?? false
        let exceedsBytes = targetBytes.map { totalBytes > $0 } ?? false
        return exceedsCount || exceedsBytes
    }
}

private struct ThumbnailEvictionCandidate {
    let filename: String
    let lastAccessedAt: Date?
    let bytes: Int64
}

extension FeedCacheStore {
    func evictOldestThumbnailIfNeeded(
        maxThumbnailCount: Int? = nil,
        maxThumbnailBytes: Int64? = nil
    ) -> ThumbnailEvictionResult? {
        let snapshot = loadSnapshot()
        let candidates = thumbnailEvictionCandidates(snapshot: snapshot)
        let thresholds = ThumbnailCacheThresholds(
            maxThumbnailCount: maxThumbnailCount,
            minThumbnailCount: nil,
            maxThumbnailBytes: maxThumbnailBytes,
            minThumbnailBytes: nil
        )
        let status = ThumbnailCacheStatus(
            fileCount: candidates.count,
            totalBytes: candidates.reduce(into: Int64(0)) { $0 += $1.bytes }
        )
        guard status.exceedsUpperBound(thresholds: thresholds) else { return nil }
        guard let candidate = candidates.first else { return nil }

        clearStoredThumbnailReference(filename: candidate.filename)
        removeThumbnailFile(filename: candidate.filename)
        return ThumbnailEvictionResult(filename: candidate.filename, removedBytes: candidate.bytes)
    }

    func trimThumbnailsIfNeeded(
        maxThumbnailCount: Int? = nil,
        minThumbnailCount: Int? = nil,
        maxThumbnailBytes: Int64? = nil,
        minThumbnailBytes: Int64? = nil
    ) -> ThumbnailTrimResult? {
        var candidates = thumbnailEvictionCandidates(snapshot: loadSnapshot())
        var status = ThumbnailCacheStatus(
            fileCount: candidates.count,
            totalBytes: candidates.reduce(into: Int64(0)) { $0 += $1.bytes }
        )
        let thresholds = ThumbnailCacheThresholds(
            maxThumbnailCount: maxThumbnailCount,
            minThumbnailCount: minThumbnailCount,
            maxThumbnailBytes: maxThumbnailBytes,
            minThumbnailBytes: minThumbnailBytes
        )
        guard status.exceedsUpperBound(thresholds: thresholds) else { return nil }

        var removedFilenames: [String] = []
        var removedBytes: Int64 = 0

        while let candidate = candidates.first,
              status.exceedsLowerBound(thresholds: thresholds) {
            clearStoredThumbnailReference(filename: candidate.filename)
            removeThumbnailFile(filename: candidate.filename)
            removedFilenames.append(candidate.filename)
            removedBytes += candidate.bytes
            candidates.removeFirst()
            status = ThumbnailCacheStatus(
                fileCount: candidates.count,
                totalBytes: status.totalBytes - candidate.bytes
            )
        }

        guard !removedFilenames.isEmpty else { return nil }
        return ThumbnailTrimResult(removedFilenames: removedFilenames, removedBytes: removedBytes)
    }

    func currentThumbnailCacheStatus() -> ThumbnailCacheStatus {
        let candidates = thumbnailEvictionCandidates(snapshot: loadSnapshot())
        return ThumbnailCacheStatus(
            fileCount: candidates.count,
            totalBytes: candidates.reduce(into: Int64(0)) { $0 += $1.bytes }
        )
    }

    private func thumbnailEvictionCandidates(snapshot: FeedCacheSnapshot) -> [ThumbnailEvictionCandidate] {
        let filenamesWithAccess = Dictionary(grouping: snapshot.videos.compactMap { video -> (String, Date?)? in
            guard let filename = video.thumbnailLocalFilename else { return nil }
            return (filename, video.thumbnailLastAccessedAt)
        }, by: \.0)

        return filenamesWithAccess.compactMap { filename, values in
            guard let bytes = thumbnailFileSize(filename: filename) else { return nil }
            let lastAccessedAt = values.compactMap(\.1).max()
            return ThumbnailEvictionCandidate(
                filename: filename,
                lastAccessedAt: lastAccessedAt,
                bytes: bytes
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.lastAccessedAt, rhs.lastAccessedAt) {
            case let (left?, right?) where left != right:
                return left < right
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            default:
                return lhs.filename < rhs.filename
            }
        }
    }

}
