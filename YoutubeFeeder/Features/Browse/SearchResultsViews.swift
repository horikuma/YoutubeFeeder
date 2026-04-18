import SwiftUI

struct KeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var searchState = KeywordSearchLogic()
    @State private var isChipVisible = true

    var body: some View {
        InteractiveListView(
            title: "検索結果",
            subtitle: "「\(keyword)」に一致する動画を新しい順に20件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                await reloadResults()
            },
            allowsRefreshCommandBinding: true
        ) {
            if searchState.result.videos.isEmpty {
                MetricTile(title: "検索結果", value: "0件", detail: "一致する動画がキャッシュにありません")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(searchState.result.videos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: {
                                dismissChip()
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(for: video),
                                            selectedVideoID: video.id,
                                            routeSource: .localSearch
                                        )
                                    )
                                )
                            },
                            openVideoAction: nil,
                            removeChannel: nil,
                            index: offset + 1,
                            desktopPrimaryClickAction: {
                                openVideo(video)
                            },
                            desktopMenuTriggerStyle: .contextMenu
                        )
                        .listInsertionTransition()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isChipVisible {
                SearchResultCountChip(totalCount: searchState.result.totalCount, sourceLabel: searchState.result.source.label, fetchedAt: searchState.result.fetchedAt)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if shouldDismissChip(for: value) {
                        dismissChip()
                    }
                }
        )
        .task {
            await reloadResults()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("keywordSearchShown")
        }
    }

    private func reloadResults() async {
        let result = await coordinator.searchVideos(keyword: keyword, limit: 20)
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                searchState.setResult(result)
            }
        }
    }

    private func dismissChip() {
        guard isChipVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isChipVisible = false
        }
    }

    private func shouldDismissChip(for value: DragGesture.Value) -> Bool {
        value.translation.height < -8 || abs(value.translation.width) > 20
    }

    private func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }
}

struct SearchResultCountChip: View {
    let totalCount: Int
    let sourceLabel: String
    let fetchedAt: Date?
    let isRefreshing: Bool

    init(totalCount: Int, sourceLabel: String, fetchedAt: Date?, isRefreshing: Bool = false) {
        self.totalCount = totalCount
        self.sourceLabel = sourceLabel
        self.fetchedAt = fetchedAt
        self.isRefreshing = isRefreshing
    }

    var body: some View {
        HStack(spacing: 8) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("再検索中")
            } else {
                if let fetchedAt {
                    Text("最終更新 \(Self.timestampFormatter.string(from: fetchedAt))")
                }
                Text("\(totalCount) 件")
                Text(sourceLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityIdentifier("search.resultChip")
        .accessibilityLabel(isRefreshing ? "再検索中" : accessibilitySummary)
        .overlay {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "search.resultChip.state",
                    value: isRefreshing ? "refreshing" : "summary"
                )
            }
        }
    }

    private var accessibilitySummary: String {
        let updatedText = fetchedAt.map { "最終更新 \(Self.timestampFormatter.string(from: $0))" } ?? "更新時刻なし"
        return "\(updatedText) \(totalCount) 件 \(sourceLabel)"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}

struct SearchRefreshStatusView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("YouTube を再検索中")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("search.refreshIndicator")
    }
}
