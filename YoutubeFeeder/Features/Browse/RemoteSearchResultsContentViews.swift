import SwiftUI

struct RemoteKeywordSearchResultsCompactView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    @Binding var path: NavigationPath
    let keyword: String
    let result: VideoSearchResult
    let visibleCount: Int
    let allowsRefreshCommandBinding: Bool
    let onRefresh: () async -> Void
    let onDismissChip: () -> Void
    let onLoadMore: () -> Void
    let normalizedChannelTitle: (CachedVideo) -> String?

    var body: some View {
        InteractiveListView(
            title: "YouTube検索",
            subtitle: "下に引っ張ると「\(keyword)」を YouTube で検索し、履歴を順次マージして表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                await onRefresh()
            },
            allowsRefreshCommandBinding: allowsRefreshCommandBinding
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
                                            prefersAutomaticRefresh: true,
                                            routeSource: .remoteSearch
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
                        .listInsertionTransition()
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
    @Binding var splitVisibleCount: Int
    let isSplitLoading: Bool
    let presentationMode: RemoteSearchPresentationMode
    let onRenderProbe: (String) -> Void
    let onLoadMoreSplitVideos: () -> Void
    let onSelectSplitChannel: (ChannelVideosRouteContext) -> Void
    let onRefresh: () async -> Void
    let onDismissChip: () -> Void
    let onLoadMore: () -> Void
    let normalizedChannelTitle: (CachedVideo) -> String?
    @State private var hasLoggedListRender = false

    var body: some View {
        NavigationSplitView {
            InteractiveListView(
                title: "YouTube検索",
                subtitle: "下に引っ張ると「\(keyword)」を YouTube で検索し、履歴を順次マージして表示",
                coordinator: coordinator,
                path: $path,
                layout: layout,
                onRefresh: {
                    await onRefresh()
                },
                allowsRefreshCommandBinding: presentationMode == .visible
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
                                    onSelectSplitChannel(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(video),
                                            selectedVideoID: video.id,
                                            prefersAutomaticRefresh: true,
                                            routeSource: .remoteSearch
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
                        .listInsertionTransition()
                    }
                }
            }
            }
            .background(
                RenderProbe {
                    guard !hasLoggedListRender else { return }
                    hasLoggedListRender = true
                    onRenderProbe("regular_list")
                }
                .frame(width: 0, height: 0)
            )
        } detail: {
            RemoteKeywordSearchResultsSplitDetailView(
                coordinator: coordinator,
                openVideo: openVideo,
                layout: layout,
                splitContext: $splitContext,
                splitVideos: $splitVideos,
                splitVisibleCount: $splitVisibleCount,
                isSplitLoading: isSplitLoading,
                presentationMode: presentationMode,
                onRenderProbe: onRenderProbe,
                onLoadMore: onLoadMoreSplitVideos,
                onAppearOnce: nil
            )
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
    }
}

struct RemoteKeywordSearchResultsSplitDetailView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    let layout: AppLayout
    @Binding var splitContext: ChannelVideosRouteContext?
    @Binding var splitVideos: [CachedVideo]
    @Binding var splitVisibleCount: Int
    let isSplitLoading: Bool
    let presentationMode: RemoteSearchPresentationMode
    let onRenderProbe: (String) -> Void
    let onLoadMore: () -> Void
    let onAppearOnce: ((String?) -> Void)?
    @State private var hasLoggedDetailRender = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(splitTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .accessibilityIdentifier("screen.remoteSearchSplitTitle")

                Text("このチャンネルの動画を新しい順に表示")
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
                    let visibleVideos = Array(splitVideos.prefix(splitVisibleCount))
                    LazyVGrid(columns: layout.listColumns, spacing: 20) {
                        ForEach(Array(visibleVideos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                                tapAction: nil,
                                openVideoAction: {
                                    openVideo(video)
                                },
                                removeChannel: nil,
                            index: offset + 1
                        )
                        .onAppear {
                            guard offset >= visibleVideos.count - 1 else { return }
                            onLoadMore()
                        }
                        .listInsertionTransition()
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
        .background(
            RenderProbe {
                guard !hasLoggedDetailRender else { return }
                hasLoggedDetailRender = true
                onRenderProbe("split_detail")
            }
            .frame(width: 0, height: 0)
        )
        .onAppear {
            onAppearOnce?(splitContext?.channelID)
        }
        .refreshable {
            guard let splitContext else { return }
            if case let .channelVideos(reloadedVideos) = await coordinator.performRefreshAction(.channel(splitContext)) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        splitVideos = reloadedVideos
                        splitVisibleCount = min(20, splitVideos.count)
                    }
                }
            }
        }
    }

    private var splitTitle: String {
        splitContext?.preferredChannelTitle ?? splitVideos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle ?? splitContext?.channelID ?? "チャンネル未選択"
    }
}
