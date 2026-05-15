import SwiftUI

struct HomeScreenRootView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let navigationPath: Binding<NavigationPath>
    @ObservedObject var viewModel: HomeScreenViewModel

    var body: some View {
        ZStack {
            HomeScreenScrollContentView(
                coordinator: coordinator,
                layout: layout,
                navigationPath: navigationPath,
                viewModel: viewModel
            )

            if viewModel.shouldMountRemoteSearchPrewarmHost {
                HomeScreenRemoteSearchPrewarmHostView(
                    coordinator: coordinator,
                    layout: layout,
                    path: $viewModel.remoteSearchPrewarmPath
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await viewModel.refreshHome()
        }
        .bindRefreshCommand {
            await viewModel.refreshHome()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .task {
            await viewModel.runAutoRefreshTaskIfNeeded()
        }
        .task(priority: .utility) {
            await viewModel.prewarmRemoteSearchIfNeeded()
        }
        .confirmationDialog(
            "この端末の設定をリセットしますか",
            isPresented: $viewModel.state.shouldConfirmReset,
            titleVisibility: .visible
        ) {
            Button("全設定をリセット", role: .destructive) {
                viewModel.resetAllSettings()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("チャンネル設定、動画キャッシュ、検索履歴、サムネイルを削除します。Documents のバックアップファイルは残ります。")
        }
    }
}

private struct HomeScreenScrollContentView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let navigationPath: Binding<NavigationPath>
    @ObservedObject var viewModel: HomeScreenViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                HomeScreenHeaderView(coordinator: coordinator, layout: layout, navigationPath: navigationPath)

                HomeScreenNavigationSectionView(
                    layout: layout,
                    navigationPath: navigationPath,
                    viewModel: viewModel
                )

                SystemStatusTile(status: coordinator.homeSystemStatus)

                if let transferFeedback = viewModel.state.transferFeedback {
                    HomeScreenRegistryTransferFeedbackCardView(feedback: transferFeedback)
                        .accessibilityIdentifier("home.transferFeedback")
                } else if let resetFeedback = viewModel.state.resetFeedback {
                    HomeScreenResetFeedbackCardView(feedback: resetFeedback)
                        .accessibilityIdentifier("home.resetFeedback")
                } else if let transferErrorMessage = viewModel.state.transferErrorMessage {
                    HomeScreenRegistryTransferErrorCardView(message: transferErrorMessage)
                        .accessibilityIdentifier("home.transferError")
                }
            }
            .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
    }
}
