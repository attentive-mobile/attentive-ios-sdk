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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                buildListView {
                    Text(String.noMessages)
                }
            case .loaded(let messages):
                buildListView {
                    ForEach(messages) { message in
                        InboxMessageRowView(message: message, style: viewModel.style)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // The VM owns tap routing: click tracking + read flip, the
                                // `ATTNSDKInboxMessageTapped` broadcast, then the host's
                                // `onMessageTap` handler or the default `actionURL` open.
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
                                .tint(viewModel.style.swipeBackground)
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
        // Applied to the state container, not just the list: `.loading` and `.error` don't
        // render a List, and leaving them out flashed the system background on every fetch
        // and dropped the host's theme entirely whenever a fetch failed.
        .inboxListBackground(viewModel.style.background)
        // Same reason as the background: only `.empty` and `.loaded` build a List, so titling
        // it there left a blank nav bar on every cold launch and every failed fetch.
        .navigationTitle(String.inbox)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
        }
    }

    /// The colour each row paints behind itself.
    ///
    /// On iOS 16+ the theme is already painted once behind the whole inbox by
    /// `inboxListBackground(_:)`, so rows stay clear — painting `style.background` here as well
    /// composites the two layers, which is wasted work for an opaque colour and visibly wrong
    /// for a translucent one (rows render darker than the gaps between them). On iOS 15
    /// `.scrollContentBackground(.hidden)` doesn't exist, so the List's opaque scroll background
    /// covers that fill and the rows are the only place the theme can land.
    ///
    /// A `nil` style background means no override at all, matching the SDK's behaviour before
    /// `InboxStyle.background` existed.
    private var rowBackground: Color? {
        guard let background = viewModel.style.background else { return nil }
        if #available(iOS 16.0, *) {
            return .clear
        } else {
            return background
        }
    }

    private func buildListView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        List {
            // Applied once to the whole content rather than per row-emitting site: list-row
            // modifiers distribute across the rows a ViewBuilder produces, so this reaches the
            // `ForEach`'s rows, the empty-state label, and the load-more spinner alike. Verified
            // by rendering each of those three shapes and sampling pixels, since that
            // distribution is SwiftUI behaviour rather than anything guaranteed by the type.
            content()
                .listRowBackground(rowBackground)
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

private extension View {
    /// Paints `color` behind the inbox in every state. Hiding the List's own scroll background
    /// needs `.scrollContentBackground(.hidden)`, which is iOS 16+; on iOS 15 the scroll
    /// background stays opaque and only the rows' `.listRowBackground` takes the colour.
    /// `.scrollContentBackground` reaches the List through the environment, so this can sit
    /// above the state switch rather than on the List itself.
    ///
    /// A `nil` colour leaves the view untouched so the list keeps the system background —
    /// the SDK's behaviour before `InboxStyle.background` existed.
    @ViewBuilder
    func inboxListBackground(_ color: Color?) -> some View {
        if let color {
            if #available(iOS 16.0, *) {
                self
                    .scrollContentBackground(.hidden)
                    .background(color)
            } else {
                self.background(color)
            }
        } else {
            self
        }
    }
}
