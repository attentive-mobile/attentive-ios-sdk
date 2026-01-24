//
//  InboxViewModel.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import Combine
import Foundation

class InboxViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([Message])
        case error
    }

    @Published
    var state: State = .loading

    private let inbox: Inbox
    private var allMessagesCancellable: AnyCancellable?

    init(inbox: Inbox) {
        self.inbox = inbox
        loadInbox()
    }
    
    deinit {
        allMessagesCancellable?.cancel()
    }

    private func loadInbox() {
        state = .loading
        allMessagesCancellable = inbox.allMessagesPublisher.sink { [weak self] messages in
            guard let self else { return }
            let sortedMessages = messages.sorted(by: { $0.timestamp > $1.timestamp })
            self.state = .loaded(sortedMessages)
        }
    }

    func refresh() {
        loadInbox()
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
