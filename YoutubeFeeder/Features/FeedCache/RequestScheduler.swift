import Foundation

actor RequestScheduler {
    typealias RequestOperation = @Sendable () async throws -> Void

    private var requestQueue: [RequestOperation] = []
}
