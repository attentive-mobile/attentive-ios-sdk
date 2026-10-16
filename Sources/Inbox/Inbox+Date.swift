//
//  Inbox+Date.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 7/23/26.
//

import Foundation

extension Date {
    func inboxRelativeString(now: Date = Date(), calendar: Calendar = .current) -> String {
        guard self <= now else { return String(localized: "Just now") }

        let elapsed = calendar.dateComponents([.day, .hour, .minute], from: self, to: now)
        switch (elapsed.day ?? 0, elapsed.hour ?? 0, elapsed.minute ?? 0) {
        case (7..., _, _):
            return formatted(.dateTime.month(.abbreviated).day())
        case (let days, _, _) where days >= 1:
            return String(localized: "\(days)d ago")
        case (_, let hours, _) where hours >= 1:
            return String(localized: "\(hours)h ago")
        case (_, _, let minutes) where minutes >= 1:
            return String(localized: "\(minutes)m ago")
        default:
            return String(localized: "Just now")
        }
    }
}
