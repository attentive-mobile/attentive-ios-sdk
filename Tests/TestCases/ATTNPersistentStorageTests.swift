//
//  ATTNPersistentStorageTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNPersistentStorageTests: XCTestCase {

    private var persistentStorage: ATTNPersistentStorage!
    private let KEY = "savedKey"
    private let VALUE = "savedValue"

    override func setUp() {
        super.setUp()
        resetUserDefaults()
        persistentStorage = ATTNPersistentStorage()
    }

    func resetUserDefaults() {
        if let domainName = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domainName)
        }
    }

    override func tearDown() {
        resetUserDefaults()
        super.tearDown()
    }

    func testSaveObject() {
        persistentStorage.save("savedValue" as NSObject, forKey: "someKey")

        XCTAssertEqual("savedValue", persistentStorage.readString(forKey: "someKey"))
    }

    func testSaveObject_givenValidString_saves() {
        persistentStorage.save(VALUE as NSObject, forKey: KEY)

        XCTAssertEqual(VALUE, persistentStorage.readString(forKey: KEY))
    }

    func testSaveObject_overwriteWithSameValue_saves() {
        persistentStorage.save(VALUE as NSObject, forKey: KEY)

        XCTAssertEqual(VALUE, persistentStorage.readString(forKey: KEY))

        persistentStorage.save(VALUE as NSObject, forKey: KEY)

        XCTAssertEqual(VALUE, persistentStorage.readString(forKey: KEY))
    }

    func testSaveObject_overwriteWithDifferentValue_savesDifferentValue() {
        persistentStorage.save(VALUE as NSObject, forKey: KEY)

        XCTAssertEqual(VALUE, persistentStorage.readString(forKey: KEY))

        persistentStorage.save("newValue" as NSObject, forKey: KEY)

        XCTAssertEqual("newValue", persistentStorage.readString(forKey: KEY))
    }

    func testReadStringForKey_noPreviousObjectSaved_returnsNil() {
        XCTAssertNil(persistentStorage.readString(forKey: KEY))
    }

    func testReadStringForKey_previousObjectSaved_returnsObject() {
        persistentStorage.save(VALUE as NSObject, forKey: KEY)

        XCTAssertEqual(VALUE, persistentStorage.readString(forKey: KEY))
    }

    func testDeleteObjectForKey_noPreviousObjectSaved_noop() {
        XCTAssertNoThrow(persistentStorage.delete(forKey: KEY))
    }

    func testDeleteObjectForKey_previousObjectSaved_deletes() {
        persistentStorage.save(VALUE as NSObject, forKey: KEY)

        XCTAssertEqual(VALUE, persistentStorage.readString(forKey: KEY))

        persistentStorage.delete(forKey: KEY)

        XCTAssertNil(persistentStorage.readString(forKey: KEY))
    }
}
