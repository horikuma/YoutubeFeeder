import XCTest
@testable import YoutubeFeeder

final class RemoteSearchErrorPolicyTests: LoggedTestCase {
    func testUserMessageSuppressesCancellationError() {
        XCTAssertNil(RemoteSearchErrorPolicy.userMessage(for: CancellationError()))
    }

    func testUserMessagePreservesOrdinaryErrorDescription() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "timed out"]
        )

        XCTAssertEqual(RemoteSearchErrorPolicy.userMessage(for: error), "timed out")
    }

    func testDiagnosticReasonRecognizesURLSessionCancellation() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)

        XCTAssertTrue(RemoteSearchErrorPolicy.isCancellation(error))
        XCTAssertEqual(RemoteSearchErrorPolicy.diagnosticReason(for: error), "urlsession_cancelled")
    }
}
