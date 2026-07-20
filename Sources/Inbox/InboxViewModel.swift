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

    /// True while the manager reports a next-page fetch in flight. Driven by the manager's
    /// `loadingMoreStream`, so a rapid `.onAppear` burst that no-ops in the manager never flips
    /// this on, and the flag is only cleared once the real fetch settles.
    @Published
    private(set) var isLoadingMore: Bool = false

    let style: InboxStyle

    private let inboxManager: InboxManager
    private var stateStreamTask: Task<Void, Never>?
    private var loadingMoreStreamTask: Task<Void, Never>?

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
        loadingMoreStreamTask = Task { [weak self] in
            guard let stream = await self?.inboxManager.loadingMoreStream else { return }
            for await isLoading in stream {
                guard !Task.isCancelled else { return }
                self?.isLoadingMore = isLoading
            }
        }
    }

    deinit {
        stateStreamTask?.cancel()
        loadingMoreStreamTask?.cancel()
    }

    func refresh() async {
        await inboxManager.refresh()
    }

    /// Called by the view when the last row appears, triggering an infinite-scroll page fetch.
    /// The manager guards against overlapping calls and no-ops when no more pages are available;
    /// spinner visibility is driven by its `loadingMoreStream` (see init), not this method.
    func loadNextPage() {
        Task { [inboxManager] in
            await inboxManager.loadNextPage()
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

    /// Fires the click-tracking POST and flips the row's read state. Called from `InboxView`
    /// when the user taps a row. The view is responsible for opening the message's `actionURL`
    /// (if any) so hosts can intercept for deep-link routing.
    func click(_ messageID: Message.ID) {
        Task {
            await inboxManager.markClicked(messageID)
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
