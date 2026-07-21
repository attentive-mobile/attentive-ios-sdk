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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Fires click tracking + local read flip, and broadcasts
                                // `ATTNSDKInboxMessageTapped` (userInfo carries the actionURL).
                                // The SDK does not open the URL itself — host apps route it.
                                viewModel.click(message)
                            }
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
                            .onAppear {
                                // Pull-up-to-load-more: when the last row scrolls into view, ask for
                                // the next page. The manager is a no-op when nothing more is available.
                                if message.id == messages.last?.id {
                                    viewModel.loadNextPage()
                                }
                            }
                    }
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
    }

    private func buildListView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        List(content: content)
            .listStyle(.plain)
            .navigationTitle(String.inbox)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
    }
}
