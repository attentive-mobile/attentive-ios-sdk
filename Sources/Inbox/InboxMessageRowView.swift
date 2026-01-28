//
//  InboxMessageRowView.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/27/26.
//

import SwiftUI

struct InboxMessageRowView: View {
    var message: Message
    var style: InboxMessageRowViewStyle

    var body: some View {
        HStack(alignment: .titleCenter, spacing: 12) {
            if !message.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .alignmentGuide(.titleCenter) { d in
                        // Offset to keep dot vertically centered with title
                        // while alignment line is at title top
                        d[VerticalAlignment.top] - 6
                    }
            }

            switch style {
            case .small:
                buildAsyncImageView(for: style)
                    .alignmentGuide(.titleCenter) { d in d[VerticalAlignment.top] }
                buildTextStackView()
            case .large:
                VStack(alignment: .leading, spacing: 4) {
                    buildAsyncImageView(for: style)
                    buildTextStackView()
                }
            }
        }
    }

    @ViewBuilder
    private func buildAsyncImageView(for style: InboxMessageRowViewStyle) -> some View {
        if let imageURL = message.imageURL {
            let asyncImage = AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "photo")
                    .aspectRatio(contentMode: .fit)
            }.clipShape(RoundedRectangle(cornerRadius: 8))

            switch style {
            case .large: asyncImage.frame(maxWidth: .infinity)
            case .small: asyncImage.frame(width: 60, height: 60)
            }
        }
    }
    
    private func buildTextStackView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.title)
                .font(.headline)
                .fontWeight(message.isRead ? .regular : .bold)
                .lineLimit(1)
                .alignmentGuide(.titleCenter) { d in d[VerticalAlignment.top] }

            Text(message.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(message.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Custom Alignment

extension VerticalAlignment {
    private enum TitleCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let titleCenter = VerticalAlignment(TitleCenter.self)
}
