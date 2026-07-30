//
//  ATTNEvent+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

// MARK: Internal Helpers
extension ATTNEvent {
    func convertEventToRequests() -> [ATTNEventRequest] {
        guard let provider = self as? ATTNEventRequestProvider else {
            Loggers.event.debug("Unknown event type: \(type(of: self)). It can not be converted to EventRequest.")
            return []
        }

        return provider.eventRequests
    }

    var priceFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        // Pin to POSIX so decimals always serialize with `.` regardless of the
        // device locale. Backends parse totals with `BigDecimal`/`Double.valueOf`
        // which don't accept the `,` separators produced on de_DE, fr_FR, etc.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
