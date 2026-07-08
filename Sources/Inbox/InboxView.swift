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
        Group {
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
                        InboxMessageRowView(message: message, style: viewModel.style)
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
        // Trigger the first load when the view appears. Cancels automatically when the view
        // disappears; SwiftUI re-runs it whenever the identity provided by the `.task` id changes,
        // but there's no id here so it runs once per appearance.
        .task {
            await viewModel.refresh()
        }
    }

    private func buildListView<Content: View>(content: () -> Content) -> some View {
        List(content: content)
            .listStyle(.plain)
            .navigationTitle(String.inbox)
            .navigationBarTitleDisplayMode(.inline)
            // Wrap in a closure rather than passing `viewModel.refresh` directly: the method
            // reference isn't `@Sendable` (viewModel is a `@MainActor ObservableObject`) and
            // `.refreshable` requires a `@Sendable () async -> Void`. The closure hops onto
            // the main actor via the `await`, satisfying both sides.
            .refreshable {
                await viewModel.refresh()
            }
    }
}
