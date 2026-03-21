import Foundation
import XCTest

private enum UITestMetricsPaths {
    static let outputURL: URL = {
        if let directory = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_TEST_METRICS_DIR"],
           !directory.isEmpty {
            let base = URL(fileURLWithPath: directory, isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base.appendingPathComponent("YoutubeFeederUITests-events.jsonl")
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "YoutubeFeederUITests"
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("YoutubeFeederTestMetrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(bundleID)-events.jsonl")
    }()
}

private final class UITestMetricsObserver: NSObject, XCTestObservation {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let lock = NSLock()
    private var startedAtByTestID: [String: Date] = [:]

    func testCaseWillStart(_ testCase: XCTestCase) {
        let now = Date()
        let testID = testCase.name
        lock.lock()
        startedAtByTestID[testID] = now
        lock.unlock()

        appendEvent(
            kind: "start",
            testID: testID,
            startedAt: now,
            finishedAt: nil,
            durationSeconds: nil
        )
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        let now = Date()
        let testID = testCase.name
        lock.lock()
        let startedAt = startedAtByTestID.removeValue(forKey: testID)
        lock.unlock()

        let duration = startedAt.map { now.timeIntervalSince($0) }
        appendEvent(
            kind: "finish",
            testID: testID,
            startedAt: startedAt,
            finishedAt: now,
            durationSeconds: duration
        )
    }

    private func appendEvent(
        kind: String,
        testID: String,
        startedAt: Date?,
        finishedAt: Date?,
        durationSeconds: TimeInterval?
    ) {
        let event = UITestMetricsEvent(
            kind: kind,
            testID: testID,
            bundleID: Bundle.main.bundleIdentifier ?? "YoutubeFeederUITests",
            startedAt: startedAt,
            finishedAt: finishedAt,
            durationSeconds: durationSeconds
        )
        guard let data = try? encoder.encode(event),
              let line = String(data: data, encoding: .utf8) else {
            return
        }

        print("YOUTUBEFEEDER_TEST_METRIC \(line)")

        lock.lock()
        defer { lock.unlock() }
        let payload = line + "\n"
        if FileManager.default.fileExists(atPath: UITestMetricsPaths.outputURL.path) {
            if let handle = try? FileHandle(forWritingTo: UITestMetricsPaths.outputURL) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(payload.utf8))
            }
        } else {
            try? payload.write(to: UITestMetricsPaths.outputURL, atomically: true, encoding: .utf8)
        }
    }
}

private struct UITestMetricsEvent: Codable {
    let kind: String
    let testID: String
    let bundleID: String
    let startedAt: Date?
    let finishedAt: Date?
    let durationSeconds: TimeInterval?
}

enum UITestMetricsBootstrap {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        XCTestObservationCenter.shared.addTestObserver(UITestMetricsObserver())
    }
}
