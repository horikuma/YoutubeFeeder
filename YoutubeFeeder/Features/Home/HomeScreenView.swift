import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>
    @State private var didRunAutoRefresh = false
    @State private var homeState = HomeScreenLogic()
    @State private var didPrewarmRemoteSearch = false
    @State private var shouldMountRemoteSearchPrewarmHost = false
    @State private var remoteSearchPrewarmPath = NavigationPath()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                    if AppLaunchMode.current.usesMockData {
                        UITestMarker(
                            identifier: "test.manualRefreshCount",
                            value: "\(coordinator.manualRefreshCount)"
                        )
                    }

                    Text("ホーム")
                        .font(layout.isPad ? .system(size: 38, weight: .black, design: .rounded) : .largeTitle.bold())
                        .accessibilityIdentifier("screen.home")

                    navigationSection
                    SystemStatusTile(status: coordinator.homeSystemStatus)

                    if let transferFeedback = homeState.transferFeedback {
                        registryTransferFeedbackCard(transferFeedback)
                            .accessibilityIdentifier("home.transferFeedback")
                    } else if let resetFeedback = homeState.resetFeedback {
                        resetFeedbackCard(resetFeedback)
                            .accessibilityIdentifier("home.resetFeedback")
                    } else if let transferErrorMessage = homeState.transferErrorMessage {
                        registryTransferErrorCard(transferErrorMessage)
                            .accessibilityIdentifier("home.transferError")
                    }
                }
                .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.vertical, 20)
            }

            if shouldMountRemoteSearchPrewarmHost {
                BasicGUIRemoteSearchScreen(
                    keyword: FeedCacheCoordinator.homeSearchKeyword,
                    coordinator: coordinator,
                    openVideo: { _ in },
                    path: $remoteSearchPrewarmPath,
                    layout: layout,
                    presentationMode: .prewarm
                )
                .opacity(0.001)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            _ = await coordinator.performRefreshAction(.home)
        }
        .bindRefreshCommand {
            _ = await coordinator.performRefreshAction(.home)
        }
        .onAppear {
            diagnostics.mark("maintenanceShown")
            AppConsoleLogger.appLifecycle.info(
                "home_shown",
                metadata: [
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact",
                    "registered_channels": String(coordinator.homeSystemStatus.registeredChannelCount),
                    "cached_videos": String(coordinator.homeSystemStatus.cachedVideoCount),
                ]
            )
        }
        .task {
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_task_started",
                metadata: [
                    "auto_refresh_on_launch": AppLaunchMode.current.autoRefreshOnLaunch ? "true" : "false",
                    "background_refresh": AppLaunchMode.current.allowsBackgroundRefresh ? "true" : "false",
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            guard AppLaunchMode.current.autoRefreshOnLaunch else {
                AppConsoleLogger.appLifecycle.info(
                    "home_auto_refresh_task_skipped",
                    metadata: [
                        "reason": "disabled_on_launch",
                        "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                    ]
                )
                return
            }
            guard !didRunAutoRefresh else {
                AppConsoleLogger.appLifecycle.info(
                    "home_auto_refresh_task_skipped",
                    metadata: [
                        "reason": "already_ran",
                        "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                    ]
                )
                return
            }
            didRunAutoRefresh = true
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_manual_refresh_started",
                metadata: [
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            await coordinator.refreshCacheManually()
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_manual_refresh_finished",
                metadata: [
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            guard AppLaunchMode.current.allowsBackgroundRefresh else {
                AppConsoleLogger.appLifecycle.info(
                    "home_auto_refresh_background_loop_skipped",
                    metadata: [
                        "reason": "background_refresh_disabled",
                        "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                    ]
                )
                return
            }
            AppConsoleLogger.appLifecycle.info(
                "home_auto_refresh_background_loop_requested",
                metadata: [
                    "layout": layout.usesSplitChannelBrowser ? "split" : "compact"
                ]
            )
            coordinator.startAutomaticRefreshLoopIfNeeded()
        }
        .task(priority: .utility) {
            guard !didPrewarmRemoteSearch else { return }
            didPrewarmRemoteSearch = true
            coordinator.prewarmRemoteSearchSnapshot(keyword: FeedCacheCoordinator.homeSearchKeyword)
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            shouldMountRemoteSearchPrewarmHost = true
        }
        .confirmationDialog(
            "この端末の設定をリセットしますか",
            isPresented: $homeState.shouldConfirmReset,
            titleVisibility: .visible
        ) {
            Button("全設定をリセット", role: .destructive) {
                resetAllSettings()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("チャンネル設定、動画キャッシュ、検索履歴、サムネイルを削除します。Documents のバックアップファイルは残ります。")
        }
    }

    private var navigationSection: some View {
        LazyVGrid(columns: layoutColumns, spacing: 16) {
            Menu {
                ForEach(ChannelBrowseSortMetric.allCases) { metric in
                    Section(metric.label) {
                        ForEach(SortDirection.allCases, id: \.self) { direction in
                            let option = ChannelBrowseSortDescriptor(metric: metric, direction: direction)
                            Button {
                                homeState.selectChannelSortDescriptor(option)
                                navigationPath.wrappedValue.append(MaintenanceRoute.channelList(option))
                            } label: {
                                HStack {
                                    Text(option.shortLabel)
                                    if option == homeState.channelSortDescriptor {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                MetricTile(
                    title: "チャンネル",
                    value: homeState.channelSortDescriptor.shortLabel,
                    detail: "並び順を選んでチャンネル一覧へ"
                )
            }
            .menuStyle(.borderlessButton)
            .accessibilityIdentifier("nav.channels")

            NavigationLink(value: MaintenanceRoute.allVideos) {
                MetricTile(
                    title: "動画",
                    value: "",
                    detail: "タップで動画一覧"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.videos")

            NavigationLink(value: MaintenanceRoute.keywordSearchResults("ゆっくり実況")) {
                MetricTile(
                    title: "キャッシュ検索",
                    value: "ゆっくり実況",
                    detail: "端末内キャッシュから新しい順に20件表示"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.search")

            NavigationLink(value: MaintenanceRoute.remoteKeywordSearchResults("ゆっくり実況")) {
                MetricTile(
                    title: "YouTube検索",
                    value: "ゆっくり実況",
                    detail: "開いた先で下に引っ張ると API 検索し、履歴を順次マージ"
                )
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    AppConsoleLogger.appLifecycle.info(
                        "remote_search_tile_tapped",
                        metadata: [
                            "layout": layout.usesSplitChannelBrowser ? "split" : "compact",
                            "keyword": FeedCacheCoordinator.homeSearchKeyword,
                        ]
                    )
                    RuntimeDiagnostics.shared.record(
                        "remote_search_home_tapped",
                        detail: "ホームから YouTube検索タイルを選択",
                        metadata: [
                            "layout": layout.usesSplitChannelBrowser ? "split" : "compact",
                            "keyword": FeedCacheCoordinator.homeSearchKeyword,
                        ]
                    )
                }
            )
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.remoteSearch")

            NavigationLink(value: MaintenanceRoute.channelRegistration) {
                MetricTile(
                    title: "チャンネル登録",
                    value: "",
                    detail: "タップで追加"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.channelRegistration")

            Menu {
                Button {
                    exportRegistry()
                } label: {
                    Label("バックアップを書き出し", systemImage: "square.and.arrow.up")
                }

                Button {
                    importRegistry()
                } label: {
                    Label("バックアップを読み込み", systemImage: "square.and.arrow.down")
                }
            } label: {
                MetricTile(
                    title: "バックアップ",
                    value: homeState.isTransferringRegistry ? "処理中..." : "",
                    detail: homeState.transferFeedback?.detail ?? "この端末内の固定JSONへ書き出し / 読み戻し"
                )
            }
            .menuStyle(.borderlessButton)
            .disabled(homeState.isTransferringRegistry)
            .accessibilityIdentifier("nav.registryTransfer")

            Button {
                homeState.requestResetAllSettings()
            } label: {
                MetricTile(
                    title: "全設定リセット",
                    value: homeState.isResettingAllSettings ? "処理中..." : "",
                    detail: "この端末の設定とキャッシュを削除。バックアップ JSON は残す"
                )
            }
            .buttonStyle(.plain)
            .disabled(homeState.isTransferringRegistry || homeState.isResettingAllSettings)
            .tint(.red)
            .accessibilityIdentifier("nav.resetAllSettings")
        }
    }

    private func exportRegistry() {
        guard !homeState.isTransferringRegistry else { return }
        homeState.beginRegistryTransfer()
        let logger = AppConsoleLogger.homeTransfer
        logger.info("export_started", metadata: ["backend": "localDocuments"])

        Task {
            do {
                let feedback = try coordinator.exportChannelRegistry(backend: .localDocuments)
                await MainActor.run {
                    homeState.finishRegistryTransfer(feedback)
                    logger.info(
                        "export_completed",
                        metadata: [
                            "backend": feedback.backend.rawValue,
                            "channel_count": String(feedback.channelCount)
                        ]
                    )
                }
            } catch {
                await MainActor.run {
                    homeState.failRegistryTransfer(error)
                    logger.error(
                        "export_failed",
                        message: AppConsoleLogger.errorSummary(error),
                        metadata: ["backend": "localDocuments"]
                    )
                }
            }
        }
    }

    private func importRegistry() {
        guard !homeState.isTransferringRegistry else { return }
        homeState.beginRegistryTransfer()

        Task {
            do {
                let feedback = try await coordinator.importChannelRegistry(backend: .localDocuments)
                await MainActor.run {
                    homeState.finishRegistryTransfer(feedback)
                }
            } catch {
                await MainActor.run {
                    homeState.failRegistryTransfer(error)
                }
            }
        }
    }

    private func resetAllSettings() {
        guard !homeState.isResettingAllSettings else { return }
        homeState.beginResetAllSettings()

        Task {
            do {
                let feedback = try await coordinator.resetAllSettings()
                await MainActor.run {
                    homeState.finishResetAllSettings(feedback)
                }
            } catch {
                await MainActor.run {
                    homeState.failResetAllSettings(error)
                }
            }
        }
    }

    private func registryTransferFeedbackCard(_ feedback: ChannelRegistryTransferFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedback.title)
                .font(.headline)

            Text(feedback.detail)
                .font(.subheadline)

            Text(feedback.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let refreshMessage = feedback.refreshMessage {
                Text(refreshMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func registryTransferErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("バックアップを完了できませんでした")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(ChannelRegistryTransferStore.fixedPathDescription(backend: .localDocuments))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func resetFeedbackCard(_ feedback: LocalStateResetFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedback.title)
                .font(.headline)

            Text(feedback.detail)
                .font(.subheadline)

            Text("バックアップから戻す場合は、Documents/YoutubeFeeder/channel-registry.json を読み込んでください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var layoutColumns: [GridItem] {
        if layout.isPad {
            return [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top),
            ]
        }

        return [GridItem(.flexible(), spacing: 16, alignment: .top)]
    }
}
