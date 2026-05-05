import Foundation
import SQLite3

final class FeedCacheSQLiteDatabaseConnection {
    let fileManager: FileManager
    let databaseURL: URL
    let baseDirectory: URL
    let queue: DispatchQueue
    let encoder = FeedCachePersistenceCoders.makeEncoder()
    let decoder = FeedCachePersistenceCoders.makeDecoder()

    private var database: OpaquePointer?

    init(databaseURL: URL, baseDirectory: URL, fileManager: FileManager) {
        self.databaseURL = databaseURL
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: "Neko.YoutubeFeeder.FeedCacheSQLiteDatabase.\(databaseURL.path)")
        queue.sync {
            openIfNeeded()
        }
    }

    deinit {
        close()
    }

    func sync<T>(_ body: () -> T) -> T {
        queue.sync(execute: body)
    }

    func close() {
        queue.sync {
            guard let database else { return }
            sqlite3_close_v2(database)
            self.database = nil
        }
    }

    func prepare(_ sql: String) -> OpaquePointer? {
        openIfNeeded()
        guard let database else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }
        return statement
    }

    func execute(_ sql: String, binder: ((OpaquePointer) -> Void)? = nil) {
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        binder?(statement)
        sqlite3_step(statement)
    }

    func scalarInt(_ sql: String, binder: ((OpaquePointer) -> Void)? = nil) -> Int {
        guard let statement = prepare(sql) else { return 0 }
        defer { sqlite3_finalize(statement) }
        binder?(statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    func beginTransaction() {
        execute(FeedCacheSQLiteDatabaseStatementBuilder.beginImmediateTransaction())
    }

    func commitTransaction() {
        execute(FeedCacheSQLiteDatabaseStatementBuilder.commitTransaction())
    }

    func tableHasColumn(table: String, column: String) -> Bool {
        guard let statement = prepare(FeedCacheSQLiteDatabaseStatementBuilder.tableInfo(table: table)) else { return false }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if string(at: 1, in: statement) == column {
                return true
            }
        }
        return false
    }

    func totalChanges() -> Int32 {
        guard let database else { return 0 }
        return sqlite3_total_changes(database)
    }

    func string(at index: Int32, in statement: OpaquePointer) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: raw)
    }

    func date(at index: Int32, in statement: OpaquePointer) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private func openIfNeeded() {
        guard database == nil else { return }
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            return
        }
        database = handle
        execute(FeedCacheSQLiteDatabaseStatementBuilder.pragmaForeignKeysOn())
        execute(FeedCacheSQLiteDatabaseStatementBuilder.pragmaJournalModeWal())
        execute(FeedCacheSQLiteDatabaseStatementBuilder.pragmaSynchronousNormal())
    }
}

let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

func bind(_ value: String?, at index: Int32, in statement: OpaquePointer) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
}

func bind(_ value: Double?, at index: Int32, in statement: OpaquePointer) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_double(statement, index, value)
}

func bind(_ value: Int?, at index: Int32, in statement: OpaquePointer) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}

func bind(_ value: Int32, at index: Int32, in statement: OpaquePointer) {
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}
