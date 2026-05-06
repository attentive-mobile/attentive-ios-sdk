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
