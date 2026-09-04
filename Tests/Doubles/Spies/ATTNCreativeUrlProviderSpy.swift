//
//  ATTNCreativeUrlProviderSpy.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-14.
//

import Foundation
@testable import ATTNSDKFramework
import XCTest

final class ATTNCreativeUrlProviderSpy: ATTNCreativeUrlProviding {

    // Tests may read this spy from the main thread while the SDK drives it from another,
    // so all state is lock-guarded: recording happens in one critical section (flag last)
    // and the expectation is fulfilled outside the lock.
    private let lock = NSLock()
    private var storage = Storage()

    private func synced<T>(_ body: (inout Storage) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&storage)
    }

    private struct Storage {
        var buildCompanyCreativeUrlWasCalled = false
        var usedDomain: String?
        var usedCreativeId: String?
        var buildCompanyCreativeUrlExpectation: XCTestExpectation?
    }

    var buildCompanyCreativeUrlWasCalled: Bool { synced { $0.buildCompanyCreativeUrlWasCalled } }
    var usedDomain: String? { synced { $0.usedDomain } }
    var usedCreativeId: String? { synced { $0.usedCreativeId } }

    var buildCompanyCreativeUrlExpectation: XCTestExpectation? {
        get { synced { $0.buildCompanyCreativeUrlExpectation } }
        set { synced { $0.buildCompanyCreativeUrlExpectation = newValue } }
    }

    func buildCompanyCreativeUrl(configuration: ATTNSDKFramework.ATTNCreativeUrlConfig) -> String {
        let expectation = synced { storage -> XCTestExpectation? in
            storage.usedDomain = configuration.domain
            storage.usedCreativeId = configuration.creativeId
            storage.buildCompanyCreativeUrlWasCalled = true
            return storage.buildCompanyCreativeUrlExpectation
        }
        expectation?.fulfill()
        return "https://example.com/creative"
    }
}
