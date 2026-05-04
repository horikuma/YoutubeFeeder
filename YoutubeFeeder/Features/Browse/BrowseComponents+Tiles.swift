import SwiftUI

extension View {
    func listInsertionTransition() -> some View {
        transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ChannelSummaryTileAppearance {
    case navigation
    case unselected
    case selected

    var gradientColors: [Color] {
        switch self {
        case .navigation:
            [.teal, .blue]
        case .unselected:
            [.teal.opacity(0.8), .blue.opacity(0.8)]
        case .selected:
            [.cyan, .blue]
        }
    }

    var thumbnailOpacity: Double {
        switch self {
        case .navigation:
            1.0
        case .unselected:
            0.78
        case .selected:
            0.92
        }
    }

    var overlayOpacity: Double {
        switch self {
        case .navigation:
            0.75
        case .unselected, .selected:
            0.78
        }
    }

    var isSelected: Bool {
        if case .selected = self {
            return true
        }
        return false
    }
}

private struct ChannelTile: View {
    let item: ChannelBrowseItem
    let appearance: ChannelSummaryTileAppearance
    let index: Int?
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: appearance.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let latestVideo = item.latestVideo {
                    ThumbnailView(video: latestVideo, contentMode: .fill)
                        .opacity(appearance.thumbnailOpacity)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(appearance.overlayOpacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                TileHighlightBorder(
                    isHovered: isHovered && !appearance.isSelected,
                    isSelected: appearance.isSelected
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.channelDisplayTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("\(item.cachedVideoCount)件")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(item.latestPublishedAtText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    TileIndexBadge(index: index)
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ChannelNavigationTile: View {
    let item: ChannelBrowseItem
    let index: Int?
    @State private var isHovered = false

    var body: some View {
        ChannelTile(item: item, appearance: .navigation, index: index, isHovered: isHovered)
            .onHover {
                isHovered = $0
                AppConsoleLogger.browseTileInteraction.debug(
                    "tile_hover_state_changed",
                    metadata: [
                        "kind": "channel_navigation",
                        "channelID": item.channelID,
                        "isHovered": "\($0)"
                    ]
                )
            }
    }
}

struct ChannelSelectionTile: View {
    let item: ChannelBrowseItem
    let isSelected: Bool
    let index: Int?
    @State private var isHovered = false

    var body: some View {
        ChannelTile(
            item: item,
            appearance: isSelected ? .selected : .unselected,
            index: index,
            isHovered: isHovered
        )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onHover {
                isHovered = $0
                AppConsoleLogger.browseTileInteraction.debug(
                    "tile_hover_state_changed",
                    metadata: [
                        "kind": "channel_selection",
                        "channelID": item.channelID,
                        "isSelected": "\(isSelected)",
                        "isHovered": "\($0)"
                    ]
                )
            }
    }
}

struct VideoHeroTile: View {
    let video: CachedVideo
    let index: Int?
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ThumbnailView(video: video, contentMode: .fill)
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(video.channelDisplayTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Text(video.publishedAtText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .overlay(alignment: .bottomTrailing) {
                VideoMetadataBadge(video: video)
                    .padding(14)
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    TileIndexBadge(index: index)
                        .padding(12)
                }
            }
            .overlay {
                TileHighlightBorder(isHovered: isHovered, isSelected: false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct TileIndexBadge: View {
    let index: Int

    var body: some View {
        Text("\(index)")
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.7), in: Capsule())
    }
}

private struct VideoMetadataBadge: View {
    let video: CachedVideo

    var body: some View {
        Text(video.metadataBadgeText)
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.72), in: Capsule())
    }
}

struct ThumbnailView: View {
    private static let referenceStore = FeedCacheStore()
    private static let writeService = FeedCacheWriteService(
        store: FeedCacheStore(),
        remoteSearchCacheStore: RemoteVideoSearchCacheStore()
    )

    let video: CachedVideo
    var contentMode: ContentMode = .fill
    @State private var cachedThumbnail: CachedThumbnailReference?
    @State private var lastTrackedFilename: String?

    var body: some View {
        Group {
            if let filename = localFilename {
                AsyncImage(url: FeedCachePaths.thumbnailURL(filename: filename)) { image in
                    image.resizable().aspectRatio(contentMode: contentMode)
                } placeholder: {
                    placeholder
                }
                .task(id: filename) {
                    guard lastTrackedFilename != filename else { return }
                    lastTrackedFilename = filename
                    await Self.referenceStore.recordThumbnailReference(filename: filename)
                }
            } else {
                placeholder
                    .task(id: video.id) {
                        guard video.thumbnailRemoteURL != nil else { return }
                        if cachedThumbnail?.videoID == video.id { return }
                        if let filename = await Self.writeService.cacheThumbnail(for: video) {
                            cachedThumbnail = CachedThumbnailReference(videoID: video.id, filename: filename)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var localFilename: String? {
        if let filename = video.thumbnailLocalFilename {
            return filename
        }
        if cachedThumbnail?.videoID == video.id {
            return cachedThumbnail?.filename
        }
        return nil
    }

    private struct CachedThumbnailReference {
        let videoID: String
        let filename: String
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.gray.opacity(0.18))
    }
}

struct BackSwipePopModifier: ViewModifier {
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            if !path.isEmpty {
                Color.clear
                    .frame(width: BackSwipePolicy.activeRegionWidth)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                if BackSwipePolicy.shouldNavigateBack(startX: value.startLocation.x, translation: value.translation) {
                                    path.removeLast()
                                }
                            }
                    )
            }
        }
    }
}
