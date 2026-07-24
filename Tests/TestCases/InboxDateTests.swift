//
//  InboxDateTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Umair Sharif on 7/23/26.
//

import Foundation
import Testing
@testable import ATTNSDKFramework

struct InboxDateTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func relativeString(secondsAgo: TimeInterval) -> String {
        now.addingTimeInterval(-secondsAgo).inboxRelativeString(now: now, calendar: calendar)
    }

    @Test(arguments: [0, 59, -120] as [TimeInterval])
    func underOneMinuteOrFuture_isJustNow(secondsAgo: TimeInterval) {
        #expect(relativeString(secondsAgo: secondsAgo) == "Just now")
    }

    @Test(arguments: [
        (60, "1m ago"),
        (31 * 60, "31m ago"),
        (3599, "59m ago")
    ] as [(TimeInterval, String)])
    func minutes(secondsAgo: TimeInterval, expected: String) {
        #expect(relativeString(secondsAgo: secondsAgo) == expected)
    }

    @Test(arguments: [
        (3600, "1h ago"),
        (5 * 3600, "5h ago"),
        (86_399, "23h ago")
    ] as [(TimeInterval, String)])
    func hours(secondsAgo: TimeInterval, expected: String) {
        #expect(relativeString(secondsAgo: secondsAgo) == expected)
    }

    @Test(arguments: [
        (86_400, "1d ago"),
        (3 * 86_400, "3d ago"),
        (604_799, "6d ago")
    ] as [(TimeInterval, String)])
    func days(secondsAgo: TimeInterval, expected: String) {
        #expect(relativeString(secondsAgo: secondsAgo) == expected)
    }

    @Test
    func oneWeekOrOlder_usesAbbreviatedMonthDay() {
        let date = now.addingTimeInterval(-604_800)
        #expect(date.inboxRelativeString(now: now, calendar: calendar) == date.formatted(.dateTime.month(.abbreviated).day()))
    }
}
