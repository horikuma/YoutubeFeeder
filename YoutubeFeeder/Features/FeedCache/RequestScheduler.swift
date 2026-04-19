import Foundation

actor RequestScheduler {
    typealias RequestOperation = @Sendable () async throws -> Void

    private var requestQueue: [RequestOperation] = []
    private let maxConcurrent: Int = 3
    private var runningRequestCount: Int = 0
    private let minIntervalMs: Int = 300
    private var lastRequestCompletedAt: Date?
}
