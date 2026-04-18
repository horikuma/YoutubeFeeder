import XCTest
@testable import YoutubeFeeder

final class ChannelRegistrationLogicTests: LoggedTestCase {
    func testDefaultsStartEmptyAndIdle() {
        let state = ChannelRegistrationLogic()

        XCTAssertNil(state.errorMessage)
        XCTAssertNil(state.feedback)
        XCTAssertFalse(state.isSubmitting)
        XCTAssertFalse(state.isImportingCSV)
        XCTAssertNil(state.importFeedback)
        XCTAssertFalse(state.isCSVImporterPresented)
    }

    func testSubmitLifecycleUpdatesOnlyRegistrationState() {
        var state = ChannelRegistrationLogic(
            errorMessage: "old error",
            feedback: makeRegistrationFeedback(),
            isSubmitting: false,
            isImportingCSV: true,
            importFeedback: makeImportFeedback(),
            isCSVImporterPresented: false
        )

        state.beginSubmit()

        XCTAssertNil(state.errorMessage)
        XCTAssertNil(state.feedback)
        XCTAssertTrue(state.isSubmitting)
        XCTAssertNil(state.importFeedback)

        let success = makeRegistrationFeedback()
        state.finishSubmit(success)

        XCTAssertEqual(state.feedback, success)
        XCTAssertFalse(state.isSubmitting)

        state.failSubmit(SampleError(message: "submit failed"))

        XCTAssertEqual(state.feedback, success)
        XCTAssertEqual(state.errorMessage, "submit failed")
        XCTAssertFalse(state.isSubmitting)
    }

    func testCSVImportLifecycleHandlesPresentationAndExecution() {
        var state = ChannelRegistrationLogic(
            errorMessage: "old error",
            feedback: makeRegistrationFeedback(),
            isSubmitting: true,
            isImportingCSV: false,
            importFeedback: makeImportFeedback(),
            isCSVImporterPresented: false
        )

        state.beginCSVImport()

        XCTAssertNil(state.errorMessage)
        XCTAssertNil(state.feedback)
        XCTAssertNil(state.importFeedback)
        XCTAssertFalse(state.isImportingCSV)

        let fileURL = URL(fileURLWithPath: "/tmp/channel-registry.csv")
        state.beginCSVImport(fromFile: fileURL)

        XCTAssertTrue(state.isImportingCSV)
        XCTAssertNil(state.errorMessage)
        XCTAssertNil(state.feedback)
        XCTAssertNil(state.importFeedback)

        let success = makeImportFeedback()
        state.finishCSVImport(success)

        XCTAssertEqual(state.importFeedback, success)
        XCTAssertFalse(state.isImportingCSV)

        state.failCSVImportPresentation(SampleError(message: "picker failed"))
        XCTAssertEqual(state.errorMessage, "picker failed")

        state.beginCSVImport(fromFile: fileURL)
        state.failCSVImport(SampleError(message: "import failed"))

        XCTAssertEqual(state.errorMessage, "import failed")
        XCTAssertFalse(state.isImportingCSV)
    }

    func testRequestCSVImportPresentsImporterWithoutStartingExecution() {
        var state = ChannelRegistrationLogic()

        state.requestCSVImport()

        XCTAssertTrue(state.isCSVImporterPresented)
        XCTAssertFalse(state.isImportingCSV)
        XCTAssertNil(state.errorMessage)
        XCTAssertNil(state.feedback)
        XCTAssertNil(state.importFeedback)
    }

    private func makeRegistrationFeedback() -> ChannelRegistrationFeedback {
        ChannelRegistrationFeedback(
            status: .added,
            channelID: "UC123",
            channelTitle: "Channel",
            latestVideoTitle: "Latest",
            latestPublishedAt: Date(timeIntervalSince1970: 1_742_000_000),
            cachedVideoCount: 5,
            latestFeedError: nil
        )
    }

    private func makeImportFeedback() -> ChannelCSVImportFeedback {
        ChannelCSVImportFeedback(
            totalRowCount: 3,
            importedCount: 2,
            alreadyRegisteredCount: 1,
            path: "/tmp/channel-registry.csv",
            refreshMessage: "refreshed"
        )
    }

    private struct SampleError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }
}
