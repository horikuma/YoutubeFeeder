import SwiftUI
import XCTest
@testable import YoutubeFeeder

final class BasicGUICompositionTests: LoggedTestCase {
    func testRouteAssemblyPreservesChannelListSortDescriptor() {
        let route = MaintenanceRoute.channelList(.default)

        let screen = BasicGUIRouteAssembly.screen(for: route)

        XCTAssertEqual(screen, .channelList(sortDescriptor: .default))
    }

    func testRouteAssemblyPreservesChannelVideosContext() {
        let context = ChannelVideosRouteContext(
            channelID: "channel-1",
            preferredChannelTitle: "Channel 1",
            selectedVideoID: "video-1",
            prefersAutomaticRefresh: true,
            routeSource: .remoteSearch
        )

        let screen = BasicGUIRouteAssembly.screen(for: .channelVideos(context))

        XCTAssertEqual(screen, .channelVideos(context: context))
    }

    func testCompactLayoutUsesCompactBasicGUIPresentation() {
        let layout = AppLayout.current(
            size: CGSize(width: 844, height: 390),
            horizontalSizeClass: .compact
        )

        XCTAssertEqual(BasicGUILayoutBranching.channelBrowsePresentation(for: layout), .compact)
        XCTAssertEqual(BasicGUILayoutBranching.remoteSearchPresentation(for: layout), .compact)
    }

    func testRegularLayoutUsesSplitBasicGUIPresentation() {
        let layout = AppLayout.current(
            size: CGSize(width: 1366, height: 1024),
            horizontalSizeClass: .regular
        )

        XCTAssertEqual(BasicGUILayoutBranching.channelBrowsePresentation(for: layout), .split)
        XCTAssertEqual(BasicGUILayoutBranching.remoteSearchPresentation(for: layout), .split)
    }
}
