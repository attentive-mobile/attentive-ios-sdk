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

    private let inbox: Inbox

    init(inbox: Inbox) {
        self.inbox = inbox
        state = .loading
        Task {
            for await state in await inbox.stateStream {
                self.state = state.viewState
            }
        }
    }

    func refresh() async {
        await inbox.refresh()
    }

    func markAsRead(_ messageID: Message.ID) {
        Task {
            await inbox.markRead(messageID)
        }
    }

    func markUnread(_ messageID: Message.ID) {
        Task {
            await inbox.markUnread(messageID)
        }
    }

    func delete(_ messageID: Message.ID) {
        Task {
            await inbox.delete(messageID)
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
