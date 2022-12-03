//
//  ButtDBChanges.swift
//  Created by Marco Arment on 11/17/22.
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

public extension ButtDB {
    /// A Publisher that emits when data in a ButtDB table has changed.
    ///
    /// The ``PrimaryKeyValues`` value passed indicates which rows in the table have changed:
    /// * If the value is non-`nil`, only the rows with the given primary-key values may have changed.
    /// * If the value is `nil`, any rows in the table may have changed.
    ///
    /// ## Example
    /// ```swift
    /// let db = try ButtDB.Database.inMemoryDatabase()
    /// // ...
    ///
    /// let listener = MyModel.changePublisher(in: db).sink { keys in
    ///     print("These primary keys may have changed: \(keys ?? "all")")
    /// }
    /// ```
    ///
    typealias ChangePublisher = PassthroughSubject<PrimaryKeyValues?, Never>

    static let legacyChangeNotification = NSNotification.Name("ButtDBTableChangeNotification")
    static let legacyChangeNotificationTableKey = "ButtDBChangedTable"
    static let legacyChangeNotificationPrimaryKeyValuesKey = "ButtDBChangedPrimaryKeyValues"
}

extension ButtDB.Database {
    internal class ChangeReporter {
        private var lock = ButtDB.Lock()
        private var flushIsEnqueued = false
        private var activeTransactions = Set<Int64>()
        private var ignoreWritesToTableName: String? = nil
        private var accumulatedChangesPerKey: [String: ButtDB.PrimaryKeyValues] = [:]
        private var accumulatedChangesForEntireTables = Set<String>()
        private var tableChangePublishers: [String: ButtDB.ChangePublisher] = [:]
        
        private var sendLegacyChangeNotifications = false
        private var debugPrintEveryReportedChange = false
        
        init(options: Options) {
            debugPrintEveryReportedChange = options.contains(.debugPrintEveryReportedChange)
            sendLegacyChangeNotifications = options.contains(.sendLegacyChangeNotifications)
        }

        public func changePublisher(for tableName: String) -> ButtDB.ChangePublisher {
            lock.withLock {
                if let existing = tableChangePublishers[tableName] { return existing }
                let publisher = ButtDB.ChangePublisher()
                tableChangePublishers[tableName] = publisher
                return publisher
            }
        }

        public func ignoreWritesToTable(_ name: String) {
            lock.lock()
            ignoreWritesToTableName = name
            lock.unlock()
        }

        public func stopIgnoringWrites() {
            lock.lock()
            ignoreWritesToTableName = nil
            lock.unlock()
        }

        public func beginTransaction(_ transactionID: Int64) {
            lock.lock()
            activeTransactions.insert(transactionID)
            lock.unlock()
        }

        public func endTransaction(_ transactionID: Int64) {
            lock.lock()
            activeTransactions.remove(transactionID)
            if !flushIsEnqueued && activeTransactions.isEmpty && (!accumulatedChangesPerKey.isEmpty || !accumulatedChangesForEntireTables.isEmpty) {
                flushIsEnqueued = true
                DispatchQueue.main.async { [weak self] in self?.flush() }
            }
            lock.unlock()
        }

        public func reportChange(tableName: String, primaryKey: ButtDB.Value? = nil) {
            lock.lock()
            if tableName != ignoreWritesToTableName {
                if let primaryKey {
                    if accumulatedChangesPerKey[tableName] == nil { accumulatedChangesPerKey[tableName] = ButtDB.PrimaryKeyValues() }
                    accumulatedChangesPerKey[tableName]!.insert(primaryKey)
                } else {
                    accumulatedChangesForEntireTables.insert(tableName)
                }

                if !flushIsEnqueued, activeTransactions.isEmpty {
                    flushIsEnqueued = true
                    DispatchQueue.main.async { [weak self] in self?.flush() }
                }
            }
            lock.unlock()
        }
        
        private func flush() {
            lock.lock()
            flushIsEnqueued = false
            let publishers = tableChangePublishers
            let byEntireTable = accumulatedChangesForEntireTables
            var byTableAndKeys = accumulatedChangesPerKey
            accumulatedChangesPerKey.removeAll()
            accumulatedChangesForEntireTables.removeAll()
            lock.unlock()

            for tableName in byEntireTable {
                if debugPrintEveryReportedChange { print("[ButtDB.ChangeReporter] changed \(tableName) (all/unknown)") }
                byTableAndKeys.removeValue(forKey: tableName)
                if let publisher = publishers[tableName] { publisher.send(nil) }
                if sendLegacyChangeNotifications { sendLegacyNotification(tableName: tableName, changedKeys: nil) }
            }
            
            for (tableName, keys) in byTableAndKeys {
                if debugPrintEveryReportedChange { print("[ButtDB.ChangeReporter] changed \(tableName) (\(keys.count) keys)") }
                if let publisher = publishers[tableName] { publisher.send(keys) }
                if sendLegacyChangeNotifications { sendLegacyNotification(tableName: tableName, changedKeys: keys) }
            }
        }
        
        private func sendLegacyNotification(tableName: String, changedKeys: ButtDB.PrimaryKeyValues?) {
            var userInfo: [AnyHashable: Any] = [ButtDB.legacyChangeNotificationTableKey: tableName]
            if let changedKeys { userInfo[ButtDB.legacyChangeNotificationPrimaryKeyValuesKey] = changedKeys.map { $0.objcValue() } }
            NotificationCenter.default.post(name: ButtDB.legacyChangeNotification, object: tableName, userInfo: userInfo)
        }
    }
}
