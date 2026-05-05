import SwiftUI

struct HomeScreenRemoteSearchPrewarmHostView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let path: Binding<NavigationPath>

    var body: some View {
        BasicGUIRemoteSearchScreen(
            keyword: FeedCacheCoordinator.homeSearchKeyword,
            coordinator: coordinator,
            openVideo: { _ in },
            path: path,
            layout: layout,
            presentationMode: .prewarm
        )
        .opacity(0.001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
