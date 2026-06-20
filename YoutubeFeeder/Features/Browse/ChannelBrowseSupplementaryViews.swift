import SwiftUI
import Combine

struct ChannelBrowseLifecycleHost<Content: View>: View {
    let coordinator: FeedCacheCoordinator
    @ObservedObject var viewModel: ChannelBrowseViewModel
    @ViewBuilder let content: () -> Content
    @State private var isConfirmingChannelRemoval = false

    var body: some View {
        content()
            .task {
                await viewModel.loadChannelBrowseItems()
            }
            .onReceive(coordinator.$maintenanceItems.dropFirst()) { _ in
                viewModel.maintenanceItemsDidChange()
            }
            .confirmationDialog(
                viewModel.state.pendingChannelRemoval.map { "\($0.channelTitle)を削除しますか" } ?? "",
                isPresented: Binding(
                    get: { viewModel.state.pendingChannelRemoval != nil },
                    set: {
                        if !$0 && !isConfirmingChannelRemoval {
                            viewModel.clearPendingRemoval(reason: "dialog_dismissed")
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("チャンネルを削除", role: .destructive) {
                    isConfirmingChannelRemoval = true
                    Task {
                        await viewModel.confirmPendingRemoval()
                        isConfirmingChannelRemoval = false
                    }
                }
                Button("キャンセル", role: .cancel) {
                    viewModel.clearPendingRemoval(reason: "dialog_cancelled")
                }
            } message: {
                Text("このチャンネルの動画キャッシュと不要サムネイルも整理します。")
            }
            .alert(item: $viewModel.state.removalFeedback) { feedback in
                Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.detail),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                viewModel.onAppear()
            }
    }
}

struct ChannelBrowseHeaderView: View {
    let title: String
    let subtitle: String
    let layout: AppLayout
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .accessibilityIdentifier(accessibilityIdentifier)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
}

struct ChannelBrowseListView<Content: View>: View {
    let title: String
    let subtitle: String
    let coordinator: FeedCacheCoordinator
    @Binding var path: NavigationPath
    let layout: AppLayout
    let onRefresh: (() async -> Void)?
    let allowsRefreshCommandBinding: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        InteractiveListView(
            title: title,
            subtitle: subtitle,
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: onRefresh,
            allowsRefreshCommandBinding: allowsRefreshCommandBinding,
            content: content
        )
    }
}

struct ChannelBrowseTileView: View {
    enum Mode {
        case selection(isSelected: Bool, onSelect: () -> Void, onRequestRemoval: () -> Void)
        case navigation(destination: MaintenanceRoute, onOpen: () -> Void, onRequestRemoval: () -> Void)
    }

    let item: ChannelBrowseItem
    let index: Int
    let mode: Mode
    let menu: TileMenuConfiguration
    let usesDesktopMenus: Bool

    var body: some View {
        switch mode {
        case let .selection(isSelected, onSelect, onRequestRemoval):
            ChannelSelectionTile(
                item: item,
                isSelected: isSelected,
                index: index
            )
            .onTapGesture(perform: onSelect)
            .modifier(
                ChannelSelectionActionModifier(
                    item: item,
                    usesDesktopMenus: usesDesktopMenus,
                    menu: menu,
                    onRequestRemoval: { _ in onRequestRemoval() }
                )
            )
            .listInsertionTransition()
        case let .navigation(destination, onOpen, onRequestRemoval):
            if usesDesktopMenus {
                Button(action: onOpen) {
                    ChannelNavigationTile(item: item, index: index)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("channel.tile.\(item.channelID)")
                .contextMenu {
                    Button("チャンネルを削除", role: .destructive) {
                        onRequestRemoval()
                    }
                }
                .listInsertionTransition()
            } else {
                NavigationLink(value: destination) {
                    ChannelNavigationTile(item: item, index: index)
                        .accessibilityIdentifier("channel.tile.\(item.channelID)")
                }
                .buttonStyle(.plain)
                .tileActionMenu(
                    menu: menu,
                    accessibilityIdentifier: "channel.tile.\(item.channelID)",
                    desktopTriggerStyle: .contextMenu
                )
                .listInsertionTransition()
            }
        }
    }
}

struct ChannelBrowseEmptyStateView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        MetricTile(title: title, value: value, detail: detail)
    }
}

struct ChannelBrowseLoadingView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        MetricTile(title: title, value: value, detail: detail)
    }
}

struct ChannelBrowseTipsTile: View {
    let summary: ChannelBrowseTipsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tips")
                    .font(.headline)
                Spacer()
                Text(summary.countText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(summary.sortText)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("\(summary.primaryHint) / \(summary.secondaryHint)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.secondary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityIdentifier("channel.tipsTile")
    }
}

struct ChannelBrowseDisplayModeToggleView: View {
    let displayMode: ChannelBrowseDisplayMode
    let setDisplayMode: (ChannelBrowseDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            displayModeButton(title: "動画一覧", mode: .videos)
            displayModeButton(title: "プレイリスト一覧", mode: .playlists)
        }
    }

    private func displayModeButton(title: String, mode: ChannelBrowseDisplayMode) -> some View {
        let isSelected = displayMode == mode
        return Button {
            setDisplayMode(mode)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

struct ChannelBrowsePlaylistSortControlView: View {
    let binding: Binding<PlaylistBrowseVideoSortOrder>

    var body: some View {
        HStack(spacing: 12) {
            Text("並び順")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("並び順", selection: binding) {
                Text("新しい順")
                    .tag(PlaylistBrowseVideoSortOrder.newestFirst)
                Text("古い順")
                    .tag(PlaylistBrowseVideoSortOrder.oldestFirst)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()
        }
    }
}

struct ChannelBrowsePlaylistBackView: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("プレイリスト一覧へ戻る", action: onBack)
                .buttonStyle(.bordered)

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .accessibilityIdentifier("channel.playlist.back")
    }
}

private struct ChannelSelectionActionModifier: ViewModifier {
    let item: ChannelBrowseItem
    let usesDesktopMenus: Bool
    let menu: TileMenuConfiguration
    let onRequestRemoval: (ChannelBrowseItem) -> Void

    func body(content: Content) -> some View {
        if usesDesktopMenus {
            content
                .accessibilityIdentifier("channel.tile.\(item.channelID)")
                .contextMenu {
                    Button("チャンネルを削除", role: .destructive) {
                        onRequestRemoval(item)
                    }
                }
        } else {
            content
                .tileActionMenu(
                    menu: menu,
                    accessibilityIdentifier: "channel.tile.\(item.channelID)"
                )
        }
    }
}
