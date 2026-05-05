import SwiftUI

struct HomeScreenHeaderView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let navigationPath: Binding<NavigationPath>

    var body: some View {
        VStack(alignment: .leading, spacing: layout.sectionSpacing) {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "test.manualRefreshCount",
                    value: "\(coordinator.manualRefreshCount)"
                )
                UITestNavigationTrigger(identifier: "test.channelList.route") {
                    navigationPath.wrappedValue.append(MaintenanceRoute.channelList(.default))
                }
            }

            Text("ホーム")
                .font(layout.isPad ? .system(size: 38, weight: .black, design: .rounded) : .largeTitle.bold())
                .accessibilityIdentifier("screen.home")
        }
    }
}
