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
        
        public init(font: Font, color: Color = .primary) {
            self.font = font
            self.color = color
        }
    }

    public enum Row {
        case small
        case large
    }

    var row: Row
    var title: Text
    var body: Text
    var timestamp: Text

    public init(
        row: Row = .small,
        title: Text = Text(font: .headline),
        body: Text = Text(font: .subheadline, color: .secondary),
        timestamp: Text = Text(font: .caption, color: .secondary)
    ) {
        self.row = row
        self.title = title
        self.body = body
        self.timestamp = timestamp
    }

    public init(
        row: Row,
        titleFont: Font = .headline,
        bodyFont: Font = .subheadline,
        timestampFont: Font = .caption,
        textColor: Color = .primary
    ) {
        self.row = row
        self.title = Text(font: titleFont, color: textColor)
        self.body = Text(font: bodyFont, color: textColor)
        self.timestamp = Text(font: timestampFont, color: textColor)
    }
}
