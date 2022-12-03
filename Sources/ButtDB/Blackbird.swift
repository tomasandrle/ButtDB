//
//  ButtDB.swift
//  Created by Marco Arment on 11/6/22.
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

/// A small, fast, lightweight SQLite database wrapper and model layer.
public class ButtDB {
    public typealias Row = Dictionary<String, ButtDB.Value>
    public typealias Arguments = Dictionary<String, ButtDB.Value>
    public typealias PrimaryKeyValues = Set<ButtDB.Value>

    /// A wrapper for SQLite's column data types.
    public enum Value: ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, Hashable {
        case null
        case integer(Int64)
        case double(Double)
        case text(String)
        case data(Data)

        public enum Error: Swift.Error {
            case cannotConvertToValue(Any)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(sqliteLiteral())
        }
        
        public static func fromAny(_ value: Any?) throws -> Value {
            guard let value else { return .null }
            switch value {
                case let v as Value:  return v
                case _ as NSNull:     return .null
                case let v as Bool:   return .integer(Int64(v ? 1 : 0))
                case let v as Int:    return .integer(Int64(v))
                case let v as Int8:   return .integer(Int64(v))
                case let v as Int16:  return .integer(Int64(v))
                case let v as Int32:  return .integer(Int64(v))
                case let v as Int64:  return .integer(v)
                case let v as UInt:   return .integer(Int64(v))
                case let v as UInt8:  return .integer(Int64(v))
                case let v as UInt16: return .integer(Int64(v))
                case let v as UInt32: return .integer(Int64(v))
                case let v as Double: return .double(v)
                case let v as Float:  return .double(Double(v))
                case let v as String: return .text(v)
                case let v as any StringProtocol: return .text(String(v))
                case let v as Data:   return .data(v)
                case let v as Date:   return .double(v.timeIntervalSince1970)
                case let v as URL:    return .text(v.absoluteString)

                default: throw Error.cannotConvertToValue(value)
            }
        }

        public init(stringLiteral value: String) { self = .text(value) }
        public init(floatLiteral value: Double)  { self = .double(value) }
        public init(integerLiteral value: Int64) { self = .integer(value) }
        public init(booleanLiteral value: Bool)  { self = .integer(value ? 1 : 0) }
        
        public func sqliteLiteral() -> String {
            switch self {
                case let .integer(i): return String(i)
                case let .double(d):  return String(d)
                case let .text(s):    return "'\(s.replacingOccurrences(of: "'", with: "''"))'"
                case let .data(b):    return "X'\(b.map { String(format: "%02hhX", $0) }.joined())'"
                case .null:           return "NULL"
            }
        }
        
        public static func fromSQLiteLiteral(_ literalString: String) -> Self? {
            if literalString == "NULL" { return .null }
            
            if literalString.hasPrefix("'"), literalString.hasSuffix("'") {
                let start = literalString.index(literalString.startIndex, offsetBy: 1)
                let end = literalString.index(literalString.endIndex, offsetBy: -1)
                return .text(literalString[start..<end].replacingOccurrences(of: "''", with: "'"))
            }

            if literalString.hasPrefix("X'"), literalString.hasSuffix("'") {
                let start = literalString.index(literalString.startIndex, offsetBy: 2)
                let end = literalString.index(literalString.endIndex, offsetBy: -1)
                let hex = literalString[start..<end].replacingOccurrences(of: "''", with: "'")
                
                let hexChars = hex.map { $0 }
                let hexPairs = stride(from: 0, to: hexChars.count, by: 2).map { String(hexChars[$0]) + String(hexChars[$0 + 1]) }
                let bytes = hexPairs.compactMap { UInt8($0, radix: 16) }
                return .data(Data(bytes))
            }
            
            if let i = Int64(literalString) { return .integer(i) }
            if let d = Double(literalString) { return .double(d) }
            return nil
        }

        public var boolValue: Bool? {
            switch self {
                case .null:           return nil
                case let .integer(i): return i > 0
                case let .double(d):  return d > 0
                case let .text(s):    return (Int(s) ?? 0) != 0
                case let .data(b):    if let str = String(data: b, encoding: .utf8), let i = Int(str) { return i != 0 } else { return nil }
            }
        }

        public var dataValue: Data? {
            switch self {
                case .null:           return nil;
                case let .data(b):    return b
                case let .integer(i): return String(i).data(using: .utf8)
                case let .double(d):  return String(d).data(using: .utf8)
                case let .text(s):    return s.data(using: .utf8)
            }
        }

        public var doubleValue: Double? {
            switch self {
                case .null:           return nil;
                case let .double(d):  return d
                case let .integer(i): return Double(i)
                case let .text(s):    return Double(s)
                case let .data(b):    if let str = String(data: b, encoding: .utf8) { return Double(str) } else { return nil }
            }
        }

        public var intValue: Int? {
            switch self {
                case .null:           return nil;
                case let .integer(i): return Int(i)
                case let .double(d):  return Int(d)
                case let .text(s):    return Int(s)
                case let .data(b):    if let str = String(data: b, encoding: .utf8) { return Int(str) } else { return nil }
            }
        }

        public var int64Value: Int64? {
            switch self {
                case .null:           return nil;
                case let .integer(i): return Int64(i)
                case let .double(d):  return Int64(d)
                case let .text(s):    return Int64(s)
                case let .data(b):    if let str = String(data: b, encoding: .utf8) { return Int64(str) } else { return nil }
            }
        }

        public var stringValue: String? {
            switch self {
                case .null:           return nil;
                case let .text(s):    return s
                case let .integer(i): return String(i)
                case let .double(d):  return String(d)
                case let .data(b):    return String(data: b, encoding: .utf8)
            }
        }
        
        private static let copyValue = unsafeBitCast(-1, to: sqlite3_destructor_type.self) // a.k.a. SQLITE_TRANSIENT
        
        internal func bind(database: isolated ButtDB.Database.Core, statement: OpaquePointer, index: Int32, for query: String) throws {
            var result: Int32
            switch self {
                case     .null:       result = sqlite3_bind_null(statement, index)
                case let .integer(i): result = sqlite3_bind_int64(statement, index, i)
                case let .double(d):  result = sqlite3_bind_double(statement, index, d)
                case let .text(s):    result = sqlite3_bind_text(statement, index, s, -1, ButtDB.Value.copyValue)
                case let .data(d):    result = d.withUnsafeBytes { bytes in sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), ButtDB.Value.copyValue) }
            }
            if result != SQLITE_OK { throw ButtDB.Database.Error.queryArgumentValueError(query: query, description: database.errorDesc(database.dbHandle)) }
        }
        
        internal func bind(database: isolated ButtDB.Database.Core, statement: OpaquePointer, name: String, for query: String) throws {
            let idx = sqlite3_bind_parameter_index(statement, name)
            if idx == 0 { throw ButtDB.Database.Error.queryArgumentNameError(query: query, name: name) }
            return try bind(database: database, statement: statement, index: idx, for: query)
        }
    }
}

// MARK: - Utilities

internal protocol ButtDBLock {
    func lock()
    func unlock()
    @discardableResult func withLock<R>(_ body: () throws -> R) rethrows -> R where R : Sendable
}
extension ButtDBLock {
    @discardableResult internal func withLock<R>(_ body: () throws -> R) rethrows -> R where R : Sendable {
        lock()
        defer { unlock() }
        return try body()
    }
}

import os
extension ButtDB {
    internal static func Lock() -> ButtDBLock {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return UnfairLock()
        } else {
            return LegacyUnfairLock()
        }
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    fileprivate class UnfairLock: ButtDBLock {
        private let _lock = OSAllocatedUnfairLock()
        internal func lock() { _lock.lock() }
        internal func unlock() { _lock.unlock() }
    }

    fileprivate class LegacyUnfairLock: ButtDBLock {
        private var _lock: UnsafeMutablePointer<os_unfair_lock>
        internal func lock()   { os_unfair_lock_lock(_lock) }
        internal func unlock() { os_unfair_lock_unlock(_lock) }

        internal init() {
            _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
            _lock.initialize(to: os_unfair_lock())
        }
        deinit { _lock.deallocate() }
    }
}

