//
//  ButtDBModelObjC.h
//  Created by Marco Arment on 11/29/22.
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
//
//  ***************************************************************************************************
//  *                                                                                                 *
//  *    This file can be omitted from projects that don't need ButtDB access from Objective-C.    *
//  *                                                                                                 *
//  ***************************************************************************************************
//

#ifndef ButtDBModelObjC_h
#define ButtDBModelObjC_h

#import <Foundation/Foundation.h>

extern NSString * _Nonnull const ButtDBModelObjCTableDidChangeNotification;
extern NSString * _Nonnull const ButtDBModelObjCChangedTableKey;
extern NSString * _Nonnull const ButtDBModelObjCChangedPrimaryKeyValuesKey;


/// The superclass for Objective-C ButtDB models, providing a basic subset of the functionality of Swift `ButtDBModel` instances.
@interface ButtDBModelObjC : NSObject


/// Specifies the table schema for this model. **Required** for subclasses to override.
/// - Returns: A ``ButtDBTableObjC`` to define the table for this model.
///
+ (ButtDBTableObjC * _Nonnull)table;


/// Performs setup and any necessary schema migrations.
///
/// Optional. If not called manually, setup and schema migrations will occur when the first database operation is performed by this class.
///
/// - Parameters:
///   - database: The ``ButtDBDatabaseObjC`` instance to resolve the schema in.
///   - completion: A block to call upon completion. **May be called on a background thread.**
///
+ (void)resolveInDatabase:(ButtDBDatabaseObjC * _Nonnull)database completion:(void (^ _Nullable)(void))completion;


/// Reads a single instance with the given primary-key value from a database if the primary key is a single column named `id`.
/// - Parameters:
///   - database: The ``ButtDBDatabaseObjC`` instance to read from.
///   - idValue: The value of the `id` column.
///   - completion: A block to call upon completion. **May be called on a background thread.**
///
+ (void)readFromDatabase:(ButtDBDatabaseObjC * _Nonnull)database withID:(id _Nonnull)idValue completion:(void (^ _Nullable)(ButtDBModelObjC * _Nullable))completion;


/// Reads instances from a database using an array of arguments.
///
/// - Parameters:
///   - database: The ``ButtDBDatabaseObjC`` instance to read from.
///   - where: The portion of the desired SQL query after the `WHERE` keyword. May contain placeholders specified as a question mark (`?`).
///   - arguments: An array of values corresponding to any placeholders in the query.
///   - completion: A block to call upon completion with an array of matching instances. **May be called on a background thread.**
/// - Returns: An array of decoded instances matching the query.
+ (void)readFromDatabase:(ButtDBDatabaseObjC * _Nonnull)database where:(NSString * _Nonnull)where arguments:(NSArray * _Nullable)arguments completion:(void (^ _Nullable)(NSArray<ButtDBModelObjC *> * _Nonnull))completion;


/// Write this instance to a database.
/// - Parameters:
///   - database: The ``ButtDBDatabaseObjC`` instance to write to.
///   - completion: A block to call upon completion. **May be called on a background thread.**
- (void)writeToDatabase:(ButtDBDatabaseObjC * _Nonnull)database completion:(void (^ _Nullable)(void))completion;


/// Delete this instance from a database.
/// - Parameters:
///   - database: The ``ButtDBDatabaseObjC`` instance to delete from.
///   - completion: A block to call upon completion. **May be called on a background thread.**
- (void)deleteFromDatabase:(ButtDBDatabaseObjC * _Nonnull)database completion:(void (^ _Nullable)(void))completion;


/// Synchronous version of ``resolveInDatabase:completion:`` using blocking semaphores.
///
/// > Warning: Deadlock risk if misused. Use the asynchronous functions when possible.
+ (void)resolveInDatabaseSync:(ButtDBDatabaseObjC * _Nonnull)database;

/// Synchronous version of ``readFromDatabase:withID:completion:`` using blocking semaphores.
///
/// > Warning: Deadlock risk if misused. Use the asynchronous functions when possible.
+ (instancetype _Nullable)readFromDatabaseSync:(ButtDBDatabaseObjC * _Nonnull)database withID:(id _Nonnull)idValue;

/// Synchronous version of ``readFromDatabase:where:arguments:completion:`` using blocking semaphores.
///
/// > Warning: Deadlock risk if misused. Use the asynchronous functions when possible.
+ (NSArray<ButtDBModelObjC *> * _Nonnull)readFromDatabaseSync:(ButtDBDatabaseObjC * _Nonnull)database where:(NSString * _Nonnull)where arguments:(NSArray * _Nullable)arguments;

/// Synchronous version of ``writeToDatabase:completion:`` using blocking semaphores.
///
/// > Warning: Deadlock risk if misused. Use the asynchronous functions when possible.
- (void)writeToDatabaseSync:(ButtDBDatabaseObjC * _Nonnull)database;

/// Synchronous version of ``deleteFromDatabase:completion:`` using blocking semaphores.
///
/// > Warning: Deadlock risk if misused. Use the asynchronous functions when possible.
- (void)deleteFromDatabaseSync:(ButtDBDatabaseObjC * _Nonnull)database;

@end

#endif /* ButtDBModelObjC_h */
