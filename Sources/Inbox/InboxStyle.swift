//
//  InboxStyle.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/27/26.
//

import SwiftUI

public struct InboxStyle {
    public struct Text {
        var font: Font
        var color: Color

        public init(font: Font, color: Color) {
            self.font = font
            self.color = color
        }
    }

    var title: Text
    var body: Text
    var timestamp: Text

    /// Background painted behind the message list. `nil` — the default — leaves the system
    /// list background in place, which is what the inbox rendered before this knob existed
    /// (white in light mode, black in dark mode).
    ///
    /// Fully honoured on iOS 16+. On iOS 15 the List's own scroll background can't be hidden,
    /// so only the message rows take the colour; the area below the last row stays system-coloured.
    var background: Color?

    /// Fill of the leading dot on unread rows. Read rows draw it clear.
    var unreadIndicator: Color

    /// Background revealed by the leading swipe (mark read / mark unread). The trailing
    /// delete swipe keeps the system destructive red.
    var swipeBackground: Color

    /// Styles each text role independently. Every parameter defaults to the SDK's own
    /// rendering, so pass only the ones you want to override.
    public init(
        title: Text = Text(font: .headline, color: .primary),
        body: Text = Text(font: .subheadline, color: .secondary),
        timestamp: Text = Text(font: .caption, color: .secondary),
        background: Color? = nil,
        unreadIndicator: Color = .blue,
        swipeBackground: Color = .blue
    ) {
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.background = background
        self.unreadIndicator = unreadIndicator
        self.swipeBackground = swipeBackground
    }

    /// Convenience for the common case of per-role fonts but one shared text colour.
    /// `textColor` applies to the title, body, and timestamp alike.
    public init(
        titleFont: Font = .headline,
        bodyFont: Font = .subheadline,
        timestampFont: Font = .caption,
        textColor: Color = .primary,
        background: Color? = nil,
        unreadIndicator: Color = .blue,
        swipeBackground: Color = .blue
    ) {
        self.title = Text(font: titleFont, color: textColor)
        self.body = Text(font: bodyFont, color: textColor)
        self.timestamp = Text(font: timestampFont, color: textColor)
        self.background = background
        self.unreadIndicator = unreadIndicator
        self.swipeBackground = swipeBackground
    }
}
