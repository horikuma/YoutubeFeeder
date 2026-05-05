import Darwin
import Foundation
import XCTest
@testable import YoutubeFeeder

func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () throws -> T) throws -> T {
    let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
    let previousValue = ProcessInfo.processInfo.environment[key]
    setenv(key, url.path, 1)
    defer {
        FeedCacheSQLiteDatabase.resetShared()
        if let previousValue {
            setenv(key, previousValue, 1)
        } else {
            unsetenv(key)
        }
    }
    return try operation()
}

func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () async throws -> T) async throws -> T {
    let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
    let previousValue = ProcessInfo.processInfo.environment[key]
    setenv(key, url.path, 1)
    defer {
        FeedCacheSQLiteDatabase.resetShared()
        if let previousValue {
            setenv(key, previousValue, 1)
        } else {
            unsetenv(key)
        }
    }
    return try await operation()
}

func withFeedCacheEnvironment<T>(
    baseDirectory: URL,
    operation: () async throws -> T
) async throws -> T {
    let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
    let previousValue = ProcessInfo.processInfo.environment[key]
    setenv(key, baseDirectory.path, 1)
    FeedCacheSQLiteDatabase.resetShared(fileManager: FileManager.default)

    defer {
        FeedCacheSQLiteDatabase.resetShared(fileManager: FileManager.default)
        if let previousValue {
            setenv(key, previousValue, 1)
        } else {
            unsetenv(key)
        }
    }

    return try await operation()
}

func withTemporaryFeedCacheBaseDirectory<T>(
    operation: (FileManager) async throws -> T
) async throws -> T {
    let fileManager = FileManager.default
    let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryRoot) }

    return try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
        try await operation(fileManager)
    }
}

func withEnvironment<T>(
    _ overrides: [String: String],
    operation: () async throws -> T
) async throws -> T {
    var previousValues: [String: String?] = [:]
    for key in overrides.keys {
        previousValues[key] = ProcessInfo.processInfo.environment[key]
    }

    for (key, value) in overrides {
        setenv(key, value, 1)
    }

    defer {
        FeedCacheSQLiteDatabase.resetShared()
        for (key, previousValue) in previousValues {
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
    }

    return try await operation()
}

func withRuntimeLogFile(_ url: URL, operation: () throws -> Void) rethrows {
    let key = "YOUTUBEFEEDER_RUNTIME_LOG_FILE"
    let previousValue = ProcessInfo.processInfo.environment[key]
    setenv(key, url.path, 1)
    defer {
        if let previousValue {
            setenv(key, previousValue, 1)
        } else {
            unsetenv(key)
        }
    }
    try operation()
}

func captureStandardOutput(_ operation: () throws -> Void) rethrows -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    try operation()

    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return unwrappedLogOutput(String(bytes: data, encoding: .utf8) ?? "")
}

func captureStandardError(_ operation: () throws -> Void) rethrows -> String {
    let pipe = Pipe()
    let originalStderr = dup(STDERR_FILENO)
    fflush(stderr)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    try operation()

    fflush(stderr)
    dup2(originalStderr, STDERR_FILENO)
    close(originalStderr)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return unwrappedLogOutput(String(bytes: data, encoding: .utf8) ?? "")
}

func captureStandardOutput<T>(
    _ operation: () async throws -> T
) async throws -> (T, String) {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    func restore() {
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()
    }

    do {
        let value = try await operation()
        restore()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (value, String(bytes: data, encoding: .utf8) ?? "")
    } catch {
        restore()
        throw error
    }
}

func unwrappedLogOutput(_ output: String) -> String {
    output
        .split(separator: "\n")
        .map { line -> String in
            guard
                let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data),
                let dictionary = object as? [String: Any],
                let wrappedLine = dictionary["line"] as? String
            else {
                return String(line)
            }

            return wrappedLine
        }
        .joined(separator: "\n")
}

func assertSnapshot(
    _ actual: FeedCacheSnapshot,
    matches expected: FeedCacheSnapshot,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(actual.savedAt, expected.savedAt, file: file, line: line)
    XCTAssertEqual(actual.channels, expected.channels, file: file, line: line)
    XCTAssertEqual(actual.videos, expected.videos, file: file, line: line)
    XCTAssertEqual(actual.playlists, expected.playlists, file: file, line: line)
}
