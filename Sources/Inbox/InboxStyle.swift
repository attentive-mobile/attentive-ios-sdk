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
    ///
    /// Always concrete: the inits resolve a `nil` argument to ``defaultAccent`` so the views
    /// never have to decide what absent means. `.tint(nil)` in particular is *not* the same as
    /// `.tint(.blue)` — it means "no tint" — so the fallback has to land here, not at the
    /// render site.
    var unreadIndicator: Color

    /// Background revealed by the leading swipe (mark read / mark unread). The trailing
    /// delete swipe keeps the system destructive red.
    ///
    /// Resolved from `nil` the same way as ``unreadIndicator``.
    var swipeBackground: Color

    /// The blue both `unreadIndicator` and `swipeBackground` fall back to, and what the inbox
    /// hardcoded before either was themeable.
    ///
    /// Named once so that a wrapper SDK passing `nil` inherits whatever this becomes, rather
    /// than pinning its own copy of the value.
    static let defaultAccent: Color = .blue

    /// Styles each text role independently. Every parameter defaults to the SDK's own
    /// rendering, so pass only the ones you want to override.
    ///
    /// All three colours take `nil` to mean "don't override", which lets a wrapper SDK forward
    /// an absent value straight through instead of restating the default. Note that `nil` means
    /// something slightly different per knob: `background` keeps the *system* list background,
    /// while `unreadIndicator` and `swipeBackground` take the *SDK's* ``defaultAccent``.
    public init(
        title: Text = Text(font: .headline, color: .primary),
        body: Text = Text(font: .subheadline, color: .secondary),
        timestamp: Text = Text(font: .caption, color: .secondary),
        background: Color? = nil,
        unreadIndicator: Color? = nil,
        swipeBackground: Color? = nil
    ) {
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.background = background
        self.unreadIndicator = unreadIndicator ?? Self.defaultAccent
        self.swipeBackground = swipeBackground ?? Self.defaultAccent
    }

    /// Convenience for the common case of per-role fonts but one shared text colour.
    /// `textColor` applies to the title, body, and timestamp alike.
    ///
    /// Delegates to the role-by-role init above so the colour parameters behave identically and
    /// the `nil`-resolution rule has exactly one home — a future change to how `nil` resolves
    /// (an adaptive per-colour-scheme default, say) can't land in one init and miss the other.
    public init(
        titleFont: Font = .headline,
        bodyFont: Font = .subheadline,
        timestampFont: Font = .caption,
        textColor: Color = .primary,
        background: Color? = nil,
        unreadIndicator: Color? = nil,
        swipeBackground: Color? = nil
    ) {
        self.init(
            title: Text(font: titleFont, color: textColor),
            body: Text(font: bodyFont, color: textColor),
            timestamp: Text(font: timestampFont, color: textColor),
            background: background,
            unreadIndicator: unreadIndicator,
            swipeBackground: swipeBackground
        )
    }
}
