import Foundation

struct ThumbnailEvictionResult: Hashable {
    let filename: String
    let removedBytes: Int64
}

struct ThumbnailTrimResult: Hashable {
    let removedFilenames: [String]
    let removedBytes: Int64
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
        let totalBytes = candidates.reduce(into: Int64(0)) { $0 += $1.bytes }
        let exceedsCount = maxThumbnailCount.map { candidates.count > $0 } ?? false
        let exceedsBytes = maxThumbnailBytes.map { totalBytes > $0 } ?? false
        guard exceedsCount || exceedsBytes else { return nil }
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
        let totalBytes = candidates.reduce(into: Int64(0)) { $0 += $1.bytes }
        let exceedsUpperCount = maxThumbnailCount.map { candidates.count > $0 } ?? false
        let exceedsUpperBytes = maxThumbnailBytes.map { totalBytes > $0 } ?? false
        guard exceedsUpperCount || exceedsUpperBytes else { return nil }

        var removedFilenames: [String] = []
        var removedBytes: Int64 = 0
        var remainingCount = candidates.count
        var remainingBytes = totalBytes

        while let candidate = candidates.first,
              exceedsLowerBound(
                count: remainingCount,
                bytes: remainingBytes,
                minThumbnailCount: minThumbnailCount,
                maxThumbnailCount: maxThumbnailCount,
                minThumbnailBytes: minThumbnailBytes,
                maxThumbnailBytes: maxThumbnailBytes
              ) {
            clearStoredThumbnailReference(filename: candidate.filename)
            removeThumbnailFile(filename: candidate.filename)
            removedFilenames.append(candidate.filename)
            removedBytes += candidate.bytes
            candidates.removeFirst()
            remainingCount = candidates.count
            remainingBytes -= candidate.bytes
        }

        guard !removedFilenames.isEmpty else { return nil }
        return ThumbnailTrimResult(removedFilenames: removedFilenames, removedBytes: removedBytes)
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

    private func exceedsLowerBound(
        count: Int,
        bytes: Int64,
        minThumbnailCount: Int?,
        maxThumbnailCount: Int?,
        minThumbnailBytes: Int64?,
        maxThumbnailBytes: Int64?
    ) -> Bool {
        let targetCount = minThumbnailCount ?? maxThumbnailCount
        let targetBytes = minThumbnailBytes ?? maxThumbnailBytes
        let exceedsCount = targetCount.map { count > $0 } ?? false
        let exceedsBytes = targetBytes.map { bytes > $0 } ?? false
        return exceedsCount || exceedsBytes
    }
}
