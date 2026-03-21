import SwiftUI

struct InteractiveListScreen<Content: View>: View {
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

    var body: some View {
        let menuActions = buildMenuActions()
        let tile = VideoHeroTile(video: video, index: index)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .tileActionMenu(actions: menuActions)
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

struct ChannelTile: View {
    let item: ChannelBrowseItem
    let index: Int?

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let latestVideo = item.latestVideo {
                    ThumbnailView(video: latestVideo, contentMode: .fill)
                }
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.channelTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("\(item.cachedVideoCount)件")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(formattedDate(item.latestPublishedAt))
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

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: date)
    }
}

struct ChannelSelectionTile: View {
    let item: ChannelBrowseItem
    let isSelected: Bool
    let index: Int?

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected ? [.cyan, .blue] : [.teal.opacity(0.8), .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let latestVideo = item.latestVideo {
                    ThumbnailView(video: latestVideo, contentMode: .fill)
                        .opacity(isSelected ? 0.92 : 0.78)
                }
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? .white.opacity(0.95) : .clear, lineWidth: 3)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.channelTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("\(item.cachedVideoCount)件")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(formattedDate(item.latestPublishedAt))
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
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: date)
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

                    Text(video.channelTitle.isEmpty ? video.channelID : video.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Text(formattedDate(video.publishedAt))
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

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: date)
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
        Text(AppFormatting.videoTileBadgeText(durationSeconds: video.durationSeconds, viewCount: video.viewCount))
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.72), in: Capsule())
    }
}

struct ThumbnailView: View {
    let video: CachedVideo
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let filename = video.thumbnailLocalFilename {
                AsyncImage(url: FeedCachePaths.thumbnailURL(filename: filename)) { image in
                    image.resizable().aspectRatio(contentMode: contentMode)
                } placeholder: {
                    placeholder
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
