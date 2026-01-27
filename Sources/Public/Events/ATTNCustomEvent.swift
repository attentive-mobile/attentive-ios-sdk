//
//  ATTNCustomEvent.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNCustomEvent)
public final class ATTNCustomEvent: NSObject, ATTNEvent {
    @objc public let type: String
    @objc public let properties: [String: String]

    @objc(initWithType:properties:)
    public init?(type: String, properties: [String: String]) {
        ATTNParameterValidation.verifyNotNil(type as NSObject, inputName: "type")
        ATTNParameterValidation.verifyStringOrNil(type as NSObject, inputName: "type")
        if let invalidCharInType = ATTNCustomEvent.findInvalidCharacter(in: type) {
            Loggers.event.debug("Invalid character \(invalidCharInType, privacy: .public) in CustomEvent type \(type, privacy: .public)")
            return nil
        }

        ATTNParameterValidation.verifyNotNil(properties as NSObject, inputName: "properties")
        ATTNParameterValidation.verify1DStringDictionaryOrNil(properties as NSDictionary, inputName: "properties")
        if properties.keys
            .map({ ATTNCustomEvent.findInvalidCharacterInPropertiesKey(key: $0) })
            .first(where: { $0 != nil }) != nil {
            return nil
        }

        self.type = type
        self.properties = properties
    }
}

fileprivate extension ATTNCustomEvent {
    static func findInvalidCharacter(in type: String) -> String? {
        let invalidCharacters = ["\"", "'", "(", ")", "{", "}", "[", "]", "\\", "|", ","]
        return findCharacter(in: type, charactersToFind: invalidCharacters)
    }

    static func findInvalidCharacterInPropertiesKey(key: String) -> String? {
        let invalidCharacters = ["\"", "{", "}", "[", "]", "\\", "|"]
        return findCharacter(in: key, charactersToFind: invalidCharacters)
    }

    static func findCharacter(in input: String, charactersToFind: [String]) -> String? {
        for character in charactersToFind where input.range(of: character) != nil {
            return character
        }
        return nil
    }
}
