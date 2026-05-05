import SwiftUI
import Combine

struct ChannelBrowseView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let presentation: BasicGUIBrowsePresentation

    @StateObject private var viewModel: ChannelBrowseViewModel

    init(
        coordinator: FeedCacheCoordinator,
        openVideo: @escaping (CachedVideo) -> Void,
        path: Binding<NavigationPath>,
        layout: AppLayout,
        sortDescriptor: ChannelBrowseSortDescriptor,
        presentation: BasicGUIBrowsePresentation
    ) {
        self.coordinator = coordinator
        self.openVideo = openVideo
        _path = path
        self.layout = layout
        self.sortDescriptor = sortDescriptor
        self.presentation = presentation
        _viewModel = StateObject(
            wrappedValue: ChannelBrowseViewModel(
                coordinator: coordinator,
                sortDescriptor: sortDescriptor
            )
        )
    }

    var body: some View {
        ChannelBrowseLifecycleHost(coordinator: coordinator, viewModel: viewModel) {
            Group {
                switch presentation {
                case .split:
                    ChannelBrowseRegularView(
                        coordinator: coordinator,
                        openVideo: openVideo,
                        path: $path,
                        layout: layout,
                        sortDescriptor: sortDescriptor,
                        viewModel: viewModel,
                        state: $viewModel.state,
                        onRefresh: {
                            await viewModel.refreshChannelBrowseItems()
                        }
                    )
                case .compact:
                    ChannelBrowseCompactView(
                        coordinator: coordinator,
                        layout: layout,
                        path: $path,
                        sortDescriptor: sortDescriptor,
                        state: $viewModel.state,
                        onRefresh: {
                            await viewModel.refreshChannelBrowseItems()
                        }
                    )
                }
            }
        }
    }
}
