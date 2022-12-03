//
//  ButtDBTestModels.swift
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

import Foundation
@testable import ButtDB

struct TestModel: ButtDBModel {
    static var table = ButtDB.Table(
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
            ButtDB.Column(name: "url",   type: .text),
            ButtDB.Column(name: "meta",  type: .text),
        ],
        indexes: [
            ButtDB.Index(columnNames: ["title"]),
        ]
    )

    let id: Int64
    var title: String
    var url: URL
    
    var nonColumn: String = ""
    
    init(id: Int64, title: String, url: URL, nonColumn: String) {
        self.id = id
        self.title = title
        self.url = url
        self.nonColumn = nonColumn
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int64.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(URL.self, forKey: .url)
    }
}

struct TestModelWithoutIDColumn: ButtDBModel {
    static var table = ButtDB.Table(
        columns: [
            ButtDB.Column(name: "pk",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
        ], primaryKeyColumnNames: [
            "pk",
        ]
    )

    var id: Int { pk }
    var pk: Int
    var title: String
}

struct TestModelWithDescription: ButtDBModel {
    static var table = ButtDB.Table(
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "url",   type: .text, mayBeNull: true),
            ButtDB.Column(name: "title", type: .text),
            ButtDB.Column(name: "description",  type: .text),
        ],
        indexes: [
            ButtDB.Index(columnNames: ["title"]),
            ButtDB.Index(columnNames: ["url"]),
        ]
    )

    let id: Int
    var url: URL?
    var title: String
    var description: String
}

struct Post: ButtDBModel {
    static var table = ButtDB.Table(
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
            ButtDB.Column(name: "url",   type: .text, mayBeNull: true),
            ButtDB.Column(name: "image", type: .data, mayBeNull: true),
        ]
    )

    let id: Int
    var title: String
    var url: URL?
    var image: Data?
}

struct TypeTest: ButtDBModel {
    static var table = ButtDB.Table(
        columns: [
            ButtDB.Column(name: "id", type: .integer),

            ButtDB.Column(name: "typeIntNull", type: .integer, mayBeNull: true),
            ButtDB.Column(name: "typeIntNotNull", type: .integer, mayBeNull: false),

            ButtDB.Column(name: "typeTextNull", type: .text, mayBeNull: true),
            ButtDB.Column(name: "typeTextNotNull", type: .text, mayBeNull: false),

            ButtDB.Column(name: "typeDoubleNull", type: .double, mayBeNull: true),
            ButtDB.Column(name: "typeDoubleNotNull", type: .double, mayBeNull: false),

            ButtDB.Column(name: "typeDataNull", type: .data, mayBeNull: true),
            ButtDB.Column(name: "typeDataNotNull", type: .data, mayBeNull: false),
        ]
    )

    let id: Int64
    
    let typeIntNull: Int64?
    let typeIntNotNull: Int64

    let typeTextNull: String?
    let typeTextNotNull: String

    let typeDoubleNull: Double?
    let typeDoubleNotNull: Double

    let typeDataNull: Data?
    let typeDataNotNull: Data
}

struct MulticolumnPrimaryKeyTest: ButtDBModel {
    static var table = ButtDB.Table(
        columns: [
            ButtDB.Column(name: "userID", type: .integer),
            ButtDB.Column(name: "feedID", type: .integer),
            ButtDB.Column(name: "episodeID", type: .integer),
            
            ButtDB.Column(name: "completed", type: .integer),
            ButtDB.Column(name: "deleted", type: .integer),
            ButtDB.Column(name: "progress", type: .integer),
        ],
        primaryKeyColumnNames: ["userID", "feedID", "episodeID"]
    )
    
    var id: String { get { "\(userID)-\(feedID)-\(episodeID)" } }

    let userID: Int64
    let feedID: Int64
    let episodeID: Int64
}

// MARK: - Schema change: Add primary-key column

struct SchemaChangeAddPrimaryKeyColumnInitial: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeAddPrimaryKeyColumn",
        columns: [
            ButtDB.Column(name: "userID", type: .integer),
            ButtDB.Column(name: "feedID", type: .integer),
            ButtDB.Column(name: "subscribed", type: .integer),
        ],
        primaryKeyColumnNames: ["userID", "feedID"]
    )

    var id: String { get { "\(userID)-\(feedID)" } }

    let userID: Int64
    let feedID: Int64
    let subscribed: Bool
}

struct SchemaChangeAddPrimaryKeyColumnChanged: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeAddPrimaryKeyColumn",
        columns: [
            ButtDB.Column(name: "userID", type: .integer),
            ButtDB.Column(name: "feedID", type: .integer),
            ButtDB.Column(name: "episodeID", type: .integer),
            ButtDB.Column(name: "subscribed", type: .integer),
        ],
        primaryKeyColumnNames: ["userID", "feedID", "episodeID"]
    )

    var id: String { get { "\(userID)-\(feedID)-\(episodeID)" } }

    let userID: Int64
    let feedID: Int64
    let episodeID: Int64
    let subscribed: Bool
}




// MARK: - Schema change: Add columns

struct SchemaChangeAddColumnsInitial: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeAddColumns",
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
        ]
    )

    let id: Int64
    var title: String
}

struct SchemaChangeAddColumnsChanged: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeAddColumns",
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
            ButtDB.Column(name: "description", type: .text),
            ButtDB.Column(name: "url",   type: .text, mayBeNull: true),
            ButtDB.Column(name: "art",   type: .data),
        ]
    )

    let id: Int64
    var title: String
    var description: String
    var url: URL?
    var art: Data
}

// MARK: - Schema change: Drop columns

struct SchemaChangeRebuildTableInitial: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeRebuild",
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
            ButtDB.Column(name: "flags", type: .integer),
        ],
        primaryKeyColumnNames: ["id", "title"]
    )

    let id: Int64
    var title: String
    var flags: Int
}

struct SchemaChangeRebuildTableChanged: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeRebuild",
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
            ButtDB.Column(name: "flags", type: .text),
            ButtDB.Column(name: "description", type: .text),
        ]
    )

    let id: Int64
    var title: String
    var flags: String
    var description: String
}

// MARK: - Schema change: Add index

struct SchemaChangeAddIndexInitial: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeAddIndex",
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
        ]
    )

    let id: Int64
    var title: String
}

struct SchemaChangeAddIndexChanged: ButtDBModel {
    static var table = ButtDB.Table(
        name: "SchemaChangeAddIndex",
        columns: [
            ButtDB.Column(name: "id",    type: .integer),
            ButtDB.Column(name: "title", type: .text),
        ],
        indexes: [
            ButtDB.Index(columnNames: ["title"])
        ]
    )

    let id: Int64
    var title: String
}
