import SwiftUI

enum RemoteSearchPresentationMode: String {
    case visible
    case prewarm
}

struct RemoteKeywordSearchResultsView: View {
    let keyword: String
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let browsePresentation: BasicGUIBrowsePresentation
    let presentationMode: RemoteSearchPresentationMode

    @StateObject private var viewModel: RemoteSearchResultsViewModel
    @State private var hasLoggedRootRender = false

    init(
        keyword: String,
        coordinator: FeedCacheCoordinator,
        openVideo: @escaping (CachedVideo) -> Void,
        path: Binding<NavigationPath>,
        layout: AppLayout,
        browsePresentation: BasicGUIBrowsePresentation,
        presentationMode: RemoteSearchPresentationMode = .visible
    ) {
        self.keyword = keyword
        self.openVideo = openVideo
        _path = path
        self.layout = layout
        self.browsePresentation = browsePresentation
        self.presentationMode = presentationMode
        _viewModel = StateObject(
            wrappedValue: RemoteSearchResultsViewModel(
                keyword: keyword,
                coordinator: coordinator,
                browsePresentation: browsePresentation,
                presentationMode: presentationMode
            )
        )
    }

    var body: some View {
        content
            .animation(.easeOut(duration: 0.25), value: viewModel.result)
            .animation(.easeOut(duration: 0.25), value: viewModel.presentationState)
            .animation(.easeOut(duration: 0.25), value: viewModel.splitContext?.channelID ?? "")
            .animation(.easeOut(duration: 0.25), value: viewModel.splitVisibleCount)
            .background(
                RenderProbe {
                    guard !hasLoggedRootRender else { return }
                    hasLoggedRootRender = true
                    recordRenderProbe("root")
                }
                .frame(width: 0, height: 0)
            )
            .overlay(alignment: .top) {
                if viewModel.presentationState.isRefreshingChip {
                    SearchRefreshStatusView()
                        .padding(.horizontal, layout.horizontalPadding)
                        .padding(.top, 12)
                }
            }
            .overlay(alignment: .topTrailing) {
                remoteSearchTestControls
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.result.totalCount > 0 {
                        Button("クリア") {
                            Task {
                                await viewModel.clearRemoteSearchHistory()
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.presentationState.chipMode == .summary {
                    SearchResultCountChip(
                        totalCount: viewModel.result.totalCount,
                        sourceLabel: viewModel.result.source.label,
                        fetchedAt: viewModel.result.fetchedAt,
                        isRefreshing: viewModel.presentationState.isRefreshingChip
                    )
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if viewModel.shouldDismissChip(for: value) {
                            viewModel.dismissChip()
                        }
                    }
            )
            .task {
                await viewModel.loadSnapshot()
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
    }

    private var remoteSearchTestControls: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "test.remoteSearch.firstVideoID",
                    value: viewModel.result.videos.first?.id ?? "none"
                )
                UITestMarker(
                    identifier: "search.refreshPhase",
                    value: viewModel.presentationState.chipMode.rawValue
                )
                UITestAsyncActionTrigger(identifier: "test.remoteSearch.refresh") {
                    await viewModel.reloadResults(forceRefresh: true)
                }
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    private func recordRenderProbe(_ phase: String) {
        let metadata = [
            "phase": phase,
            "layout": browsePresentation.rawValue,
            "mode": presentationMode.rawValue,
            "videos": String(viewModel.result.videos.count),
        ]
        AppConsoleLogger.youtubeSearch.info("screen_render_probe", metadata: metadata)
        RuntimeDiagnostics.shared.record(
            "remote_search_render_probe",
            detail: "YouTube検索画面の描画到達点",
            metadata: metadata
        )
    }

    @ViewBuilder
    private var content: some View {
        if browsePresentation.usesSplitLayout {
            RemoteKeywordSearchResultsRegularView(
                keyword: keyword,
                coordinator: viewModel.coordinator,
                openVideo: openVideo,
                path: $path,
                layout: layout,
                result: viewModel.result,
                visibleCount: viewModel.presentationState.visibleCount,
                splitContext: $viewModel.splitContext,
                splitVideos: $viewModel.splitVideos,
                splitVisibleCount: $viewModel.splitVisibleCount,
                isSplitLoading: viewModel.isSplitLoading,
                presentationMode: presentationMode,
                onRenderProbe: recordRenderProbe,
                onLoadMoreSplitVideos: { viewModel.loadSplitMoreIfNeeded() },
                onSelectSplitChannel: { viewModel.selectSplitChannel($0) },
                onRefresh: { await viewModel.reloadResults(forceRefresh: true) },
                onRefreshSplit: { await viewModel.refreshSplitSelection() },
                onDismissChip: { viewModel.dismissChip() },
                onLoadMore: { viewModel.loadMoreIfNeeded() },
                normalizedChannelTitle: viewModel.normalizedChannelTitle(for:)
            )
        } else {
            RemoteKeywordSearchResultsCompactView(
                coordinator: viewModel.coordinator,
                layout: layout,
                openVideo: openVideo,
                path: $path,
                keyword: keyword,
                result: viewModel.result,
                visibleCount: viewModel.presentationState.visibleCount,
                allowsRefreshCommandBinding: presentationMode == .visible,
                onRefresh: { await viewModel.reloadResults(forceRefresh: true) },
                onDismissChip: { viewModel.dismissChip() },
                onLoadMore: { viewModel.loadMoreIfNeeded() },
                normalizedChannelTitle: viewModel.normalizedChannelTitle(for:)
            )
        }
    }
}
