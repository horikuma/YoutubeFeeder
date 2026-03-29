import SwiftUI
import UIKit

struct InteractiveListView<Content: View>: View {
    let title: String
    let subtitle: String
    let coordinator: FeedCacheCoordinator
    @Binding var path: NavigationPath
    let layout: AppLayout
    let onRefresh: (() async -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(layout.isPad ? .system(size: 34, weight: .black, design: .rounded) : .largeTitle.bold())
                    .accessibilityIdentifier("screen.title")

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                content()
            }
            .frame(maxWidth: layout.readableContentWidth ?? layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
        .refreshable {
            guard let onRefresh else { return }
            await onRefresh()
        }
        .onAppear {
            coordinator.suspendLiveUpdates()
        }
        .onDisappear {
            coordinator.resumeLiveUpdates()
        }
    }
}

struct TileMenuAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void
}

private struct TileActionMenuModifier: ViewModifier {
    let actions: [TileMenuAction]
    @State private var isShowingMenu = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        isShowingMenu = true
                    }
            )
            .confirmationDialog("", isPresented: $isShowingMenu, titleVisibility: .hidden) {
                if actions.isEmpty {
                    Button("未定義") {}
                } else {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        Button(action.title, role: action.role) {
                            action.action()
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
    }
}

extension View {
    func tileActionMenu(actions: [TileMenuAction]) -> some View {
        modifier(TileActionMenuModifier(actions: actions))
    }
}

struct VideoTile: View {
    let video: CachedVideo
    let tapAction: (() -> Void)?
    let openVideoAction: (() -> Void)?
    let removeChannel: (() -> Void)?
    let index: Int?
    @State private var shareURL: URL?

    var body: some View {
        let menuActions = buildMenuActions()
        let tile = VideoHeroTile(video: video, index: index)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .tileActionMenu(actions: menuActions)
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL {
                    ActivityShareSheet(activityItems: [shareURL])
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("長押しでメニューを開きます")
            .accessibilityIdentifier("video.tile.\(video.id)")

        if let tapAction {
            Button(action: tapAction) {
                tile
            }
            .buttonStyle(.plain)
        } else {
            tile
        }
    }

    private func buildMenuActions() -> [TileMenuAction] {
        var actions: [TileMenuAction] = []

        if let shareURL = VideoSharePolicy.shareURL(for: video) {
            actions.append(
                TileMenuAction(title: "共有", role: nil) {
                    self.shareURL = shareURL
                }
            )
        }

        if let openVideoAction {
            actions.append(
                TileMenuAction(title: "YouTubeで開く", role: nil) {
                    openVideoAction()
                }
            )
        }

        if let removeChannel {
            actions.append(
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    removeChannel()
                }
            )
        }

        return actions
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
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

    var selectionBorderColor: Color {
        switch self {
        case .selected:
            .white.opacity(0.95)
        case .navigation, .unselected:
            .clear
        }
    }
}

fileprivate struct ChannelTile: View {
    let item: ChannelBrowseItem
    let appearance: ChannelSummaryTileAppearance
    let index: Int?

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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(appearance.selectionBorderColor, lineWidth: 3)
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

    var body: some View {
        ChannelTile(item: item, appearance: .navigation, index: index)
    }
}

struct ChannelSelectionTile: View {
    let item: ChannelBrowseItem
    let isSelected: Bool
    let index: Int?

    var body: some View {
        ChannelTile(
            item: item,
            appearance: isSelected ? .selected : .unselected,
            index: index
        )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct VideoHeroTile: View {
    let video: CachedVideo
    let index: Int?

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

    let video: CachedVideo
    var contentMode: ContentMode = .fill
    @State private var lastTrackedFilename: String?

    var body: some View {
        Group {
            if let filename = video.thumbnailLocalFilename {
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
            } else if let remoteURL = video.thumbnailRemoteURL {
                AsyncImage(url: remoteURL) { image in
                    image.resizable().aspectRatio(contentMode: contentMode)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
