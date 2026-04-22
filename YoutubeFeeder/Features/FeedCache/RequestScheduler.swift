import Foundation

actor RequestScheduler {
    typealias RequestOperation = @Sendable () async throws -> Void

    private struct QueuedRequest {
        let id: Int
        let operation: RequestOperation
    }

    private var requestQueue: [QueuedRequest] = []
    private let maxConcurrent: Int = 3
    private var runningRequestCount: Int = 0
    private let minIntervalMs: Int = 300
    private var lastRequestCompletedAt: Date?
    private var workerTask: Task<Void, Never>?
    private var nextRequestID: Int = 1

    func enqueue<Value>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let requestID = nextRequestID
        nextRequestID += 1

        AppConsoleLogger.feedRefresh.debug(
            "request_scheduler_enqueue",
            metadata: [
                "request_id": String(requestID),
                "queued": String(requestQueue.count + 1),
                "running": String(runningRequestCount)
            ]
        )

        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.append(QueuedRequest(id: requestID) {
                do {
                    let value = try await operation()
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            })
            startWorkerLoopIfNeeded()
        }
    }

    private func startWorkerLoopIfNeeded() {
        guard workerTask == nil else {
            return
        }

        workerTask = Task {
            await self.runWorkerLoop()
        }
    }

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
            let request = requestQueue.removeFirst()
            runningRequestCount += 1

            AppConsoleLogger.feedRefresh.debug(
                "request_scheduler_start",
                metadata: [
                    "request_id": String(request.id),
                    "queued": String(requestQueue.count),
                    "running": String(runningRequestCount)
                ]
            )

            defer {
                runningRequestCount -= 1
                lastRequestCompletedAt = .now
                AppConsoleLogger.feedRefresh.debug(
                    "request_scheduler_finish",
                    metadata: [
                        "request_id": String(request.id),
                        "queued": String(requestQueue.count),
                        "running": String(runningRequestCount)
                    ]
                )
            }

            do {
                try await request.operation()
            } catch {
                continue
            }
        }
    }
}
