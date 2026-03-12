//
//  ContentView.swift
//  HelloWorld
//
//  Created by 高下彰実 on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var coordinator: FeedCacheCoordinator

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
        TabView {
            maintenancePage
                .tag(0)

            videosPage
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color(.systemGroupedBackground))
        .task(priority: .userInitiated) {
            coordinator.refreshFromCache()
        }
        .task(priority: .background) {
            try? await Task.sleep(for: .milliseconds(300))
            coordinator.start()
        }
    }

    private var maintenancePage: some View {
        let progress = coordinator.progress

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("メンテナンス")
                        .font(.largeTitle.bold())

                    Text("左右スワイプで動画一覧に切り替え")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

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

                    MetricTile(
                        title: "チャンネル",
                        value: "\(progress.cachedChannels) / \(progress.totalChannels)",
                        detail: progress.isRunning ? "日次初回は10秒間隔、その後は1時間ごとに確認" : "停止中"
                    )

                    MetricTile(
                        title: "動画",
                        value: "\(progress.cachedVideos)",
                        detail: "一覧表示・検索・並び替え向けキャッシュ"
                    )

                    MetricTile(
                        title: "サムネイル",
                        value: "\(progress.cachedThumbnails)",
                        detail: "ローカル保存済み件数"
                    )

                    MetricTile(
                        title: "現在処理中",
                        value: currentChannelLabel(progress),
                        detail: progress.currentChannelID ?? "待機中"
                    )

                    if let lastUpdatedAt = progress.lastUpdatedAt {
                        MetricTile(
                            title: "最終更新",
                            value: Self.dateFormatter.string(from: lastUpdatedAt),
                            detail: "最後にキャッシュ全体を書き込んだ時刻"
                        )
                    }

                    if let lastError = progress.lastError {
                        MetricTile(
                            title: "最新エラー",
                            value: lastError,
                            detail: "次のチャンネル取得は継続します"
                        )
                    }

                    Text("チャンネル状態")
                        .font(.title3.bold())
                        .padding(.top, 8)

                    LazyVStack(spacing: 12) {
                        ForEach(coordinator.maintenanceItems) { item in
                            ChannelStatusCard(item: item)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var videosPage: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("動画一覧")
                        .font(.largeTitle.bold())

                    Text("キャッシュ済み動画を新しい順に最大50件表示")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if coordinator.videos.isEmpty {
                        MetricTile(
                            title: "動画一覧",
                            value: "まだありません",
                            detail: "収集が進むとここに長尺動画を最大50件まで表示します"
                        )
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(coordinator.videos) { video in
                                Button {
                                    openVideo(video)
                                } label: {
                                    VideoHeroTile(video: video)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
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

private struct VideoHeroTile: View {
    let video: CachedVideo

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)

            ThumbnailView(video: video, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
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
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.18))

            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
