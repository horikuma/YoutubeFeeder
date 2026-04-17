import XCTest
@testable import YoutubeFeeder

final class HomeScreenLogicTests: LoggedTestCase {
    func testDefaultsStartWithDefaultSortAndNoFeedback() {
        let state = HomeScreenLogic()

        XCTAssertEqual(state.channelSortDescriptor, .default)
        XCTAssertNil(state.transferFeedback)
        XCTAssertNil(state.resetFeedback)
        XCTAssertNil(state.transferErrorMessage)
    }

    func testRegistryTransferLifecycleKeepsResetStateClearedAndRecordsOutcome() {
        var state = HomeScreenLogic(
            channelSortDescriptor: ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .ascending),
            transferFeedback: makeTransferFeedback(action: .export),
            resetFeedback: makeResetFeedback(),
            transferErrorMessage: "old error"
        )

        state.beginRegistryTransfer()

        XCTAssertEqual(state.channelSortDescriptor, ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .ascending))
        XCTAssertEqual(state.transferFeedback, makeTransferFeedback(action: .export))
        XCTAssertNil(state.resetFeedback)
        XCTAssertNil(state.transferErrorMessage)

        let successFeedback = makeTransferFeedback(action: .import)
        state.finishRegistryTransfer(successFeedback)

        XCTAssertEqual(state.transferFeedback, successFeedback)

        state.failRegistryTransfer(SampleError(message: "transfer failed"))

        XCTAssertNil(state.transferFeedback)
        XCTAssertEqual(state.transferErrorMessage, "transfer failed")
    }

    func testResetLifecycleKeepsTransferStateClearedAndRecordsOutcome() {
        var state = HomeScreenLogic(
            channelSortDescriptor: .default,
            transferFeedback: makeTransferFeedback(action: .import),
            resetFeedback: makeResetFeedback(),
            transferErrorMessage: "old error"
        )

        state.beginResetAllSettings()

        XCTAssertEqual(state.transferFeedback, nil)
        XCTAssertEqual(state.resetFeedback, makeResetFeedback())
        XCTAssertNil(state.transferErrorMessage)

        let successFeedback = makeResetFeedback()
        state.finishResetAllSettings(successFeedback)

        XCTAssertEqual(state.resetFeedback, successFeedback)

        state.failResetAllSettings(SampleError(message: "reset failed"))

        XCTAssertNil(state.resetFeedback)
        XCTAssertEqual(state.transferErrorMessage, "reset failed")
    }

    func testSelectChannelSortDescriptorUpdatesOnlyTheSortState() {
        var state = HomeScreenLogic()
        let descriptor = ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .descending)

        state.selectChannelSortDescriptor(descriptor)

        XCTAssertEqual(state.channelSortDescriptor, descriptor)
        XCTAssertNil(state.transferFeedback)
        XCTAssertNil(state.resetFeedback)
        XCTAssertNil(state.transferErrorMessage)
    }

    private func makeTransferFeedback(action: ChannelRegistryTransferAction) -> ChannelRegistryTransferFeedback {
        ChannelRegistryTransferFeedback(
            action: action,
            backend: .localDocuments,
            channelCount: 3,
            path: "/tmp/channel-registry.json",
            refreshMessage: "refresh"
        )
    }

    private func makeResetFeedback() -> LocalStateResetFeedback {
        LocalStateResetFeedback(
            removedChannelCount: 1,
            removedVideoCount: 2,
            removedThumbnailCount: 3,
            removedSearchCacheCount: 4
        )
    }

    private struct SampleError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }
}
