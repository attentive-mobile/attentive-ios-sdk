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

    init(inboxManager: InboxManager, style: InboxStyle) {
        self.inboxManager = inboxManager
        self.style = style
        state = .loading
        Task {
            for await state in await inboxManager.stateStream {
                self.state = state.viewState
            }
        }
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
