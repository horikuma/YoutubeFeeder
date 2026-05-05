import SwiftUI

struct ChannelBrowseSidebarView: View {
    let items: [ChannelBrowseItem]
    let selectedChannelID: String?
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let tipsSummary: ChannelBrowseTipsSummary
    let usesDesktopMenus: Bool
    let onSelectChannel: (String) -> Void
    let onRequestRemoval: (ChannelBrowseItem) -> Void

    private var sortedItems: [ChannelBrowseItem] {
        items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ChannelBrowseTipsTile(summary: tipsSummary)

                if sortedItems.isEmpty {
                    ChannelBrowseEmptyStateView(
                        title: "チャンネル一覧",
                        value: "まだありません",
                        detail: "キャッシュが増えるとここに並びます"
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(sortedItems.enumerated()), id: \.element.id) { offset, item in
                            ChannelBrowseTileView(
                                item: item,
                                index: offset + 1,
                                mode: .selection(
                                    isSelected: item.channelID == selectedChannelID,
                                    onSelect: { onSelectChannel(item.channelID) },
                                    onRequestRemoval: { onRequestRemoval(item) }
                                ),
                                menu: selectionMenu(for: item),
                                usesDesktopMenus: usesDesktopMenus
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 420, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top) {
            ChannelBrowseHeaderView(
                title: "チャンネル一覧",
                subtitle: sortDescriptor.listSubtitle,
                layout: layout,
                accessibilityIdentifier: "screen.title"
            )
        }
    }

    private func selectionMenu(for item: ChannelBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: usesDesktopMenus ? TileMenuAction(title: "このチャンネルを表示", role: nil) {
                onSelectChannel(item.channelID)
            } : nil,
            secondaryActions: [
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    onRequestRemoval(item)
                }
            ]
        )
    }
}
