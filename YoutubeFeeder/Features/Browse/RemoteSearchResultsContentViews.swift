import SwiftUI

struct RemoteKeywordSearchResultsCompactView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    @Binding var path: NavigationPath
    let keyword: String
    let result: VideoSearchResult
    let visibleCount: Int
    let onRefresh: () async -> Void
    let onDismissChip: () -> Void
    let onLoadMore: () -> Void
    let normalizedChannelTitle: (CachedVideo) -> String?

    var body: some View {
        InteractiveListScreen(
            title: "YouTube検索",
            subtitle: "下に引っ張ると「\(keyword)」を YouTube で検索し、履歴を順次マージして表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                await onRefresh()
            }
        ) {
            if result.fetchedAt == nil, result.videos.isEmpty, result.errorMessage == nil {
                MetricTile(
                    title: "YouTube検索",
                    value: "未取得",
                    detail: "この画面で下に引っ張ると検索します。結果はキャッシュされ、次回はその内容を表示します"
                )
            } else if let errorMessage = result.errorMessage, result.videos.isEmpty {
                MetricTile(title: "YouTube検索", value: "取得できません", detail: errorMessage)
            } else if result.videos.isEmpty {
                MetricTile(title: "YouTube検索", value: "0件", detail: "一致する動画が見つかりませんでした")
            } else {
                let visibleVideos = Array(result.videos.prefix(visibleCount))
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(visibleVideos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: {
                                onDismissChip()
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(video),
                                            selectedVideoID: video.id,
                                            prefersAutomaticRefresh: true
                                        )
                                    )
                                )
                            },
                            openVideoAction: nil,
                            removeChannel: nil,
                            index: offset + 1
                        )
                        .onAppear {
                            guard offset >= visibleVideos.count - 1 else { return }
                            onLoadMore()
                        }
                    }
                }
            }
        }
    }
}

struct RemoteKeywordSearchResultsRegularView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let result: VideoSearchResult
    let visibleCount: Int
    @Binding var splitContext: ChannelVideosRouteContext?
    @Binding var splitVideos: [CachedVideo]
    let isSplitLoading: Bool
    let onRefresh: () async -> Void
    let onDismissChip: () -> Void
    let onLoadMore: () -> Void
    let normalizedChannelTitle: (CachedVideo) -> String?

    var body: some View {
        NavigationSplitView {
            InteractiveListScreen(
                title: "YouTube検索",
                subtitle: "下に引っ張ると「\(keyword)」を YouTube で検索し、履歴を順次マージして表示",
                coordinator: coordinator,
                path: $path,
                layout: layout,
                onRefresh: {
                    await onRefresh()
                }
            ) {
                if result.fetchedAt == nil, result.videos.isEmpty, result.errorMessage == nil {
                    MetricTile(
                        title: "YouTube検索",
                        value: "未取得",
                        detail: "この画面で下に引っ張ると検索します。結果はキャッシュされ、次回はその内容を表示します"
                    )
                } else if let errorMessage = result.errorMessage, result.videos.isEmpty {
                    MetricTile(title: "YouTube検索", value: "取得できません", detail: errorMessage)
                } else if result.videos.isEmpty {
                    MetricTile(title: "YouTube検索", value: "0件", detail: "一致する動画が見つかりませんでした")
                } else {
                    let visibleVideos = Array(result.videos.prefix(visibleCount))
                    LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                        ForEach(Array(visibleVideos.enumerated()), id: \.element.id) { offset, video in
                            VideoTile(
                                video: video,
                                tapAction: {
                                    onDismissChip()
                                    Task {
                                        let context = ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(video),
                                            selectedVideoID: video.id,
                                            prefersAutomaticRefresh: true
                                        )
                                        await MainActor.run {
                                            splitContext = context
                                        }
                                        let loadedVideos = await coordinator.openChannelVideos(context)
                                        await MainActor.run {
                                            splitVideos = loadedVideos
                                        }
                                    }
                                },
                                openVideoAction: nil,
                                removeChannel: nil,
                                index: offset + 1
                            )
                            .onAppear {
                                guard offset >= visibleVideos.count - 1 else { return }
                                onLoadMore()
                            }
                        }
                    }
                }
            }
        } detail: {
            RemoteKeywordSearchResultsSplitDetailPane(
                coordinator: coordinator,
                openVideo: openVideo,
                layout: layout,
                splitContext: $splitContext,
                splitVideos: $splitVideos,
                isSplitLoading: isSplitLoading,
                onAppearOnce: nil
            )
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
    }
}

struct RemoteKeywordSearchResultsSplitDetailPane: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    let layout: AppLayout
    @Binding var splitContext: ChannelVideosRouteContext?
    @Binding var splitVideos: [CachedVideo]
    let isSplitLoading: Bool
    let onAppearOnce: ((String?) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(splitTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .accessibilityIdentifier("screen.remoteSearchSplitTitle")

                Text("このチャンネルの動画を新しい順に最大50件表示")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if AppLaunchMode.current.usesMockData {
                    UITestMarker(
                        identifier: "test.remoteSearch.splitChannelID",
                        value: splitContext?.channelID ?? "none"
                    )
                    UITestMarker(
                        identifier: "screen.channelVideos.loaded",
                        value: splitVideos.first?.id ?? "none"
                    )
                }

                if splitContext == nil {
                    MetricTile(title: "チャンネル動画", value: "未選択", detail: "左側の動画をタップするとこのチャンネルの動画一覧を表示します")
                } else if isSplitLoading {
                    MetricTile(title: "動画一覧", value: "読み込み中", detail: "右側のチャンネル動画を準備しています")
                } else if splitVideos.isEmpty {
                    MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
                } else {
                    LazyVGrid(columns: layout.listColumns, spacing: 20) {
                        ForEach(Array(splitVideos.enumerated()), id: \.element.id) { offset, video in
                            VideoTile(
                                video: video,
                                tapAction: nil,
                                openVideoAction: {
                                    openVideo(video)
                                },
                                removeChannel: nil,
                                index: offset + 1
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: layout.readableContentWidth ?? layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            onAppearOnce?(splitContext?.channelID)
        }
        .refreshable {
            guard let splitContext else { return }
            await coordinator.refreshChannelManually(splitContext.channelID)
            splitVideos = await coordinator.openChannelVideos(splitContext)
        }
    }

    private var splitTitle: String {
        splitContext?.preferredChannelTitle ?? splitVideos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle ?? splitContext?.channelID ?? "チャンネル未選択"
    }
}
