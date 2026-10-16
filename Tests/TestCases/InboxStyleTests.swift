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

    // MARK: - Explicit nil inherits the default

    /// A wrapper SDK (React Native) builds a full `InboxStyle` from values that are each
    /// optional on the JS side, so it needs to forward "absent" without restating the default.
    /// Passing `nil` explicitly must land on the same colours as omitting the argument.
    func testDesignatedInit_explicitNilColors_inheritDefaults() {
        let unreadIndicator: Color? = nil
        let swipeBackground: Color? = nil
        let background: Color? = nil

        let style = InboxStyle(
            background: background,
            unreadIndicator: unreadIndicator,
            swipeBackground: swipeBackground
        )

        XCTAssertNil(style.background)
        XCTAssertEqual(style.unreadIndicator, InboxStyle.defaultAccent)
        XCTAssertEqual(style.swipeBackground, InboxStyle.defaultAccent)
    }

    func testFontConvenienceInit_explicitNilColors_inheritDefaults() {
        let unreadIndicator: Color? = nil
        let swipeBackground: Color? = nil

        let style = InboxStyle(
            textColor: .black,
            background: nil,
            unreadIndicator: unreadIndicator,
            swipeBackground: swipeBackground
        )

        XCTAssertNil(style.background)
        XCTAssertEqual(style.unreadIndicator, InboxStyle.defaultAccent)
        XCTAssertEqual(style.swipeBackground, InboxStyle.defaultAccent)
    }

    /// Mixing a forwarded `nil` with a concrete colour must resolve each independently, which
    /// is the shape of the wrapper's real call: every knob arrives separately optional.
    func testExplicitNilAndConcreteColors_resolveIndependently() {
        let style = InboxStyle(
            background: Color?.none,
            unreadIndicator: .pink,
            swipeBackground: Color?.none
        )

        XCTAssertNil(style.background)
        XCTAssertEqual(style.unreadIndicator, .pink)
        XCTAssertEqual(style.swipeBackground, InboxStyle.defaultAccent)
    }

    /// The fallback the wrapper inherits by passing `nil` must stay the blue the inbox
    /// hardcoded before these knobs existed — this is the value it no longer has to copy.
    func testDefaultAccent_isThePreExistingBlue() {
        XCTAssertEqual(InboxStyle.defaultAccent, .blue)
    }

    /// Compile-and-run check on the exact `UIColor?` -> `Color?` bridging the README documents
    /// for wrapper SDKs, so the documented form can't drift from what actually builds.
    func testWrapperBridgingFromOptionalUIColor() {
        let providedBackground: UIColor? = .green
        let absentIndicator: UIColor? = nil
        let absentSwipe: UIColor? = nil

        let style = InboxStyle(
            background: providedBackground.map(Color.init(uiColor:)),
            unreadIndicator: absentIndicator.map(Color.init(uiColor:)),
            swipeBackground: absentSwipe.map(Color.init(uiColor:))
        )

        XCTAssertEqual(style.background, Color(uiColor: .green))
        XCTAssertEqual(style.unreadIndicator, InboxStyle.defaultAccent)
        XCTAssertEqual(style.swipeBackground, InboxStyle.defaultAccent)
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
