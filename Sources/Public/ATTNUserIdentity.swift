//
//  ATTNUserIdentity.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import Foundation

@objc(ATTNUserIdentity)
public final class ATTNUserIdentity: NSObject {
    private let lock = NSLock()
    private var _identifiers: [String: Any]
    private var _visitorId: String
    private let visitorService: ATTNVisitorService

    @objc public var identifiers: [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return _identifiers
    }

    @objc public var visitorId: String {
        lock.lock()
        defer { lock.unlock() }
        return _visitorId
    }

    @objc
    override public convenience init() {
        self.init(identifiers: [:])
    }

    @objc(initWithIdentifiers:)
    public init(identifiers: [String: Any]) {
        self.visitorService = .init()
        self._identifiers = identifiers
        self._visitorId = self.visitorService.getVisitorId()
        super.init()
    }

    @objc
    public func clearUser() {
        lock.lock()
        _identifiers = [:]
        _visitorId = visitorService.createNewVisitorId()
        lock.unlock()
    }

    @objc
    public func mergeIdentifiers(_ newIdentifiers: [String: Any]) {
        validate(identifiers: newIdentifiers)
        lock.lock()
        // In case of a key conflict, the new value from newIdentifiers should be used.
        _identifiers.merge(newIdentifiers) { (_, new) in new }
        lock.unlock()
    }
}

fileprivate extension ATTNUserIdentity {
    func validate(identifiers: [String: Any]) {
        for key in identifiers.keys {
            if key == ATTNIdentifierType.customIdentifiers {
                ATTNParameterValidation.verify1DStringDictionaryOrNil(
                    identifiers[key] as? NSDictionary,
                    inputName: key)
            } else {
                ATTNParameterValidation.verifyStringOrNil(
                    identifiers[key] as? NSObject,
                    inputName: key)
            }
        }
    }
}
