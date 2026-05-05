import SwiftUI

struct HomeScreenNavigationSectionView: View {
    let layout: AppLayout
    let navigationPath: Binding<NavigationPath>
    @ObservedObject var viewModel: HomeScreenViewModel

    var body: some View {
        LazyVGrid(columns: layoutColumns, spacing: 16) {
            HomeScreenChannelSortMenuTile(
                layout: layout,
                navigationPath: navigationPath,
                selectedSortDescriptor: viewModel.state.channelSortDescriptor,
                selectChannelSortDescriptor: viewModel.selectChannelSortDescriptor
            )

            HomeScreenNavigationMetricTile(
                title: "動画",
                value: "",
                detail: "タップで動画一覧",
                destination: MaintenanceRoute.allVideos,
                accessibilityIdentifier: "nav.videos"
            )

            HomeScreenNavigationMetricTile(
                title: "キャッシュ検索",
                value: "ゆっくり実況",
                detail: "端末内キャッシュから新しい順に20件表示",
                destination: MaintenanceRoute.keywordSearchResults("ゆっくり実況"),
                accessibilityIdentifier: "nav.search"
            )

            HomeScreenRemoteSearchTile(layout: layout)

            HomeScreenNavigationMetricTile(
                title: "チャンネル登録",
                value: "",
                detail: "タップで追加",
                destination: MaintenanceRoute.channelRegistration,
                accessibilityIdentifier: "nav.channelRegistration"
            )

            HomeScreenRegistryTransferMenuTile(
                viewModel: viewModel,
                accessibilityIdentifier: "nav.registryTransfer"
            )

            HomeScreenResetAllSettingsButtonTile(
                viewModel: viewModel,
                accessibilityIdentifier: "nav.resetAllSettings"
            )
        }
    }

    private var layoutColumns: [GridItem] {
        if layout.isPad {
            return [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top)
            ]
        }

        return [GridItem(.flexible(), spacing: 16, alignment: .top)]
    }
}

private struct HomeScreenChannelSortMenuTile: View {
    let layout: AppLayout
    let navigationPath: Binding<NavigationPath>
    let selectedSortDescriptor: ChannelBrowseSortDescriptor
    let selectChannelSortDescriptor: (ChannelBrowseSortDescriptor) -> Void

    var body: some View {
        Menu {
            ForEach(ChannelBrowseSortMetric.allCases) { metric in
                Section(metric.label) {
                    ForEach(SortDirection.allCases, id: \.self) { direction in
                        let option = ChannelBrowseSortDescriptor(metric: metric, direction: direction)
                        Button {
                            selectChannelSortDescriptor(option)
                            navigationPath.wrappedValue.append(MaintenanceRoute.channelList(option))
                        } label: {
                            HStack {
                                Text(option.shortLabel)
                                if option == selectedSortDescriptor {
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
                value: selectedSortDescriptor.shortLabel,
                detail: "並び順を選んでチャンネル一覧へ"
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("nav.channels")
    }
}

private struct HomeScreenNavigationMetricTile: View {
    let title: String
    let value: String
    let detail: String
    let destination: MaintenanceRoute
    let accessibilityIdentifier: String

    var body: some View {
        NavigationLink(value: destination) {
            MetricTile(title: title, value: value, detail: detail)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HomeScreenRemoteSearchTile: View {
    let layout: AppLayout

    var body: some View {
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
                        "keyword": FeedCacheCoordinator.homeSearchKeyword
                    ]
                )
                RuntimeDiagnostics.shared.record(
                    "remote_search_home_tapped",
                    detail: "ホームから YouTube検索タイルを選択",
                    metadata: [
                        "layout": layout.usesSplitChannelBrowser ? "split" : "compact",
                        "keyword": FeedCacheCoordinator.homeSearchKeyword
                    ]
                )
            }
        )
        .buttonStyle(.plain)
        .accessibilityIdentifier("nav.remoteSearch")
    }
}

private struct HomeScreenRegistryTransferMenuTile: View {
    @ObservedObject var viewModel: HomeScreenViewModel
    let accessibilityIdentifier: String

    var body: some View {
        Menu {
            Button {
                viewModel.exportRegistry()
            } label: {
                Label("バックアップを書き出し", systemImage: "square.and.arrow.up")
            }

            Button {
                viewModel.importRegistry()
            } label: {
                Label("バックアップを読み込み", systemImage: "square.and.arrow.down")
            }
        } label: {
            MetricTile(
                title: "バックアップ",
                value: viewModel.state.isTransferringRegistry ? "処理中..." : "",
                detail: viewModel.state.transferFeedback?.detail ?? "この端末内の固定JSONへ書き出し / 読み戻し"
            )
        }
        .menuStyle(.borderlessButton)
        .disabled(viewModel.state.isTransferringRegistry)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HomeScreenResetAllSettingsButtonTile: View {
    @ObservedObject var viewModel: HomeScreenViewModel
    let accessibilityIdentifier: String

    var body: some View {
        Button {
            viewModel.requestResetAllSettings()
        } label: {
            MetricTile(
                title: "全設定リセット",
                value: viewModel.state.isResettingAllSettings ? "処理中..." : "",
                detail: "この端末の設定とキャッシュを削除。バックアップ JSON は残す"
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state.isTransferringRegistry || viewModel.state.isResettingAllSettings)
        .tint(.red)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
