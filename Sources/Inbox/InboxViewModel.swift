//
//  InboxViewModel.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import Combine
import Foundation

@MainActor
class InboxViewModel: ObservableObject {
    @Published
    var state: InboxState = .loading

    private let inbox: Inbox
    private var inboxStateCancellable: AnyCancellable?

    init(inbox: Inbox) {
        self.inbox = inbox
        state = .loading
        inboxStateCancellable = inbox.inboxStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inboxState in
                guard let self else { return }
                state = inboxState
            }
    }

    deinit {
        inboxStateCancellable?.cancel()
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
