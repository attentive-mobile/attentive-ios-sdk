//
//  InboxMessageRowView.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/27/26.
//

import SwiftUI

struct InboxMessageRowView: View {
    var message: Message
    var style: InboxStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(message.isRead ? .clear : .blue)
                .frame(width: 8, height: 8)

            switch style.row {
            case .small:
                buildAsyncImageView()
                buildTextStackView()
            case .large:
                VStack(alignment: .leading, spacing: 4) {
                    buildAsyncImageView()
                    buildTextStackView()
                }
            }
        }
    }

    @ViewBuilder
    private func buildAsyncImageView() -> some View {
        if let imageURL = message.imageURL {
            let asyncImage = AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "photo")
                    .aspectRatio(contentMode: .fit)
            }.clipShape(RoundedRectangle(cornerRadius: 8))

            switch style.row {
            case .large: asyncImage.frame(maxWidth: .infinity)
            case .small: asyncImage.frame(width: 60, height: 60)
            }
        }
    }
    
    private func buildTextStackView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.title)
                .font(style.title.font)
                .foregroundColor(style.title.color)
                .fontWeight(message.isRead ? .regular : .bold)
                .lineLimit(1)

            Text(message.body)
                .font(style.body.font)
                .foregroundColor(style.body.color)
                .lineLimit(2)

            Text(message.timestamp, style: .relative)
                .font(style.timestamp.font)
                .foregroundColor(style.timestamp.color)
                .foregroundColor(.gray)
        }
    }
}
