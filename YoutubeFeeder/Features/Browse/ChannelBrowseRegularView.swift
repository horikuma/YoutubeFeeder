import SwiftUI

struct ChannelBrowseRegularView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let viewModel: ChannelBrowseViewModel
    @Binding var state: ChannelBrowseLogic
    let onRefresh: () async -> Void

    private var items: [ChannelBrowseItem] {
        state.items
    }

    private var selectedChannelID: String? {
        state.selectedChannelID
    }

    private var selectedTitle: String {
        state.selectedTitle()
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        ChannelBrowseTipsSummary.build(items: state.items, sortDescriptor: sortDescriptor)
    }

    var body: some View {
        NavigationSplitView {
            ChannelBrowseSidebarView(
                items: items,
                selectedChannelID: selectedChannelID,
                layout: layout,
                sortDescriptor: sortDescriptor,
                tipsSummary: tipsSummary,
                usesDesktopMenus: AppInteractionPlatform.current.usesPrimaryClickForMenus,
                onSelectChannel: selectChannel(_:),
                onRequestRemoval: { state.requestRemoval(for: $0) }
            )
            .navigationTitle("チャンネル一覧")
        } detail: {
            ChannelBrowseDetailView(
                selectedTitle: selectedTitle,
                layout: layout,
                openVideo: openVideo,
                viewModel: viewModel,
                state: $state
            )
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
        .bindRefreshCommand {
            await onRefresh()
        }
        .onAppear {
            applyDefaultSelectionIfNeeded()
        }
        .onChange(of: items) {
            applyDefaultSelectionIfNeeded()
        }
    }

    private func selectChannel(_ channelID: String) {
        viewModel.selectChannel(channelID)
    }

    private func applyDefaultSelectionIfNeeded() {
        viewModel.applyDefaultSelectionIfNeeded()
    }
}
