//
//  InboxView.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import SwiftUI

struct InboxView: View {
    @ObservedObject
    var viewModel: InboxViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            Text("Error")
        case .empty:
            List {
                Text("No messages")
            }
            .listStyle(.plain)
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
        case .loaded(let messages):
            List(messages) { message in
                InboxMessageRow(message: message, style: viewModel.style)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.delete(message.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            message.isRead ? viewModel.markUnread(message.id) : viewModel.markAsRead(message.id)
                        } label: {
                            message.isRead ? Label("Unread", systemImage: "envelope") : Label("Read", systemImage: "envelope.open")
                        }
                        .tint(.blue)
                    }
            }
            .listStyle(.plain)
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

struct InboxMessageRow: View {
    var message: Message
    var style: InboxViewStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }

            switch style {
            case .small:
                buildAsyncImageView(for: style)
                buildTextStackView()
            case .large:
                VStack(alignment: .leading, spacing: 4) {
                    buildAsyncImageView(for: style)
                    buildTextStackView()
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func buildAsyncImageView(for style: InboxViewStyle) -> some View {
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
