import SwiftUI

struct ChannelBrowseCompactView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    @Binding var path: NavigationPath
    let sortDescriptor: ChannelBrowseSortDescriptor
    @Binding var state: ChannelBrowseLogic
    let onRefresh: () async -> Void

    private var usesDesktopMenus: Bool {
        AppInteractionPlatform.current.usesPrimaryClickForMenus
    }

    private var items: [ChannelBrowseItem] {
        state.items
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        ChannelBrowseTipsSummary.build(items: state.items, sortDescriptor: sortDescriptor)
    }

    var body: some View {
        ChannelBrowseListView(
            title: "チャンネル一覧",
            subtitle: sortDescriptor.listSubtitle,
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: onRefresh,
            allowsRefreshCommandBinding: true
        ) {
            ChannelBrowseTipsTile(summary: tipsSummary)

            if items.isEmpty {
                ChannelBrowseEmptyStateView(
                    title: "チャンネル一覧",
                    value: "まだありません",
                    detail: "キャッシュが増えるとここに並びます"
                )
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        ChannelBrowseTileView(
                            item: item,
                            index: offset + 1,
                            mode: .navigation(
                                destination: MaintenanceRoute.channelVideos(
                                    ChannelVideosRouteContext(
                                        channelID: item.channelID,
                                        preferredChannelTitle: item.channelTitle
                                    )
                                ),
                                onOpen: {
                                    path.append(
                                        MaintenanceRoute.channelVideos(
                                            ChannelVideosRouteContext(
                                                channelID: item.channelID,
                                                preferredChannelTitle: item.channelTitle
                                            )
                                        )
                                    )
                                },
                                onRequestRemoval: {
                                    state.requestRemoval(for: item)
                                }
                            ),
                            menu: channelMenu(for: item),
                            usesDesktopMenus: usesDesktopMenus
                        )
                    }
                }
            }
        }
    }

    private func channelMenu(for item: ChannelBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: usesDesktopMenus ? TileMenuAction(title: "動画一覧を開く", role: nil) {
                path.append(
                    MaintenanceRoute.channelVideos(
                        ChannelVideosRouteContext(
                            channelID: item.channelID,
                            preferredChannelTitle: item.channelTitle
                        )
                    )
                )
            } : nil,
            secondaryActions: [
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    state.requestRemoval(for: item)
                }
            ]
        )
    }
}
