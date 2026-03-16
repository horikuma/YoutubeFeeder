import XCTest
@testable import HelloWorld

final class ChannelBrowseTipsSummaryTests: XCTestCase {
    func testBuildSummarizesChannelCountAndSort() {
        let items = [
            makeItem(channelID: "UC001", title: "Alpha"),
            makeItem(channelID: "UC002", title: "Beta")
        ]

        let summary = ChannelBrowseTipsSummary.build(
            items: items,
            sortDescriptor: ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .ascending)
        )

        XCTAssertEqual(summary.countText, "2件")
        XCTAssertEqual(summary.sortText, "チャンネル登録日時 ↑")
        XCTAssertEqual(summary.primaryHint, "タップで動画一覧")
        XCTAssertEqual(summary.secondaryHint, "長押しで削除")
    }

    func testBuildHandlesEmptyList() {
        let summary = ChannelBrowseTipsSummary.build(
            items: [],
            sortDescriptor: .default
        )

        XCTAssertEqual(summary.countText, "0件")
        XCTAssertEqual(summary.sortText, "動画投稿日時 ↓")
    }

    private func makeItem(channelID: String, title: String) -> ChannelBrowseItem {
        ChannelBrowseItem(
            id: channelID,
            channelID: channelID,
            channelTitle: title,
            latestPublishedAt: nil,
            registeredAt: nil,
            latestVideo: nil,
            cachedVideoCount: 0
        )
    }
}
