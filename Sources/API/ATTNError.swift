//
//  ATTNError.swift
//  attentive-ios-sdk-framework
//
//  Created by Adela Gao on 8/20/25.
//

import Foundation

public enum ATTNError: Error {
  case sdkNotInitialized
  case missingContactInfo
  case geoDomainUnavailable
  case badURL
}

extension ATTNError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .sdkNotInitialized:
      return "SDK not initialized"
    case .missingContactInfo:
      return "Provide email and/or phone"
    case .geoDomainUnavailable:
      return "Geo domain unavailable"
    case .badURL:
      return "Invalid URL"
    }
  }
}
