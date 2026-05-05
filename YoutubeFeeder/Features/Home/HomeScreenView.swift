import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>
    @StateObject private var viewModel: HomeScreenViewModel

    init(
        coordinator: FeedCacheCoordinator,
        layout: AppLayout,
        diagnostics: StartupDiagnostics,
        navigationPath: Binding<NavigationPath>
    ) {
        self.coordinator = coordinator
        self.layout = layout
        self.diagnostics = diagnostics
        self.navigationPath = navigationPath
        _viewModel = StateObject(
            wrappedValue: HomeScreenViewModel(
                coordinator: coordinator,
                layout: layout,
                diagnostics: diagnostics
            )
        )
    }

    var body: some View {
        HomeScreenRootView(
            coordinator: coordinator,
            layout: layout,
            navigationPath: navigationPath,
            viewModel: viewModel
        )
    }
}
