//
//  ButtDBTests.swift
//  Created by Marco Arment on 11/20/22.
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

import XCTest
import Combine
@testable import ButtDB

func AssertNoThrowAsync(_ action: @autoclosure (() async throws -> Void)) async {
    do {
        try await action()
    } catch {
        XCTAssert(false, "Call threw error: \(error)")
    }
}

func AssertThrowsErrorAsync(_ action: @autoclosure (() async throws -> Void)) async {
    do {
        try await action()
        XCTAssert(false, "Call was expected to throw")
    } catch { }
}

final class ButtDBTestTests: XCTestCase {
    enum Error: Swift.Error {
        case testError
    }

    var sqliteFilename = ""

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory.path
        sqliteFilename = "\(dir)/test\(Int64.random(in: 0..<Int64.max)).sqlite"
    }

    override func tearDownWithError() throws {
        if sqliteFilename != "", sqliteFilename != ":memory:", FileManager.default.fileExists(atPath: sqliteFilename) { try FileManager.default.removeItem(atPath: sqliteFilename) }
    }

    // Use XCTAssert and related functions to verify your tests produce the correct results.
    // Any test you write for XCTest can be annotated as throws and async.
    // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
    // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

    func testValueConversions() throws {
        guard let n = ButtDB.Value.fromSQLiteLiteral("NULL") else { throw Error.testError }
        XCTAssert(n == .null)
        XCTAssert(n.intValue == nil)
        XCTAssert(n.doubleValue == nil)
        XCTAssert(n.stringValue == nil)
        XCTAssert(n.dataValue == nil)
        XCTAssert((try ButtDB.Value.fromAny(nil)) == n)
        XCTAssert((try ButtDB.Value.fromAny(NSNull())) == n)

        guard let i = ButtDB.Value.fromSQLiteLiteral("123456") else { throw Error.testError }
        XCTAssert(i == .integer(123456))
        XCTAssert(i.intValue == 123456)
        XCTAssert(i.doubleValue == 123456.0)
        XCTAssert(i.stringValue == "123456")
        XCTAssert(i.dataValue == "123456".data(using: .utf8))
        XCTAssert((try ButtDB.Value.fromAny(123456)) == i)
        XCTAssert((try ButtDB.Value.fromAny(Int(123456))) == i)
        XCTAssert((try ButtDB.Value.fromAny(Int8(123))) == .integer(123))
        XCTAssert((try ButtDB.Value.fromAny(Int16(12345))) == .integer(12345))
        XCTAssert((try ButtDB.Value.fromAny(Int32(123456))) == i)
        XCTAssert((try ButtDB.Value.fromAny(Int64(123456))) == i)
        XCTAssert((try ButtDB.Value.fromAny(UInt(123456))) == i)
        XCTAssert((try ButtDB.Value.fromAny(UInt8(123))) == .integer(123))
        XCTAssert((try ButtDB.Value.fromAny(UInt16(12345))) == .integer(12345))
        XCTAssert((try ButtDB.Value.fromAny(UInt32(123456))) == i)
        XCTAssertThrowsError(try ButtDB.Value.fromAny(UInt64(123456)))
        XCTAssert((try ButtDB.Value.fromAny(false)) == .integer(0))
        XCTAssert((try ButtDB.Value.fromAny(true)) == .integer(1))

        guard let d = ButtDB.Value.fromSQLiteLiteral("123456.789") else { throw Error.testError }
        XCTAssert(d == .double(123456.789))
        XCTAssert(d.intValue == 123456)
        XCTAssert(d.doubleValue == 123456.789)
        XCTAssert(d.stringValue == "123456.789")
        XCTAssert(d.dataValue == "123456.789".data(using: .utf8))
        XCTAssert((try ButtDB.Value.fromAny(123456.789)) == d)
        XCTAssert((try ButtDB.Value.fromAny(Float(123456.789))) == .double(123456.7890625))
        XCTAssert((try ButtDB.Value.fromAny(Double(123456.789))) == d)

        guard let s = ButtDB.Value.fromSQLiteLiteral("'abc\"🌊\"d''éƒ'''") else { throw Error.testError }
        XCTAssert(s == .text("abc\"🌊\"d'éƒ'"))
        XCTAssert(s.intValue == nil)
        XCTAssert(s.doubleValue == nil)
        XCTAssert(s.stringValue == "abc\"🌊\"d'éƒ'")
        XCTAssert(s.dataValue == "abc\"🌊\"d'éƒ'".data(using: .utf8)!)
        XCTAssert((try ButtDB.Value.fromAny("abc\"🌊\"d'éƒ'")) == s)
    
        guard let b = ButtDB.Value.fromSQLiteLiteral("X\'616263F09F8C8A64C3A9C692\'") else { throw Error.testError }
        XCTAssert(b == .data("abc🌊déƒ".data(using: .utf8)!))
        XCTAssert(b.intValue == nil)
        XCTAssert(b.doubleValue == nil)
        XCTAssert(b.stringValue == "abc🌊déƒ")
        XCTAssert(b.dataValue == "abc🌊déƒ".data(using: .utf8))
        XCTAssert((try ButtDB.Value.fromAny("abc🌊déƒ".data(using: .utf8)!)) == b)

        let date = Date()
        XCTAssert((try ButtDB.Value.fromAny(date)) == .double(date.timeIntervalSince1970))
        
        let url = URL(string: "https://www.marco.org/")!
        XCTAssert((try ButtDB.Value.fromAny(url)) == .text(url.absoluteString))
    }

    func testOpenDB() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await TestModel.resolveSchema(in: db)
        try await SchemaChangeAddColumnsInitial.resolveSchema(in: db)
        try await SchemaChangeRebuildTableInitial.resolveSchema(in: db)
        await db.close()
    }
    
    func testQueries() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let count = min(TestData.URLs.count, TestData.titles.count, TestData.descriptions.count)
        
        try await db.transaction { core in
            for i in 0..<count {
                let m = TestModelWithDescription(id: i, url: TestData.URLs[i], title: TestData.titles[i], description: TestData.descriptions[i])
                try m.writeIsolated(to: db, core: core)
            }
        }

        let the = try await TestModelWithDescription.read(from: db, where: "title LIKE 'the%'")
        XCTAssert(the.count == 231)

        let paramFormat1Results = try await TestModelWithDescription.read(from: db, where: "title LIKE ?", "the%")
        XCTAssert(paramFormat1Results.count == 231)

        let paramFormat2Results = try await TestModelWithDescription.read(from: db, where: "title LIKE ?", arguments: ["the%"])
        XCTAssert(paramFormat2Results.count == 231)

        let paramFormat3Results = try await TestModelWithDescription.read(from: db, where: "title LIKE :title", arguments: [":title" : "the%"])
        XCTAssert(paramFormat3Results.count == 231)

        let id42 = try await TestModelWithDescription.read(from: db, id: 42)
        XCTAssertNotNil(id42)
        XCTAssert(id42!.id == 42)
        
        try await id42!.delete(from: db)
        let id42AfterDelete = try await TestModelWithDescription.read(from: db, id: 42)
        XCTAssertNil(id42AfterDelete)
    }

    func testColumnTypes() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await TypeTest.resolveSchema(in: db)
        
        let tt = TypeTest(id: Int64.max, typeIntNull: nil, typeIntNotNull: Int64.min, typeTextNull: nil, typeTextNotNull: "textNotNull!", typeDoubleNull: nil, typeDoubleNotNull: Double.pi, typeDataNull: nil, typeDataNotNull: "dataNotNull!".data(using: .utf8)!)
        try await tt.write(to: db)
        
        let read = try await TypeTest.read(from: db, id: Int64.max)
        XCTAssertNotNil(read)
        XCTAssert(read!.id == Int64.max)
        XCTAssert(read!.typeIntNull == nil)
        XCTAssert(read!.typeIntNotNull == Int64.min)
        XCTAssert(read!.typeTextNull == nil)
        XCTAssert(read!.typeTextNotNull == "textNotNull!")
        XCTAssert(read!.typeDoubleNull == nil)
        XCTAssert(read!.typeDoubleNotNull == Double.pi)
        XCTAssert(read!.typeDataNull == nil)
        XCTAssert(read!.typeDataNotNull == "dataNotNull!".data(using: .utf8)!)
    }

    func testHeavyWorkload() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])

        // big block of writes to populate the DB
        try await db.transaction { core in
            for i in 0..<1000 {
                let t = TestModel(id: Int64(i), title: TestData.randomTitle, url: TestData.randomURL, nonColumn: TestData.randomDescription)
                try t.writeIsolated(to: db, core: core)
            }
        }

        // random reads/writes interleaved
        for _ in 0..<5000 {
            if var r = try await TestModel.read(from: db, id: Int64.random(in: 0..<1000)) {
                r.title = TestData.randomTitle
                try await r.write(to: db)
            }

            let t = TestModel(id: TestData.randomInt64(), title: TestData.randomTitle, url: TestData.randomURL, nonColumn: TestData.randomDescription)
            try await t.write(to: db)
        }

        await db.close()
    }

    func testMemoryDB() async throws {
        sqliteFilename = ":memory:"
        try await testHeavyWorkload()
    }
    
    func testMultiStatements() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await Post.resolveSchema(in: db)
        try await db.execute("PRAGMA user_version = 234; UPDATE Post SET url = NULL")
        let userVersion = try await db.query("PRAGMA user_version").first?["user_version"]
        XCTAssert(userVersion != nil)
        XCTAssert(userVersion!.intValue == 234)
    }

    func testTransactionRollback() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        
        let id = TestData.randomInt64()
        let originalTitle = TestData.randomTitle
        var t = TestModel(id: id, title: originalTitle, url: TestData.randomURL, nonColumn: TestData.randomString(length: 32))
        try await t.write(to: db)

        try await db.cancellableTransaction { core in
            t.title = "new title"
            try t.writeIsolated(to: db, core: core)
            
            let title = try core.query("SELECT title FROM TestModel WHERE id = ?", id).first!["title"]!.stringValue
            XCTAssert(title == "new title")
            
            return false // rollback
        }
        
        let title = try await db.query("SELECT title FROM TestModel WHERE id = ?", id).first!["title"]!.stringValue
        XCTAssert(title == originalTitle)
    }

    func testConcurrentAccessToSameDBFile() async throws {
        let mem1 = try ButtDB.Database.inMemoryDatabase(options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        XCTAssertNoThrow(try _ = ButtDB.Database.inMemoryDatabase())
        try await mem1.execute("PRAGMA user_version = 1") // so mem1 doesn't get deallocated until after this

        let db1 = try ButtDB.Database(path: sqliteFilename)
        XCTAssertThrowsError(try _ = ButtDB.Database(path: sqliteFilename))
        await db1.close()
        XCTAssertNoThrow(try ButtDB.Database(path: sqliteFilename)) // should be OK to reuse a path after .close()
    
        await AssertThrowsErrorAsync(try await db1.execute("PRAGMA user_version = 1")) // so db1 doesn't get deallocated until after this and we test throwing errors for accessing a closed DB
    }

    func testSchemaChangeAddPrimaryKeyColumn() async throws {
        let userID = TestData.randomInt64()
        let feedID = TestData.randomInt64()
        let episodeID = TestData.randomInt64()

        var db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await SchemaChangeAddPrimaryKeyColumnInitial(userID: userID, feedID: feedID, subscribed: true).write(to: db)
        await db.close()
    
        db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let newInstance = SchemaChangeAddPrimaryKeyColumnChanged(userID: userID, feedID: feedID, episodeID: episodeID, subscribed: false)
        try await newInstance.write(to: db)
    
        let firstInstance = try await SchemaChangeAddPrimaryKeyColumnChanged.read(from: db, multicolumnPrimaryKey: [userID, feedID, 0])
        let secondInstance = try await SchemaChangeAddPrimaryKeyColumnChanged.read(from: db, multicolumnPrimaryKey: [userID, feedID, episodeID])
        let thirdInstance = try await SchemaChangeAddPrimaryKeyColumnChanged.read(from: db, multicolumnPrimaryKey: ["userID" : userID, "feedID" : feedID, "episodeID": episodeID])

        XCTAssertNotNil(firstInstance)
        XCTAssertNotNil(secondInstance)
        XCTAssertNotNil(thirdInstance)
        XCTAssert(firstInstance!.episodeID == 0)
        XCTAssert(secondInstance!.episodeID == episodeID)
        XCTAssert(thirdInstance!.episodeID == episodeID)
        XCTAssert(firstInstance!.subscribed == true)
        XCTAssert(secondInstance!.subscribed == false)
        XCTAssert(thirdInstance!.subscribed == false)
    }

    func testSchemaChangeAddColumns() async throws {
        let id = TestData.randomInt64()
        let title = TestData.titles.randomElement()!

        var db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await SchemaChangeAddColumnsInitial(id: id, title: title).write(to: db)
        await db.close()
    
        db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let newInstance = SchemaChangeAddColumnsChanged(id: TestData.randomInt64(not: id), title: TestData.randomTitle, description: "Custom", url: TestData.randomURL, art: TestData.randomData(length: 2048))
        try await newInstance.write(to: db)
    
        let modifiedInstance = try await SchemaChangeAddColumnsChanged.read(from: db, id: id)
        XCTAssertNotNil(modifiedInstance)
        XCTAssert(modifiedInstance!.title == title)

        let readNewInstance = try await SchemaChangeAddColumnsChanged.read(from: db, id: newInstance.id)
        XCTAssertNotNil(readNewInstance)
        XCTAssert(readNewInstance!.description == "Custom")
    }

    func testSchemaChangeDropColumns() async throws {
        let id = TestData.randomInt64()
        let title = TestData.titles.randomElement()!

        var db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await SchemaChangeAddColumnsChanged(id: id, title: title, description: "Custom", url: TestData.randomURL, art: TestData.randomData(length: 2048)).write(to: db)
        await db.close()
    
        db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let newInstance = SchemaChangeAddColumnsInitial(id: TestData.randomInt64(not: id), title: TestData.randomTitle)
        try await newInstance.write(to: db)
    
        let modifiedInstance = try await SchemaChangeAddColumnsInitial.read(from: db, id: id)
        XCTAssertNotNil(modifiedInstance)
        XCTAssert(modifiedInstance!.title == title)
    }

    func testSchemaChangeAddIndex() async throws {
        let id = TestData.randomInt64()
        let title = TestData.titles.randomElement()!

        var db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await SchemaChangeAddIndexInitial(id: id, title: title).write(to: db)
        await db.close()
    
        db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let newInstance = SchemaChangeAddIndexChanged(id: TestData.randomInt64(not: id), title: TestData.randomTitle)
        try await newInstance.write(to: db)
    
        let modifiedInstance = try await SchemaChangeAddIndexChanged.read(from: db, id: id)
        XCTAssertNotNil(modifiedInstance)
        XCTAssert(modifiedInstance!.title == title)
    }

    func testSchemaChangeDropIndex() async throws {
        let id = TestData.randomInt64()
        let title = TestData.titles.randomElement()!

        var db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await SchemaChangeAddIndexChanged(id: id, title: title).write(to: db)
        await db.close()
    
        db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let newInstance = SchemaChangeAddIndexInitial(id: TestData.randomInt64(not: id), title: TestData.randomTitle)
        try await newInstance.write(to: db)
    
        let modifiedInstance = try await SchemaChangeAddIndexInitial.read(from: db, id: id)
        XCTAssertNotNil(modifiedInstance)
        XCTAssert(modifiedInstance!.title == title)
    }

    func testSchemaChangeRebuildTable() async throws {
        let id = TestData.randomInt64()
        let title = TestData.titles.randomElement()!

        var db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        try await SchemaChangeRebuildTableInitial(id: id, title: title, flags: 15).write(to: db)
        await db.close()
    
        db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        let newInstance = SchemaChangeRebuildTableChanged(id: TestData.randomInt64(not: id), title: TestData.randomTitle, flags: "{1,0}", description: TestData.randomDescription)
        try await newInstance.write(to: db)
    
        let modifiedInstance = try await SchemaChangeRebuildTableChanged.read(from: db, id: id)
        XCTAssertNotNil(modifiedInstance)
        XCTAssert(modifiedInstance!.title == title)
        XCTAssert(modifiedInstance!.description == "")
        XCTAssert(modifiedInstance!.flags == "15")
    }
    
    var _testChangeNotificationsExpectedChangedKeys: ButtDB.PrimaryKeyValues?
    var _testChangeNotificationsListeners: [AnyCancellable] = []
    var _testChangeNotificationsCallCount = 0
    func testChangeNotifications() async throws {
        let db = try ButtDB.Database(path: sqliteFilename, options: [.debugPrintEveryQuery, .debugPrintEveryReportedChange])
        
        try await TestModel.resolveSchema(in: db)
        try await TestModelWithDescription.resolveSchema(in: db)
        
        _testChangeNotificationsListeners.append(TestModel.changePublisher(in: db).sink { keys in
            XCTAssert(false, "Change listener called for incorrect table")
        })

        _testChangeNotificationsListeners.append(TestModelWithDescription.changePublisher(in: db).sink { keys in
            XCTAssertEqual(keys, self._testChangeNotificationsExpectedChangedKeys)
            self._testChangeNotificationsCallCount += 1
        })

        // Batched change notifications
        let count = min(TestData.URLs.count, TestData.titles.count, TestData.descriptions.count)
        try await db.transaction { core in
            var expectedBatchedKeys = ButtDB.PrimaryKeyValues()
            for i in 0..<count {
                expectedBatchedKeys.insert(.integer(Int64(i)))
                let m = TestModelWithDescription(id: i, url: TestData.URLs[i], title: TestData.titles[i], description: TestData.descriptions[i])
                try m.writeIsolated(to: db, core: core)
            }
            self._testChangeNotificationsExpectedChangedKeys = expectedBatchedKeys
        }
        await MainActor.run { } // blocks until after the change has been sent to the publisher
        XCTAssert(_testChangeNotificationsCallCount == 1)
        
        // Individual change notifications
        var m = try await TestModelWithDescription.read(from: db, id: 64)!
        m.title = "Edited title!"
        _testChangeNotificationsExpectedChangedKeys = ButtDB.PrimaryKeyValues([ .integer(64) ])
        try await m.write(to: db)
        await MainActor.run { }
        XCTAssert(_testChangeNotificationsCallCount == 2)
        
        // Unspecified/whole-table change notifications
        _testChangeNotificationsExpectedChangedKeys = nil
        try await TestModelWithDescription.query(in: db, "UPDATE $T SET url = NULL")
        await MainActor.run { }
        XCTAssert(_testChangeNotificationsCallCount == 3)
    }
}
