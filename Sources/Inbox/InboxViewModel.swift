//
//  InboxViewModel.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import Foundation

class InboxViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([Message])
        case error
    }

    @Published
    var state: State = .loading

    private var messages: [Message.ID: Message] = [:]
    private var sortedMessages: [Message] {
        messages.values.sorted(by: { $0.timestamp > $1.timestamp })
    }

    private let sdk: ATTNSDK

    init(sdk: ATTNSDK) {
        self.sdk = sdk
        loadInbox()
    }

    private func loadInbox() {
        state = .loading
        Task {
            let messages = await sdk.allMessages
            self.messages = messages.reduce(into: [:]) { $0[$1.id] = $1 }
            state = .loaded(sortedMessages)
        }
    }

    func refresh() {
        loadInbox()
    }

    func markAsRead(_ messageID: Message.ID) {
        messages[messageID]?.isRead = true
        sdk.markRead(for: messageID)
        state = .loaded(sortedMessages)
    }

    func markUnread(_ messageID: Message.ID) {
        messages[messageID]?.isRead = false
        sdk.markUnread(for: messageID)
        state = .loaded(sortedMessages)
    }

    func delete(_ messageID: Message.ID) {
        messages.removeValue(forKey: messageID)
        sdk.delete(messageID: messageID)
        state = .loaded(sortedMessages)
    }
}
