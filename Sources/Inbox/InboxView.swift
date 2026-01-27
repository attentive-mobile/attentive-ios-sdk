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
                InboxMessageRow(message: message)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageURL = message.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "photo")
                        .aspectRatio(contentMode: .fit)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.title)
                        .font(.headline)
                        .fontWeight(message.isRead ? .regular : .bold)
                        .lineLimit(1)

                    Spacer()

                    if !message.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    } else {
                        EmptyView()
                    }
                }

                Text(message.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(message.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}
