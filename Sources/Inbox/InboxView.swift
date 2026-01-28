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
            Text(String.somethingWentWrong)
        case .empty:
            buildListView {
                Text(String.noMessages)
            }
        case .loaded(let messages):
            buildListView {
                ForEach(messages) { message in
                    InboxMessageRowView(message: message, style: viewModel.messageRowStyle)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.delete(message.id)
                            } label: {
                                Label(String.delete, systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                message.isRead ? viewModel.markUnread(message.id) : viewModel.markAsRead(message.id)
                            } label: {
                                message.isRead ? Label(String.unread, systemImage: "envelope") : Label(String.read, systemImage: "envelope.open")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
    }

    private func buildListView<Content: View>(content: () -> Content) -> some View {
        List(content: content)
            .listStyle(.plain)
            .navigationTitle(String.inbox)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable(action: viewModel.refresh)
    }
}
