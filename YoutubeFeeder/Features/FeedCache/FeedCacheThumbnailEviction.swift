import Foundation

struct ThumbnailEvictionResult: Hashable {
    let filename: String
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
