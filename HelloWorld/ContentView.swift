//
//  ContentView.swift
//  HelloWorld
//
//  Created by 高下彰実 on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @State private var videos: [YouTubeVideo] = []
    @State private var selectedChannelID: String?
    @State private var errorMessage: String?

    private let channels = ChannelResource.loadChannelIDs()
    private let service = YouTubeFeedService()

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header

                if let errorMessage {
                    errorCard(message: errorMessage)
                } else if videos.isEmpty {
                    loadingCard
                } else {
                    ForEach(videos) { video in
                        VideoTile(video: video)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadFeed()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YouTube Feed")
                .font(.title.bold())

            if let selectedChannelID {
                Text("channel: \(selectedChannelID)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.orange.gradient)
            .frame(height: 120)
            .overlay {
                ProgressView("読み込み中...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
    }

    private func errorCard(message: String) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.red.gradient)
            .frame(height: 140)
            .overlay(alignment: .leading) {
                Text(message)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(20)
            }
    }

    @MainActor
    private func loadFeed() async {
        guard let firstChannel = channels.first else {
            errorMessage = "チャンネル一覧が空です。"
            return
        }

        selectedChannelID = firstChannel

        do {
            videos = try await service.fetchVideos(for: firstChannel)
            errorMessage = videos.isEmpty ? "動画を取得できませんでした。" : nil
        } catch {
            errorMessage = "フィード取得に失敗しました。"
        }
    }
}

private struct VideoTile: View {
    let video: YouTubeVideo

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)

            AsyncImage(url: video.thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.black.opacity(0.15)
            }
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

                Text(video.channelTitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                if let publishedAt = video.publishedAt {
                    Text(ContentView.dateFormatter.string(from: publishedAt))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    ContentView()
}
