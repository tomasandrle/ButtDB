//
//  ButtDBModel.swift
//  Created by Marco Arment on 11/8/22.
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
import Combine

/// A model protocol based on `Codable` and SQLite.
///
/// ## Defining the schema
/// Types that conform to `ButtDBModel` must define a ``ButtDB/Table`` with database columns, indexes, and a primary key.
///
/// **Example:** A simple model:
/// ```swift
/// struct Post: ButtDBModel {
///     static var table = ButtDB.Table(
///         columns: [
///             ButtDB.Column(name: "id",    type: .integer),
///             ButtDB.Column(name: "title", type: .text),
///             ButtDB.Column(name: "url",   type: .text, mayBeNull: true),
///         ]
///     )
///
///     let id: Int
///     var title: String
///     var url: URL?     // optional since mayBeNull == true
/// }
/// ```
/// > If the primary key is not specified, it is assumed to be a column named `"id"`.
///
/// If a table with the same name already exists in a database, a schema migration will be attempted for the following operations:
/// * Adding or dropping columns
/// * Adding or dropping indexes
/// * Changing column type or nullability
/// * Changing the primary key
/// If the migration fails, an error will be thrown.
///
/// Schema migrations are performed when the first `ButtDBModel` database operation is performed for a given table.
/// To perform any necessary migrations in advance, you may optionally call ``resolveSchema(in:)-89xpw``.
///
/// ## Reading and writing
/// Most reads and writes are performed asynchronously:
/// ```swift
/// let db = try ButtDB.Database(path: "/tmp/test.sqlite")
///
/// // Write a new instance to the database
/// let post = Post(id: 1, title: "What I had for breakfast")
/// try await post.write(to: db)
///
/// // Fetch an existing instance by primary key
/// let anotherPost = try await Post.read(from: db, id: 2)
///
/// // Or with a WHERE query, parameterized with SQLite data types
/// let theSportsPost = try await Post.read(from: db, where: "title = ?", "Sports")
///
/// // Modify an instance and re-save it to the database
/// if let firstPost = try await Post.read(from: db, id: 1) {
///    var modifiedPost = firstPost
///    modifiedPost.title = "New title"
///    try await modifiedPost.write(to db)
/// }
///
/// // Or use an SQL query to modify the database directly
/// try await Post.query("UPDATE $T SET title = ? WHERE id = ?", "New title", 1)
/// ```
///
/// Synchronous access is provided in ``ButtDB/Database/transaction(_:)``.
///
/// ## Change notifications
/// When a table is modified, its ``ButtDB/ChangePublisher`` emits with the affected primary-key values:
/// * If the specific affected rows are known, their primary-key values are emitted.
/// * If an unknown set of rows or the entire table are affected, `nil` is emitted.
///
/// ```swift
/// let listener = Post.changePublisher(in: db).sink { changedPrimaryKeys in
///     print("Post IDs changed: \(changedPrimaryKeys ?? "all of them")")
/// }
/// ```
///
/// ## Unsupported SQLite features
///
/// `ButtDBModel` assumes simple and straightforward SQLite usage.
///
/// Features such as foreign keys, virtual tables, views, autoincrement, partial or expression indexes, attached databases, etc.
/// are unsupported and untested.
///
/// While ``ButtDB/Database`` should work with a more broad set of SQL and SQLite features,
/// `ButtDBModel` should not be used with tables or queries involving them,
/// and their use may cause some features not to behave as expected.
///
public protocol ButtDBModel: Codable, Equatable, Identifiable {
    /// Defines the database schema for models of this type.
    static var table: ButtDB.Table { get }
    
    /// Performs setup and any necessary schema migrations.
    ///
    /// Optional. If not called manually, setup and schema migrations will occur when the first database operation is performed for the conforming type's table.
    ///
    /// If the database migration fails, an error will be thrown.
    ///
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to resolve the schema in.
    static func resolveSchema(in database: ButtDB.Database) async throws

    /// Reads a single instance with the given primary-key value from a database.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - primaryKey: The value of the primary-key column.
    /// - Returns: The decoded instance in the table with the given primary key, or `nil` if a corresponding instance doesn't exist in the table.
    ///
    /// This method is only for tables with single-column primary keys.
    ///
    /// For tables with multi-column primary keys, use ``read(from:multicolumnPrimaryKey:)-4jvke``.
    ///
    /// For tables with a single-column primary key named `id`, ``read(from:id:)-ii0w`` is more concise.
    static func read(from database: ButtDB.Database, primaryKey: Any) async throws -> Self?

    /// Reads a single instance with the given primary key values from a database.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - multicolumnPrimaryKey: The array of values of the primary-key columns. Must match the number and order of primary-key values defined in the model's table.
    /// - Returns: The decoded instance in the table with the given primary key, or `nil` if a corresponding instance doesn't exist in the table.
    ///
    /// For tables with single-column primary keys, ``read(from:primaryKey:)-3p0bv`` is more concise.
    static func read(from database: ButtDB.Database, multicolumnPrimaryKey: [Any]) async throws -> Self?

    /// Reads a single instance with the given primary key values from a database.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - multicolumnPrimaryKey: A dictionary of column names and values of the primary-key columns. Must match the number of primary-key values defined in the model's table.
    /// - Returns: The decoded instance in the table with the given primary key, or `nil` if a corresponding instance doesn't exist in the table.
    ///
    /// For tables with single-column primary keys, ``read(from:primaryKey:)-3p0bv`` is more concise.
    static func read(from database: ButtDB.Database, multicolumnPrimaryKey: [String: Any]) async throws -> Self?
    
    /// Reads a single instance with the given primary-key value from a database if the primary key is a single column named `id`.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - id: The value of the `id` column.
    /// - Returns: The decoded instance in the table with the given `id`, or `nil` if a corresponding instance doesn't exist in the table.
    ///
    /// For tables with other primary-key names, see ``read(from:primaryKey:)-3p0bv`` and ``read(from:multicolumnPrimaryKey:)-4jvke``.
    static func read(from database: ButtDB.Database, id: Any) async throws -> Self?

    /// Reads instances from a database using an optional list of arguments.
    ///
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - queryAfterWhere: The portion of the desired SQL query after the `WHERE` keyword. May contain placeholders specified as a question mark (`?`).
    ///   - arguments: Values corresponding to any placeholders in the query.
    /// - Returns: An array of decoded instances matching the query.
    ///
    /// ## Example
    /// ```swift
    /// let posts = try await Post.read(
    ///     from: db,
    ///     where: "state = ? OR title = ? ORDER BY time DESC",
    ///     arguments: [1 /* state */, "Test Title" /* title *]
    /// )
    /// ```
    static func read(from database: ButtDB.Database, where queryAfterWhere: String, _ arguments: Any...) async throws -> [Self]

    /// Reads instances from a database using an array of arguments.
    ///
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - queryAfterWhere: The portion of the desired SQL query after the `WHERE` keyword. May contain placeholders specified as a question mark (`?`).
    ///   - arguments: An array of values corresponding to any placeholders in the query.
    /// - Returns: An array of decoded instances matching the query.
    ///
    /// ## Example
    /// ```swift
    /// let posts = try await Post.read(
    ///     from: db,
    ///     where: "state = ? OR title = ? ORDER BY time DESC",
    ///     arguments: [1 /* state */, "Test Title" /* title *]
    /// )
    /// ```
    static func read(from database: ButtDB.Database, where queryAfterWhere: String, arguments: [Any]) async throws -> [Self]

    /// Reads instances from a database using a dictionary of named arguments.
    ///
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to read from.
    ///   - queryAfterWhere: The portion of the desired SQL query after the `WHERE` keyword. May contain named placeholders prefixed by a colon (`:`), at-sign (`@`), or dollar sign (`$`) as described in the [SQLite documentation](https://www.sqlite.org/c3ref/bind_blob.html).
    ///   - arguments: A dictionary of placeholder names used in the query and their corresponding values. Names must include the prefix character used.
    /// - Returns: An array of decoded instances matching the query.
    ///
    /// ## Example
    /// ```swift
    /// let posts = try await Post.read(
    ///     from: db,
    ///     where: "state = :state OR title = :title ORDER BY time DESC",
    ///     arguments: [":state": 1, ":title": "Test Title"]
    /// )
    /// ```
    static func read(from database: ButtDB.Database, where queryAfterWhere: String, arguments: [String: Any]) async throws -> [Self]

    /// Write this instance to a database.
    /// - Parameter database: The ``ButtDB/Database`` instance to write to.
    func write(to database: ButtDB.Database) async throws
    
    /// Write this instance to a database synchronously from an actor-isolated transaction.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to write to.
    ///   - core: The isolated ``ButtDB/Database/Core`` provided to the transaction.
    ///
    /// For use only when the database actor is isolated within calls to ``ButtDB/Database/transaction(_:)`` or ``ButtDB/Database/cancellableTransaction(_:)``.
    func writeIsolated(to database: ButtDB.Database, core: isolated ButtDB.Database.Core) throws

    /// Delete this instance from a database.
    /// - Parameter database: The ``ButtDB/Database`` instance to delete from.
    func delete(from database: ButtDB.Database) async throws
    
    /// Delete this instance from a database synchronously from an actor-isolated transaction.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to delete from.
    ///   - core: The isolated ``ButtDB/Database/Core`` provided to the transaction.
    ///
    /// For use only when the database actor is isolated within calls to ``ButtDB/Database/transaction(_:)`` or ``ButtDB/Database/cancellableTransaction(_:)``.
    func deleteIsolated(from database: ButtDB.Database, core: isolated ButtDB.Database.Core) throws

    // -- Arbitrary queries -- (use of "$T" placeholder in query will be replaced with the table name, e.g. "SELECT id FROM $T")
    
    
    /// Executes arbitrary SQL with a placeholder available for this type's table name.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to query.
    ///   - query: The SQL statement to execute, optionally containing:
    ///       - A `$T` placeholder which will be replaced with this type's table name.
    ///       - Question-mark placeholders (`?`) for any argument values to be passed to the query.
    ///   - arguments: Values corresponding to any placeholders in the query.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    @discardableResult static func query(in database: ButtDB.Database, _ query: String, _ arguments: Any...) async throws -> [ButtDB.Row]
    
    /// Executes arbitrary SQL with a placeholder available for this type's table name.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to query.
    ///   - query: The SQL statement to execute, optionally containing:
    ///       - A `$T` placeholder which will be replaced with this type's table name.
    ///       - Question-mark placeholders (`?`) for any argument values to be passed to the query.
    ///   - arguments: An array of values corresponding to any placeholders in the query.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    @discardableResult static func query(in database: ButtDB.Database, _ query: String, arguments: [Any]) async throws -> [ButtDB.Row]

    /// Executes arbitrary SQL with a placeholder available for this type's table name.
    /// - Parameters:
    ///   - database: The ``ButtDB/Database`` instance to query.
    ///   - query: The SQL statement to execute, optionally containing:
    ///       - A `$T` placeholder which will be replaced with this type's table name.
    ///       - Named placeholders prefixed by a colon (`:`), at-sign (`@`), or dollar sign (`$`) as described in the [SQLite documentation](https://www.sqlite.org/c3ref/bind_blob.html).
    ///   - arguments: A dictionary of placeholder names used in the query and their corresponding values. Names must include the prefix character used.
    /// - Returns: An array of rows matching the query if applicable, or an empty array otherwise.
    @discardableResult static func query(in database: ButtDB.Database, _ query: String, arguments: [String: Any]) async throws -> [ButtDB.Row]
    
    // -- Listening for changes --
    
    /// The change publisher for this model's table.
    /// - Parameter database: The ``ButtDB/Database`` instance to monitor.
    /// - Returns: The ``ButtDB/ChangePublisher`` for this model's table.
    static func changePublisher(in database: ButtDB.Database) -> ButtDB.ChangePublisher
}

extension ButtDBModel {
    public static func changePublisher(in database: ButtDB.Database) -> ButtDB.ChangePublisher { database.changeReporter.changePublisher(for: self.table.name(type: self)) }
    
    public static func read(from database: ButtDB.Database, id: Any) async throws -> Self? { return try await self.read(from: database, where: "id = ?", id).first }

    public static func read(from database: ButtDB.Database, primaryKey: Any) async throws -> Self? { return try await self.read(from: database, multicolumnPrimaryKey: [primaryKey]) }

    public static func read(from database: ButtDB.Database, multicolumnPrimaryKey: [Any]) async throws -> Self? {
        if multicolumnPrimaryKey.count != table.primaryKeys.count {
            fatalError("Incorrect number of primary-key values provided (\(multicolumnPrimaryKey.count), need \(table.primaryKeys.count)) for table \(table.name(type: self))")
        }
        return try await self.read(from: database, where: table.primaryKeys.map { "`\($0.name)` = ?" }.joined(separator: " AND "), multicolumnPrimaryKey).first
    }

    public static func read(from database: ButtDB.Database, multicolumnPrimaryKey: [String: Any]) async throws -> Self? {
        if multicolumnPrimaryKey.count != table.primaryKeys.count {
            fatalError("Incorrect number of primary-key values provided (\(multicolumnPrimaryKey.count), need \(table.primaryKeys.count)) for table \(table.name(type: self))")
        }
        
        var andClauses: [String] = []
        var values: [Any] = []
        for (name, value) in multicolumnPrimaryKey {
            andClauses.append("`\(name)` = ?")
            values.append(value)
        }
        
        return try await self.read(from: database, where: andClauses.joined(separator: " AND "), arguments: values).first
    }

    public static func read(from database: ButtDB.Database, where queryAfterWhere: String, _ arguments: Any...) async throws -> [Self] {
        return try await self.read(from: database, where: queryAfterWhere, arguments: arguments)
    }

    public static func read(from database: ButtDB.Database, where queryAfterWhere: String, arguments: [Any]) async throws -> [Self] {
        return try await query(in: database, "SELECT * FROM $T WHERE \(queryAfterWhere)", arguments: arguments).map {
            let decoder = ButtDBSQLiteDecoder($0)
            return try Self(from: decoder)
        }
    }

    public static func read(from database: ButtDB.Database, where queryAfterWhere: String, arguments: [String: Any]) async throws -> [Self] {
        return try await query(in: database, "SELECT * FROM $T WHERE \(queryAfterWhere)", arguments: arguments).map {
            let decoder = ButtDBSQLiteDecoder($0)
            return try Self(from: decoder)
        }
    }

    @discardableResult
    public static func query(in database: ButtDB.Database, _ query: String, _ arguments: Any...) async throws -> [ButtDB.Row] {
        return try await self.query(in: database, query, arguments: arguments)
    }

    @discardableResult
    public static func query(in database: ButtDB.Database, _ query: String, arguments: [Any]) async throws -> [ButtDB.Row] {
        try await table.resolveWithDatabase(type: Self.self, database: database, core: database.core) { try validateSchema() }
        return try await database.core.query(query.replacingOccurrences(of: "$T", with: table.name(type: Self.self)), arguments: arguments)
    }

    @discardableResult
    public static func query(in database: ButtDB.Database, _ query: String, arguments: [String: Any]) async throws -> [ButtDB.Row] {
        try await table.resolveWithDatabase(type: Self.self, database: database, core: database.core) { try validateSchema() }
        return try await database.core.query(query.replacingOccurrences(of: "$T", with: table.name(type: Self.self)), arguments: arguments)
    }

    private static func validateSchema() throws -> Void {
        var testRow = ButtDB.Row()
        for column in table.columns { testRow[column.name] = column.mayBeNull ? .null : column.type.defaultValue() }
        let decoder = ButtDBSQLiteDecoder(testRow)
        do {
            _ = try Self(from: decoder)
        } catch {
            fatalError("Table \"\(table.name(type: self))\" definition defaults do not decode to model \(String(describing: self)): \(error)")
        }
    }
    
    public static func resolveSchema(in database: ButtDB.Database) async throws {
        try await table.resolveWithDatabase(type: Self.self, database: database, core: database.core) { try validateSchema() }
    }
    
    private func insertQueryValues() throws -> (sql: String, values: [Any], primaryKeyValue: ButtDB.Value?) {
        let encoder = ButtDBSQLiteEncoder()
        try self.encode(to: encoder)

        var columnNames: [String] = []
        var placeholders: [String] = []
        var values: [ButtDB.Value] = []
        var primaryKeyValue: ButtDB.Value? = nil
        let primaryKeyColumnName = Self.table.primaryKeys.first?.name ?? ""
        for (key, value) in encoder.sqliteArguments().filter({ Self.table.columnNames.contains($0.key) }) {
            columnNames.append(key)
            placeholders.append("?")
            values.append(value)
            if key == primaryKeyColumnName { primaryKeyValue = try ButtDB.Value.fromAny(value) }
        }
        
        let sql = "REPLACE INTO `\(Self.table.name(type: Self.self))` (`\(columnNames.joined(separator: "`,`"))`) VALUES (\(placeholders.joined(separator: ",")))"
        return (sql: sql, values: values, primaryKeyValue: primaryKeyValue)
    }
    
    public func write(to database: ButtDB.Database) async throws {
        try await writeIsolated(to: database, core: database.core)
    }
    
    public func writeIsolated(to database: ButtDB.Database, core: isolated ButtDB.Database.Core) throws {
        if database.options.contains(.readOnly) { fatalError("Cannot write ButtDBModel to a read-only database") }
        try Self.table.resolveWithDatabaseIsolated(type: Self.self, database: database, core: core) { try Self.validateSchema() }

        let (sql, values, primaryKeyValue) = try insertQueryValues()
        database.changeReporter.ignoreWritesToTable(Self.table.name(type: Self.self))
        defer {
            database.changeReporter.stopIgnoringWrites()
            database.changeReporter.reportChange(tableName: Self.table.name(type: Self.self), primaryKey: primaryKeyValue)
        }
        try core.query(sql, arguments: values)
    }

    public func delete(from database: ButtDB.Database) async throws {
        try await deleteIsolated(from: database, core: database.core)
    }

    public func deleteIsolated(from database: ButtDB.Database, core: isolated ButtDB.Database.Core) throws {
        if database.options.contains(.readOnly) { fatalError("Cannot delete ButtDBModel from a read-only database") }
        let table = Self.table
        try table.resolveWithDatabaseIsolated(type: Self.self, database: database, core: core) { try Self.validateSchema() }

        let encoder = ButtDBSQLiteEncoder()
        try self.encode(to: encoder)
        let sqliteColumnValues = encoder.sqliteArguments()

        var andClauses: [String] = []
        var values: [ButtDB.Value] = []
        for column in table.primaryKeys {
            andClauses.append("`\(column.name)` = ?")
            let value = sqliteColumnValues[column.name]!
            values.append(value)
        }
        
        database.changeReporter.ignoreWritesToTable(Self.table.name(type: Self.self))
        defer {
            database.changeReporter.stopIgnoringWrites()
            database.changeReporter.reportChange(tableName: Self.table.name(type: Self.self), primaryKey: values.count == 1 ? values.first! : nil)
        }
        let sql = "DELETE FROM `\(table.name(type: Self.self))` WHERE \(andClauses.joined(separator: " AND "))"
        try core.query(sql, arguments: values)
    }

}
