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
    private var startedRequestCount: Int = 0
    private var finishedRequestCount: Int = 0
    private var maxRunningObserved: Int = 0
    private var lastRequestStartedAt: Date?
    private var minStartIntervalObservedMs: Int?
    private var lastLoggedFinishedRequestCount: Int = 0
    private let aggregateLogInterval: Int = 50
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
            startedRequestCount += 1
            maxRunningObserved = max(maxRunningObserved, runningRequestCount)
            if let lastRequestStartedAt {
                let intervalMs = Int((Date.now.timeIntervalSince(lastRequestStartedAt) * 1000).rounded(.up))
                if intervalMs > 0 {
                    minStartIntervalObservedMs = minStartIntervalObservedMs.map { min($0, intervalMs) } ?? intervalMs
                }
            }
            lastRequestStartedAt = .now

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
                finishedRequestCount += 1
                AppConsoleLogger.feedRefresh.debug(
                    "request_scheduler_finish",
                    metadata: [
                        "request_id": String(request.id),
                        "queued": String(requestQueue.count),
                        "running": String(runningRequestCount)
                    ]
                )
                if finishedRequestCount % aggregateLogInterval == 0 {
                    AppConsoleLogger.feedRefresh.info(
                        "request_scheduler_progress",
                        metadata: aggregateMetadata(reason: "progress")
                    )
                    lastLoggedFinishedRequestCount = finishedRequestCount
                } else if requestQueue.isEmpty, runningRequestCount == 0, lastLoggedFinishedRequestCount != finishedRequestCount {
                    AppConsoleLogger.feedRefresh.info(
                        "request_scheduler_progress",
                        metadata: aggregateMetadata(reason: "idle")
                    )
                    lastLoggedFinishedRequestCount = finishedRequestCount
                }
            }

            do {
                try await request.operation()
            } catch {
                continue
            }
        }
    }

    private func aggregateMetadata(reason: String) -> [String: String] {
        [
            "reason": reason,
            "configured_min_interval_ms": String(minIntervalMs),
            "configured_max_concurrent": String(maxConcurrent),
            "started_requests": String(startedRequestCount),
            "finished_requests": String(finishedRequestCount),
            "max_running_observed": String(maxRunningObserved),
            "min_start_interval_ms_observed": minStartIntervalObservedMs.map(String.init) ?? "nil"
        ]
    }
}
