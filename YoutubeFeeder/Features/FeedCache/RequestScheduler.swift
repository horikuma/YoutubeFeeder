import Foundation

actor RequestScheduler {
    typealias RequestOperation = @Sendable () async throws -> Void

    private var requestQueue: [RequestOperation] = []
    private let maxConcurrent: Int = 3
    private var runningRequestCount: Int = 0
    private let minIntervalMs: Int = 300
    private var lastRequestCompletedAt: Date?

    private func waitForMinimumIntervalIfNeeded() async {
        guard let lastRequestCompletedAt else {
            return
        }

        let minimumInterval = TimeInterval(minIntervalMs) / 1000
        let elapsed = Date.now.timeIntervalSince(lastRequestCompletedAt)
        guard elapsed < minimumInterval else {
            return
        }

        let remainingMilliseconds = Int(((minimumInterval - elapsed) * 1000).rounded(.up))
        guard remainingMilliseconds > 0 else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(remainingMilliseconds))
        } catch {
        }
    }

    private func runWorkerLoop() async {
        while !Task.isCancelled {
            guard runningRequestCount < maxConcurrent else {
                await Task.yield()
                continue
            }

            guard !requestQueue.isEmpty else {
                await Task.yield()
                continue
            }

            await waitForMinimumIntervalIfNeeded()
            let operation = requestQueue.removeFirst()
            runningRequestCount += 1
            defer {
                runningRequestCount -= 1
                lastRequestCompletedAt = .now
            }

            do {
                try await operation()
            } catch {
                continue
            }
        }
    }
}
