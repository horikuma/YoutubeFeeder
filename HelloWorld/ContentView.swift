//
//  ContentView.swift
//  HelloWorld
//
//  Created by 高下彰実 on 2026/03/11.
//

import SwiftUI

private enum MaintenanceRoute: Hashable {
    case channelList
    case allVideos
    case channelVideos(String)
}

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var coordinator: FeedCacheCoordinator
    @State private var hasEnteredMaintenance = false
    @State private var hasPreparedMaintenance = false
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var diagnostics = StartupDiagnostics.shared

    init() {
        _coordinator = StateObject(wrappedValue: FeedCacheCoordinator(channels: ChannelResource.loadChannelIDs()))
    }

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        let layout = AppLayout.current(horizontalSizeClass: horizontalSizeClass, idiom: UIDevice.current.userInterfaceIdiom)

        Group {
            if hasEnteredMaintenance {
                NavigationStack(path: $navigationPath) {
                    maintenancePage(layout: layout)
                        .navigationDestination(for: MaintenanceRoute.self) { route in
                            switch route {
                            case .channelList:
                                ChannelBrowseListView(coordinator: coordinator, path: $navigationPath, layout: layout)
                            case .allVideos:
                                AllVideosView(coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            case let .channelVideos(channelID):
                                ChannelVideosView(channelID: channelID, coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            }
                        }
                }
            } else {
                LaunchScreenView()
            }
        }
        .background(Color(.systemGroupedBackground))
        .attachDiagnosticsProbe()
        .task(priority: .userInitiated) {
            guard !hasPreparedMaintenance else { return }
            hasPreparedMaintenance = true
            await coordinator.bootstrapMaintenance()
            diagnostics.mark("bootstrapLoaded")
            withAnimation(.easeInOut(duration: 0.2)) {
                hasEnteredMaintenance = true
            }
        }
        .task(id: hasEnteredMaintenance) {
            guard hasEnteredMaintenance else { return }
            diagnostics.mark("maintenanceEntered")
            guard AppLaunchMode.current.allowsBackgroundRefresh else { return }
            coordinator.start()
        }
    }

    private func maintenancePage(layout: AppLayout) -> some View {
        let progress = coordinator.progress

        return ScrollView {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                Text("メンテナンス")
                    .font(layout.isPad ? .system(size: 38, weight: .black, design: .rounded) : .largeTitle.bold())
                    .accessibilityIdentifier("screen.maintenance")

                if layout.isPad {
                    HStack(alignment: .top, spacing: 18) {
                        progressSection(progress: progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statusSection(progress: progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    progressSection(progress: progress)
                    statusSection(progress: progress)
                }
            }
            .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            diagnostics.mark("maintenanceShown")
        }
    }

    private func progressSection(progress: CacheProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(
                value: Double(progress.cachedChannels),
                total: Double(max(progress.totalChannels, 1))
            ) {
                Text("キャッシュ進捗")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(progress.cachedChannels) / \(progress.totalChannels)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: layoutColumns,
                spacing: 16
            ) {
                NavigationLink(value: MaintenanceRoute.channelList) {
                    MetricTile(
                        title: "チャンネル",
                        value: "\(progress.cachedChannels) / \(progress.totalChannels)",
                        detail: progress.isRunning ? "タップでチャンネル一覧" : "停止中"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nav.channels")

                NavigationLink(value: MaintenanceRoute.allVideos) {
                    MetricTile(
                        title: "動画",
                        value: "\(progress.cachedVideos)",
                        detail: "タップで動画一覧"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nav.videos")
            }
        }
    }

    private var layoutColumns: [GridItem] {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top),
            ]
        }

        return [GridItem(.flexible(), spacing: 16, alignment: .top)]
    }

    @ViewBuilder
    private func statusSection(progress: CacheProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ChannelStateLiveCard(
                title: "現在処理中",
                value: currentChannelLabel(progress),
                detail: progress.currentChannelID ?? "待機中"
            )

            ChannelStateLiveCard(
                title: "最終更新",
                value: progress.lastUpdatedAt.map(Self.dateFormatter.string(from:)) ?? "未更新",
                detail: "最新キャッシュ状態"
            )

            if let lastError = progress.lastError {
                ChannelStateLiveCard(
                    title: "最新エラー",
                    value: lastError,
                    detail: "次のチャンネル取得は継続します"
                )
            }
        }
    }

    private func currentChannelLabel(_ progress: CacheProgress) -> String {
        guard let number = progress.currentChannelNumber else {
            return "待機中"
        }

        return "\(number)番目"
    }

    private func openVideo(_ video: CachedVideo) {
        guard let webURL = video.videoURL else { return }

        let appURL = URL(string: "youtube://watch?v=\(video.id)")!
        openURL(appURL) { accepted in
            if !accepted {
                openURL(webURL)
            }
        }
    }
}

private struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("HelloWorld")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Launching...")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(32)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(minHeight: 120)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)

                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChannelStateLiveCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ChannelStatusCard: View {
    let item: ChannelMaintenanceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.channelTitle ?? item.channelID)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(item.channelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Text(item.freshness.label)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor(item.freshness), in: Capsule())
            }

            LabeledContent("前回更新", value: formattedDate(item.lastSuccessAt))
            LabeledContent("最終確認", value: formattedDate(item.lastCheckedAt))
            LabeledContent("最新投稿日", value: formattedDate(item.latestPublishedAt))
            LabeledContent("キャッシュ動画数", value: "\(item.cachedVideoCount)")

            if let lastError = item.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "未取得"
        }
        return ContentView.dateFormatter.string(from: date)
    }

    private func statusColor(_ freshness: ChannelFreshness) -> Color {
        switch freshness {
        case .fresh:
            return .green
        case .stale:
            return .orange
        case .neverFetched:
            return .gray
        }
    }
}

private struct ChannelBrowseListView: View {
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

private struct AllVideosView: View {
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

private struct ChannelVideosView: View {
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

private struct InteractiveListScreen<Content: View>: View {
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

private struct LongPressVideoTile: View {
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
    }
}

private struct ChannelHeroTile: View {
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

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
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
        .accessibilityIdentifier("channel.tile.\(item.channelID)")
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "投稿日なし" }
        return ContentView.dateFormatter.string(from: date)
    }
}

private struct VideoHeroTile: View {
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

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
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
        .accessibilityIdentifier("video.tile.\(video.id)")
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "投稿日なし"
        }
        return ContentView.dateFormatter.string(from: date)
    }
}

private struct ThumbnailView: View {
    let video: CachedVideo
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let filename = video.thumbnailLocalFilename {
                AsyncImage(url: FeedCachePaths.thumbnailURL(filename: filename)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } placeholder: {
                    placeholder
                }
            } else if let remoteURL = video.thumbnailRemoteURL {
                AsyncImage(url: remoteURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
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

private struct BackSwipePopModifier: ViewModifier {
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 140)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            if BackSwipePolicy.shouldNavigateBack(
                                startX: value.startLocation.x,
                                translation: value.translation
                            ), !path.isEmpty {
                                path.removeLast()
                            }
                        }
                )
        }
    }
}
