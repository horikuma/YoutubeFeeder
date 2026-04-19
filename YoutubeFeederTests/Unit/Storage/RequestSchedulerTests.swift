import Foundation
import XCTest
@testable import YoutubeFeeder

final class RequestSchedulerTests: LoggedTestCase {
    func testRequestsRespectMinimumInterval() async throws {
        let scheduler = RequestScheduler()
        let recorder = RequestStartRecorder()

        async let firstValue: Int = scheduler.enqueue {
            await recorder.record(Date())
            return 1
        }

        async let secondValue: Int = scheduler.enqueue {
            await recorder.record(Date())
            return 2
        }

        let values = try await (firstValue, secondValue)
        let starts = await recorder.snapshot()

        XCTAssertEqual(values.0, 1)
        XCTAssertEqual(values.1, 2)
        XCTAssertEqual(starts.count, 2)
        XCTAssertLessThan(starts[0], starts[1])
        XCTAssertGreaterThanOrEqual(starts[1].timeIntervalSince(starts[0]), 0.25)
    }
}

private actor RequestStartRecorder {
    private var starts: [Date] = []

    func record(_ date: Date) {
        starts.append(date)
    }

    func snapshot() -> [Date] {
        starts
    }
}
