//
//  InboxView.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import SwiftUI

struct InboxView: View {
    var viewModel: InboxViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            Text("Error")
        case .loaded(let messages):
            List(messages) { message in
                InboxMessageRow(message: message)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.delete(message.id)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        
                        if !message.isRead {
                            Button {
                                viewModel.markAsRead(message.id)
                            } label: {
                                Label("Read", systemImage: "envelope.open")
                            }
                            .tint(.blue)
                        }
                    }
            }
            .listStyle(.plain)
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refresh()
            }
        }
    }
}

struct InboxMessageRow: View {
    var message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
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

                Text(message.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

extension Message {
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
