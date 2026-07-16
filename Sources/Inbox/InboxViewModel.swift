//
//  InboxViewModel.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import Foundation

@MainActor
class InboxViewModel: ObservableObject {
    enum State {
        case loading
        case empty
        case loaded([Message])
        case error(Error)
    }

    @Published
    var state: State = .loading

    /// True while a `loadNextPage()` call is in flight. Drives the footer spinner in `InboxView`.
    @Published
    var isLoadingMore: Bool = false

    let style: InboxStyle

    private let inboxManager: InboxManager
    private var stateStreamTask: Task<Void, Never>?

    init(inboxManager: InboxManager, style: InboxStyle) {
        self.inboxManager = inboxManager
        self.style = style
        state = .loading
        stateStreamTask = Task { [weak self] in
            guard let stream = await self?.inboxManager.stateStream else { return }
            for await state in stream {
                guard !Task.isCancelled else { return }
                self?.state = state.viewState
            }
        }
    }

    deinit {
        stateStreamTask?.cancel()
    }

    func refresh() async {
        await inboxManager.refresh()
    }

    /// Called by the view when the last row appears, triggering an infinite-scroll page fetch.
    /// The manager guards against overlapping calls and no-ops when no more pages are available;
    /// its `Bool` return tells us whether a fetch actually started so we can toggle the footer
    /// spinner off only when there was one to hide.
    func loadNextPage() {
        // Optimistically show the spinner; the manager will either fetch (spinner stays until the
        // fetch returns) or no-op (we clear it immediately below). A brief flash on no-op is
        // preferable to two actor hops on every last-row `.onAppear`.
        isLoadingMore = true
        Task { [weak self] in
            guard let self = self else { return }
            _ = await self.inboxManager.loadNextPage()
            self.isLoadingMore = false
        }
    }

    func markAsRead(_ messageID: Message.ID) {
        Task {
            await inboxManager.markRead(messageID)
        }
    }

    func markUnread(_ messageID: Message.ID) {
        Task {
            await inboxManager.markUnread(messageID)
        }
    }

    func delete(_ messageID: Message.ID) {
        Task {
            await inboxManager.delete(messageID)
        }
    }
}

extension InboxState {
    var viewState: InboxViewModel.State {
        switch self {
        case .loading: .loading
        case .loaded(let messages): messages.isEmpty ? .empty : .loaded(messages)
        case .error(let error): .error(error)
        }
    }
}
