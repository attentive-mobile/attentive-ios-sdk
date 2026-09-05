//
//  InboxStyleTests.swift
//  attentive-ios-sdk Tests
//

import XCTest
import SwiftUI
@testable import ATTNSDKFramework

final class InboxStyleTests: XCTestCase {

    // MARK: - Defaults preserve pre-existing rendering

    /// The three colour knobs added in MSDK-480 default to what the inbox rendered before
    /// they existed: a blue unread dot, a blue leading-swipe background, and no background
    /// override (so the List keeps the system background).
    func testDefaultInit_usesPreExistingRenderingValues() {
        let style = InboxStyle()

        XCTAssertNil(style.background)
        XCTAssertEqual(style.unreadIndicator, .blue)
        XCTAssertEqual(style.swipeBackground, .blue)
    }

    func testFontConvenienceInit_usesPreExistingRenderingValues() {
        let style = InboxStyle(textColor: .black)

        XCTAssertNil(style.background)
        XCTAssertEqual(style.unreadIndicator, .blue)
        XCTAssertEqual(style.swipeBackground, .blue)
    }

    /// Adding the colour parameters must not disturb the text styling the two inits already set.
    func testDefaultInit_leavesTextStylingUnchanged() {
        let style = InboxStyle()

        XCTAssertEqual(style.title.font, .headline)
        XCTAssertEqual(style.title.color, .primary)
        XCTAssertEqual(style.body.font, .subheadline)
        XCTAssertEqual(style.body.color, .secondary)
        XCTAssertEqual(style.timestamp.font, .caption)
        XCTAssertEqual(style.timestamp.color, .secondary)
    }

    // MARK: - Custom values

    func testDesignatedInit_storesCustomColors() {
        let style = InboxStyle(
            background: .green,
            unreadIndicator: .pink,
            swipeBackground: .orange
        )

        XCTAssertEqual(style.background, .green)
        XCTAssertEqual(style.unreadIndicator, .pink)
        XCTAssertEqual(style.swipeBackground, .orange)
    }

    func testFontConvenienceInit_storesCustomColors() {
        let style = InboxStyle(
            titleFont: .system(size: 16, weight: .semibold),
            bodyFont: .system(size: 14),
            timestampFont: .caption,
            textColor: .black,
            background: .green,
            unreadIndicator: .pink,
            swipeBackground: .orange
        )

        XCTAssertEqual(style.background, .green)
        XCTAssertEqual(style.unreadIndicator, .pink)
        XCTAssertEqual(style.swipeBackground, .orange)
        // The single `textColor` still fans out to all three text roles.
        XCTAssertEqual(style.title.color, .black)
        XCTAssertEqual(style.body.color, .black)
        XCTAssertEqual(style.timestamp.color, .black)
    }

    /// The colour knobs are independent — setting one must not pull the others off their defaults.
    func testCustomizingOneColor_leavesTheOthersAtDefaults() {
        let style = InboxStyle(unreadIndicator: .pink)

        XCTAssertEqual(style.unreadIndicator, .pink)
        XCTAssertNil(style.background)
        XCTAssertEqual(style.swipeBackground, .blue)
    }

    // MARK: - Source compatibility

    /// Existing integrations call these inits positionally / with the old argument set. They
    /// must keep compiling unchanged now that the colour parameters have been appended.
    func testExistingCallSitesStillCompile() {
        let textStyled = InboxStyle(
            title: .init(font: .headline, color: .primary),
            body: .init(font: .subheadline, color: .secondary),
            timestamp: .init(font: .caption, color: .secondary)
        )
        let fontStyled = InboxStyle(
            titleFont: .system(size: 16, weight: .semibold),
            bodyFont: .system(size: 14),
            timestampFont: .caption,
            textColor: .primary
        )

        XCTAssertEqual(textStyled.unreadIndicator, .blue)
        XCTAssertEqual(fontStyled.unreadIndicator, .blue)
    }
}
