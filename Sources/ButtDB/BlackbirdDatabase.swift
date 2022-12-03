//
//  ButtDBDatabase.swift
//  Created by Marco Arment on 11/28/22.
//  Copyright (c) 2022 Marco Arment
//
//  Released under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import SQLite3

internal protocol ButtDBQueryable {
    /// Executes arbitrary SQL queries without returning a value.
    ///
    /// - Parameter query: The SQL string to execute. May contain multiple queries separated by semicolons (`;`).
    ///
    /// Queries are passed to SQLite without any additional parameters or automatic replacements.
    ///
    /// Any type of query valid in SQLite may be used here.
    ///
    /// ## Example
    /// ```swift
    /// try await db.execute("PRAGMA user_version = 1; UPDATE posts SET deleted = 0")
    /// ```
    func execute(_ query: String) async throws
    
    /// Performs an atomic, cancellable transaction with synchronous database access and batched change notifications.
    /// - Parameters:
    ///     - action: The actions to perform in the transaction. If an error is thrown, the transaction is rolled back and the error is rethrown to the caller.
    ///    
    ///         Use ``cancellableTransaction(_:)`` to roll back transactions without throwing errors.
    ///
    /// While inside the transaction's `action`:
    /// * Queries against the isolated ``ButtDB/Database/Core`` can be executed synchronously (using `try` instead of `try await`).
    /// * Change notifications for this database, via both ``ButtDB/ChangePublisher`` and ``ButtDB/legacyChangeNotification``, are queued until the transaction is completed. When delivered, multiple changes for the same table are consolidated into a single notification with every affected primary-key value.
    ///
    ///     __Note:__ Notifications may be sent for changes occurring during the transaction even if the transaction is rolled back.
    ///
    /// ## Example
    /// ```swift
    /// try await db.transaction { core in
    ///     try core.query("INSERT INTO posts (id, title) VALUES (?, ?)", 1, "Title 1")
    ///     try core.query("INSERT INTO posts (id, title) VALUES (?, ?)", 2, "Title 2")
    ///     //...
    ///     try core.query("INSERT INTO posts (id, title) VALUES (?, ?)", 999, "Title 999")
    /// }
    /// ```
    ///
    /// > Performing large quantities of database writes is typically much faster inside a transaction.
    ///
    /// ## See also
    /// ``cancellableTransaction(_:)``
    func transaction(_ action: ((_ core: isolated ButtDB.Database.Core) throws -> Void) ) async throws

    /// Equivalent to ``transaction(_:)``, but with the ability to cancel without throwing an error.
    /// - Parameter action: The actions to perform in the transaction. Return `true` to commit the transaction or `false` to roll it back. If an error is thrown, the transaction is rolled back and the error is rethrown to the caller.
    ///
    /// See ``transaction(_:)`` for details.
    ///
    /// ## Example
    /// ```swift
    /// try await db.cancellableTransaction { core in
    ///     try core.query("INSERT INTO posts (id, title) VALUES (?, ?)", 1, "Title 1")
    ///     try core.query("INSERT INTO posts (id, title) VALUES (?, ?)", 2, "Title 2")
    ///     //...
    ///     try core.query("INSERT INTO posts (id, title) VALUES (?, ?)", 999, "Title 999")
    ///
    ///     let areWeReadyForCommitment: Bool = //...
    ///     return areWeReadyForCommitment
    /// }
    /// ```
    func cancellableTransaction(_ action: ((_ core: isolated ButtDB.Database.Core) throws -> Bool) ) async throws

    
    /// Queries the database.
    /// - Parameter query: An SQL query.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let ids = try await db.query("SELECT id FROM posts WHERE state = 1")
    /// ```
    @discardableResult func query(_ query: String) async throws -> [ButtDB.Row]
    
    /// Queries the database with an optional list of arguments.
    /// - Parameters:
    ///   - query: An SQL query that may contain placeholders specified as a question mark (`?`).
    ///   - arguments: Values corresponding to any placeholders in the query.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let rows = try await db.query(
    ///     "SELECT id FROM posts WHERE state = ? OR title = ?",
    ///     1,           // value for state
    ///     "Test Title" // value for title
    /// )
    /// ```
    @discardableResult func query(_ query: String, _ arguments: Any...) async throws -> [ButtDB.Row]
    
    /// Queries the database with an array of arguments.
    /// - Parameters:
    ///   - query: An SQL query that may contain placeholders specified as a question mark (`?`).
    ///   - arguments: An array of values corresponding to any placeholders in the query.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let rows = try await db.query(
    ///     "SELECT id FROM posts WHERE state = ? OR title = ?",
    ///     arguments: [1 /* value for state */, "Test Title" /* value for title */]
    /// )
    /// ```
    @discardableResult func query(_ query: String, arguments: [Any]) async throws -> [ButtDB.Row]
    
    /// Queries the database using a dictionary of named arguments.
    ///
    /// - Parameters:
    ///   - query: An SQL query that may contain named placeholders prefixed by a colon (`:`), at-sign (`@`), or dollar sign (`$`) as described in the [SQLite documentation](https://www.sqlite.org/c3ref/bind_blob.html).
    ///   - arguments: A dictionary of placeholder names used in the query and their corresponding values. Names must include the prefix character used.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let rows = try await db.query(
    ///     "SELECT id FROM posts WHERE state = :state OR title = :title",
    ///     arguments: [":state": 1, ":title": "Test Title"]
    /// )
    /// ```
    @discardableResult func query(_ query: String, arguments: [String: Any]) async throws -> [ButtDB.Row]
}

extension ButtDB {
    /// A managed SQLite database.
    ///
    /// A lightweight wrapper around [SQLite](https://www.sqlite.org/).
    ///
    /// ### Basic usage
    /// The database is accessed primarily via `async` calls, internally using an `actor` for performance, concurrency, and isolation.
    ///
    /// ```swift
    /// let db = try ButtDB.Database(path: "/tmp/test.sqlite")
    ///
    /// // SELECT with structured arguments and returned rows
    /// for row in try await db.query("SELECT id FROM posts WHERE state = ?", 1) {
    ///     let id = row["id"]
    ///     // ...
    /// }
    ///
    /// // Run direct queries
    /// try await db.execute("UPDATE posts SET comments = NULL")
    /// ```
    ///
    /// ### Synchronous transactions
    /// The isolated actor can also be accessed from ``transaction(_:)`` for synchronous functionality or high-performance batch operations:
    /// ```swift
    /// try await db.transaction { core in
    ///     try core.query("INSERT INTO posts VALUES (?, ?)", 16, "Sports!")
    ///     try core.query("INSERT INTO posts VALUES (?, ?)", 17, "Dewey Defeats Truman")
    ///     //...
    ///     try core.query("INSERT INTO posts VALUES (?, ?)", 89, "Florida Man At It Again")
    /// }
    /// ```
    ///
    public class Database: Identifiable, Hashable, Equatable, ButtDBQueryable {
        /// Process-unique identifiers for Database instances. Used internally.
        public typealias InstanceID = Int64

        /// A process-unique identifier for this instance. Used internally.
        public let id: InstanceID
        
        public static func == (lhs: Database, rhs: Database) -> Bool { return lhs.id == rhs.id }
        
        public func hash(into hasher: inout Hasher) { hasher.combine(id) }

        public enum Error: Swift.Error {
            case anotherInstanceExistsWithPath(path: String)
            case cannotOpenDatabaseAtPath(path: String, description: String)
            case unsupportedConfigurationAtPath(path: String)
            case queryError(query: String, description: String)
            case queryArgumentNameError(query: String, name: String)
            case queryArgumentValueError(query: String, description: String)
            case queryExecutionError(query: String, description: String)
            case queryResultValueError(query: String, column: String)
            case databaseIsClosed
        }
        
        /// Options for customizing database behavior.
        public struct Options: OptionSet {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }

            internal static let inMemoryDatabase            = Options(rawValue: 1 << 0)

            /// Sets the database to read-only. Any calls to ``ButtDBModel`` write functions with a read-only database will terminate with a fatal error.
            public static let readOnly                      = Options(rawValue: 1 << 1)
            
            /// Logs every query with `print()`. Useful for debugging.
            public static let debugPrintEveryQuery          = Options(rawValue: 1 << 2)
            
            /// Logs every change reported by ``ButtDB/ChangePublisher`` instances for this database with `print()`. Useful for debugging.
            public static let debugPrintEveryReportedChange = Options(rawValue: 1 << 3)
            
            /// Sends ``ButtDB/legacyChangeNotification`` notifications using `NotificationCenter`.
            public static let sendLegacyChangeNotifications = Options(rawValue: 1 << 4)
        }
        
        /// The path to the database file, or `nil` for in-memory databases.
        public let path: String?
        
        /// The ``Options-swift.struct`` used to create the database.
        public let options: Options
        
        internal let core: Core
        internal var changeReporter: ChangeReporter

        private static var instanceLock = Lock()
        private static var nextInstanceID: InstanceID = 0
        private static var pathsOfCurrentInstances = Set<String>()
        
        /// Instantiates a new SQLite database in memory, without persisting to a file.
        public static func inMemoryDatabase(options: Options = []) throws -> Database {
            return try Database(path: "", options: options.union([.inMemoryDatabase]))
        }
        
        /// Instantiates a new SQLite database as a file on disk.
        ///
        /// - Parameters:
        ///   - path: The path to the database file. If no file exists at `path`, it will be created.
        ///   - options: Any custom behavior desired.
        ///
        /// At most one instance per database filename may exist at a time.
        ///
        /// An error will be thrown if another instance exists with the same filename, the database cannot be created, or the linked version of SQLite lacks the required capabilities.
        public init(path: String, options: Options = []) throws {
            id = try Self.instanceLock.withLock {
                if !options.contains(.inMemoryDatabase), Self.pathsOfCurrentInstances.contains(path) { throw Error.anotherInstanceExistsWithPath(path: path) }
                let id = Self.nextInstanceID
                Self.nextInstanceID += 1
                return id
            }
            
            var normalizedOptions = options
            if path.isEmpty || path == ":memory:" { normalizedOptions.insert(.inMemoryDatabase) }

            self.options = normalizedOptions
            self.path = normalizedOptions.contains(.inMemoryDatabase) ? nil : path
            self.changeReporter = ChangeReporter(options: options)

            var handle: OpaquePointer? = nil
            let flags: Int32 = (options.contains(.readOnly) ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) | SQLITE_OPEN_NOMUTEX
            let result = sqlite3_open_v2(self.path ?? ":memory:", &handle, flags, nil)
            guard let handle else { throw Error.cannotOpenDatabaseAtPath(path: path, description: "SQLite cannot allocate memory") }
            guard result == SQLITE_OK else {
                let code = sqlite3_errcode(handle)
                let msg = String(cString: sqlite3_errmsg(handle), encoding: .utf8) ?? "(unknown)"
                sqlite3_close(handle)
                throw Error.cannotOpenDatabaseAtPath(path: path, description: "SQLite error code \(code): \(msg)")
            }
            
            if SQLITE_OK != sqlite3_exec(handle, "PRAGMA journal_mode = WAL", nil, nil, nil) || SQLITE_OK != sqlite3_exec(handle, "PRAGMA synchronous = NORMAL", nil, nil, nil) {
                sqlite3_close(handle)
                throw Error.unsupportedConfigurationAtPath(path: path)
            }

            if let filePath = self.path {
                Self.instanceLock.withLock { Self.pathsOfCurrentInstances.insert(filePath) }
            }

            core = Core(handle, changeReporter: changeReporter, options: options)
            
            sqlite3_update_hook(handle, { ctx, operation, dbName, tableName, rowid in
                guard let ctx else { return }
                let changeReporter = Unmanaged<ChangeReporter>.fromOpaque(ctx).takeUnretainedValue()
                if let tableName, let tableNameStr = String(cString: tableName, encoding: .utf8) {
                    changeReporter.reportChange(tableName: tableNameStr)
                }
            }, Unmanaged<ChangeReporter>.passUnretained(changeReporter).toOpaque())
        }
        
        deinit {
            if let path {
                Self.instanceLock.withLock { Self.pathsOfCurrentInstances.remove(path) }
            }
        }
        
        /// Close the current database manually.
        ///
        /// Optional. If not called, databases automatically close when deallocated.
        ///
        /// This is useful if actions must be taken after the database is definitely closed, such as moving it, deleting it, or instantiating another ``ButtDB/Database`` instance for the same file.
        ///
        /// Sending any queries to a closed database throws an error.
        public func close() async {
            await core.close()
            if let path {
                Self.instanceLock.withLock { Self.pathsOfCurrentInstances.remove(path) }
            }
        }
        
        // MARK: - Forwarded Core functions
        
        public func execute(_ query: String) async throws { try await core.execute(query) }

        public func transaction(_ action: ((_ core: isolated Core) throws -> Void) ) async throws { try await core.transaction(action) }
        
        public func cancellableTransaction(_ action: ((_ core: isolated Core) throws -> Bool) ) async throws { try await core.cancellableTransaction(action) }

        
        @discardableResult public func query(_ query: String) async throws -> [ButtDB.Row] { return try await core.query(query, []) }

        @discardableResult public func query(_ query: String, _ arguments: Any...) async throws -> [ButtDB.Row] { return try await core.query(query, arguments) }

        @discardableResult public func query(_ query: String, arguments: [Any]) async throws -> [ButtDB.Row] { return try await core.query(query, arguments) }

        @discardableResult public func query(_ query: String, arguments: [String: Any]) async throws -> [ButtDB.Row] { return try await core.query(query, arguments) }

        // MARK: - Core

        
        /// An actor for protected concurrent access to a database.
        public actor Core: ButtDBQueryable {
            private var debugPrintEveryQuery = false

            internal var dbHandle: OpaquePointer
            private weak var changeReporter: ChangeReporter?
            private var cachedStatements: [String: OpaquePointer] = [:]
            private var isClosed = false
            private var nextTransactionID: Int64 = 0
        
            internal init(_ dbHandle: OpaquePointer, changeReporter: ChangeReporter, options: Database.Options) {
                self.dbHandle = dbHandle
                self.changeReporter = changeReporter
                self.debugPrintEveryQuery = options.contains(.debugPrintEveryQuery)
            }

            deinit {
                if !isClosed {
                    for (_, statement) in cachedStatements { sqlite3_finalize(statement) }
                    sqlite3_close(dbHandle)
                    isClosed = true
                }
            }
            
            fileprivate func close() {
                if isClosed { return }
                for (_, statement) in cachedStatements { sqlite3_finalize(statement) }
                sqlite3_close(dbHandle)
                isClosed = true
            }

            public func transaction(_ action: ((_ core: isolated ButtDB.Database.Core) throws -> Void) ) throws {
                try cancellableTransaction { core in
                    try action(core)
                    return true
                }
            }

            public func cancellableTransaction(_ action: ((_ core: isolated ButtDB.Database.Core) throws -> Bool) ) throws {
                if isClosed { throw Error.databaseIsClosed }
                let transactionID = nextTransactionID
                nextTransactionID += 1
                changeReporter?.beginTransaction(transactionID)
                defer { changeReporter?.endTransaction(transactionID) }

                try execute("SAVEPOINT \"\(transactionID)\"")
                var commit = false
                do { commit = try action(self) }
                catch {
                    try execute("ROLLBACK TO SAVEPOINT \"\(transactionID)\"")
                    throw error
                }

                if commit { try execute("RELEASE SAVEPOINT \"\(transactionID)\"") }
                else { try execute("ROLLBACK TO SAVEPOINT \"\(transactionID)\"") }
            }
            
            public func execute(_ query: String) throws {
                if debugPrintEveryQuery { print("[ButtDB.Database] \(query)") }
                if isClosed { throw Error.databaseIsClosed }

                let transactionID = nextTransactionID
                nextTransactionID += 1
                changeReporter?.beginTransaction(transactionID)
                defer { changeReporter?.endTransaction(transactionID) }
                
                let result = sqlite3_exec(dbHandle, query, nil, nil, nil)
                if result != SQLITE_OK { throw Error.queryError(query: query, description: errorDesc(dbHandle)) }
            }
            
            nonisolated internal func errorDesc(_ dbHandle: OpaquePointer?, _ query: String? = nil) -> String {
                guard let dbHandle else { return "No SQLite handle" }
                let code = sqlite3_errcode(dbHandle)
                let msg = String(cString: sqlite3_errmsg(dbHandle), encoding: .utf8) ?? "(unknown)"

                if #available(iOS 16, watchOS 9, macOS 13, tvOS 16, *), case let offset = sqlite3_error_offset(dbHandle), offset >= 0 {
                    return "SQLite error code \(code) at index \(offset): \(msg)"
                } else {
                    return "SQLite error code \(code): \(msg)"
                }
            }

            @discardableResult
            public func query(_ query: String) throws -> [ButtDB.Row] { return try self.query(query, []) }

            @discardableResult
            public func query(_ query: String, _ arguments: Any...) throws -> [ButtDB.Row] { return try self.query(query, arguments: arguments) }

            @discardableResult
            public func query(_ query: String, arguments: [Any]) throws -> [ButtDB.Row] {
                if isClosed { throw Error.databaseIsClosed }
                let statement = try preparedStatement(query)
                var idx = 1 // SQLite bind-parameter indexes start at 1, not 0!
                for any in arguments {
                    let value = try Value.fromAny(any)
                    try value.bind(database: self, statement: statement, index: Int32(idx), for: query)
                    idx += 1
                }
                return try rowsByExecutingPreparedStatement(statement, from: query)
            }

            @discardableResult
            public func query(_ query: String, arguments: [String: Any]) throws -> [ButtDB.Row] {
                if isClosed { throw Error.databaseIsClosed }
                let statement = try preparedStatement(query)
                for (name, any) in arguments {
                    let value = try Value.fromAny(any)
                    try value.bind(database: self, statement: statement, name: name, for: query)
                }
                return try rowsByExecutingPreparedStatement(statement, from: query)
            }

            private func preparedStatement(_ query: String) throws -> OpaquePointer {
                if let cached = cachedStatements[query] { return cached }
                var statement: OpaquePointer? = nil
                let result = sqlite3_prepare_v3(dbHandle, query, -1, UInt32(SQLITE_PREPARE_PERSISTENT), &statement, nil)
                guard result == SQLITE_OK, let statement else { throw Error.queryError(query: query, description: errorDesc(dbHandle)) }
                cachedStatements[query] = statement
                return statement
            }
            
            private func rowsByExecutingPreparedStatement(_ statement: OpaquePointer, from query: String) throws -> [ButtDB.Row] {
                if debugPrintEveryQuery { print("[ButtDB.Database] \(query)") }

                let transactionID = nextTransactionID
                nextTransactionID += 1
                changeReporter?.beginTransaction(transactionID)
                defer { changeReporter?.endTransaction(transactionID) }

                var result = sqlite3_step(statement)
                
                guard result == SQLITE_ROW || result == SQLITE_DONE else { throw Error.queryExecutionError(query: query, description: errorDesc(dbHandle)) }

                let columnCount = sqlite3_column_count(statement)
                if columnCount == 0 {
                    guard sqlite3_reset(statement) == SQLITE_OK, sqlite3_clear_bindings(statement) == SQLITE_OK else {
                        throw Error.queryExecutionError(query: query, description: errorDesc(dbHandle))
                    }
                    return []
                }
                
                var columnNames: [String] = []
                for i in 0 ..< columnCount {
                    guard let charPtr = sqlite3_column_name(statement, i), case let name = String(cString: charPtr) else {
                        throw Error.queryExecutionError(query: query, description: errorDesc(dbHandle))
                    }
                    columnNames.append(name)
                }

                var rows: [ButtDB.Row] = []
                while result == SQLITE_ROW {
                    var row: ButtDB.Row = [:]
                    for i in 0 ..< Int(columnCount) {
                        switch sqlite3_column_type(statement, Int32(i)) {
                            case SQLITE_NULL:    row[columnNames[i]] = .null
                            case SQLITE_INTEGER: row[columnNames[i]] = .integer(sqlite3_column_int64(statement, Int32(i)))
                            case SQLITE_FLOAT:   row[columnNames[i]] = .double(sqlite3_column_double(statement, Int32(i)))

                            case SQLITE_TEXT:
                                guard let charPtr = sqlite3_column_text(statement, Int32(i)) else { throw Error.queryResultValueError(query: query, column: columnNames[i]) }
                                row[columnNames[i]] = .text(String(cString: charPtr))
            
                            case SQLITE_BLOB:
                                let byteLength = sqlite3_column_bytes(statement, Int32(i))
                                if byteLength > 0 {
                                    guard let bytes = sqlite3_column_blob(statement, Int32(i)) else { throw Error.queryResultValueError(query: query, column: columnNames[i]) }
                                    row[columnNames[i]] = .data(Data(bytes: bytes, count: Int(byteLength)))
                                } else {
                                    row[columnNames[i]] = .data(Data())
                                }

                            default: throw Error.queryExecutionError(query: query, description: errorDesc(dbHandle))
                        }
                    }
                    rows.append(row)

                    result = sqlite3_step(statement)
                }
                if result != SQLITE_DONE { throw Error.queryExecutionError(query: query, description: errorDesc(dbHandle)) }
                
                guard sqlite3_reset(statement) == SQLITE_OK, sqlite3_clear_bindings(statement) == SQLITE_OK else {
                    throw Error.queryExecutionError(query: query, description: errorDesc(dbHandle))
                }
                return rows
            }
        }
    }

}
