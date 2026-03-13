import SwiftUI

struct ChannelBrowseListView: View {
    let coordinator: FeedCacheCoordinator
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var items: [ChannelBrowseItem] = []

    var body: some View {
        InteractiveListScreen(
            title: "チャンネル一覧",
            subtitle: "最新投稿日が新しい順",
            coordinator: coordinator,
            path: $path,
            layout: layout
        ) {
            if items.isEmpty {
                MetricTile(title: "チャンネル一覧", value: "まだありません", detail: "キャッシュが増えるとここに並びます")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(items) { item in
                        NavigationLink(value: MaintenanceRoute.channelVideos(item.channelID)) {
                            ChannelHeroTile(item: item, height: layout.tileHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("channel.tile.\(item.channelID)")
                    }
                }
            }
        }
        .task {
            items = await coordinator.loadChannelBrowseItems()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("channelListShown")
        }
    }
}

struct AllVideosView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    var body: some View {
        InteractiveListScreen(
            title: "動画一覧",
            subtitle: "キャッシュ済み動画を新しい順に最大50件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout
        ) {
            if coordinator.videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "収集が進むとここに長尺動画を最大50件まで表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(coordinator.videos) { video in
                        LongPressVideoTile(video: video, openVideo: openVideo, height: layout.tileHeight)
                    }
                }
            }
        }
        .task {
            coordinator.loadVideosFromCache()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("allVideosShown")
        }
    }
}

struct ChannelVideosView: View {
    let channelID: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var videos: [CachedVideo] = []

    var body: some View {
        InteractiveListScreen(
            title: channelTitle,
            subtitle: "このチャンネルの動画を新しい順に最大50件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout
        ) {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "screen.channelVideos.loaded",
                    value: videos.first?.id ?? "none"
                )
            }

            if videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(videos) { video in
                        LongPressVideoTile(video: video, openVideo: openVideo, height: layout.tileHeight)
                    }
                }
            }
        }
        .task {
            videos = await coordinator.loadVideosForChannel(channelID)
        }
        .onAppear {
            StartupDiagnostics.shared.mark("channelVideosShown")
        }
    }

    private var channelTitle: String {
        coordinator.maintenanceItems.first(where: { $0.channelID == channelID })?.channelTitle ?? channelID
    }
}

struct InteractiveListScreen<Content: View>: View {
    let title: String
    let subtitle: String
    let coordinator: FeedCacheCoordinator
    @Binding var path: NavigationPath
    let layout: AppLayout
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
            .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
        .onAppear {
            coordinator.suspendLiveUpdates()
        }
        .onDisappear {
            coordinator.resumeLiveUpdates()
        }
    }
}

struct LongPressVideoTile: View {
    let video: CachedVideo
    let openVideo: (CachedVideo) -> Void
    let height: CGFloat

    @State private var isPressing = false

    var body: some View {
        VideoHeroTile(video: video, height: height)
            .scaleEffect(isPressing ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressing)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onLongPressGesture(
                minimumDuration: VideoOpenPolicy.minimumPressDuration,
                maximumDistance: VideoOpenPolicy.maximumMovement
            ) {
                openVideo(video)
            } onPressingChanged: { pressing in
                isPressing = pressing
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("1秒長押しでYouTubeを開きます")
            .accessibilityIdentifier("video.tile.\(video.id)")
    }
}

struct ChannelHeroTile: View {
    let item: ChannelBrowseItem
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: height)

            if let latestVideo = item.latestVideo {
                ThumbnailView(video: latestVideo, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: date)
    }
}

struct VideoHeroTile: View {
    let video: CachedVideo
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: height)

            ThumbnailView(video: video, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: date)
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
            Color.clear
                .frame(width: 140)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            if BackSwipePolicy.shouldNavigateBack(startX: value.startLocation.x, translation: value.translation), !path.isEmpty {
                                path.removeLast()
                            }
                        }
                )
        }
    }
}
