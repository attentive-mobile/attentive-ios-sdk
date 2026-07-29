//
//  InboxViewModel.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/22/26.
//

import Foundation
import UIKit

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
    private let onTap: ((Message) -> Void)?
    private let urlOpener: ATTNURLOpening
    private var stateStreamTask: Task<Void, Never>?
    private var loadingMoreStreamTask: Task<Void, Never>?

    init(
        inboxManager: InboxManager,
        style: InboxStyle,
        onTap: ((Message) -> Void)? = nil,
        urlOpener: ATTNURLOpening = ATTNApplicationURLOpener()
    ) {
        self.inboxManager = inboxManager
        self.style = style
        self.onTap = onTap
        self.urlOpener = urlOpener
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

    /// Called from `InboxView` when the user taps a row. Dispatches the click-tracking POST +
    /// read flip to the manager (async — navigation must not wait on the network, matching the
    /// Android SDK), broadcasts `ATTNSDKInboxMessageTapped` (userInfo carries the actionURL),
    /// then routes the tap — to the host's `onMessageTap` handler when one was provided,
    /// otherwise by opening `actionURL` via `UIApplication`. Unclaimed http(s) links fall back
    /// to the browser; a custom scheme no app claims is logged and dropped. Note the tracking
    /// runs concurrently with routing: an `onMessageTap` handler that reads inbox state
    /// synchronously may still observe the message as unread.
    func click(_ message: Message) {
        Task {
            await inboxManager.markClicked(message.id)
        }
        var userInfo: [AnyHashable: Any] = ["attentiveInboxMessageId": message.id]
        if let actionURL = message.actionURL {
            userInfo["attentiveInboxActionUrl"] = actionURL
        }
        NotificationCenter.default.post(
            name: .ATTNSDKInboxMessageTapped,
            object: nil,
            userInfo: userInfo
        )

        // Host-provided handler replaces the SDK's routing entirely (matches the Android
        // SDK's onMessageClick override) — it hears every tap, even URL-less ones.
        if let onTap {
            onTap(message)
            return
        }

        guard let actionURL = message.actionURL else { return }
        // Server-supplied string: refuse empty-scheme, scriptable (javascript:/file:/data:),
        // and privileged system-action (tel:/sms:/itms-*) URLs. The broadcast above still
        // carries the raw URL — hosts decide for themselves.
        guard actionURL.attnIsOpenableDeepLink else {
            Loggers.network.error("Refusing to open inbox action URL with unsupported scheme: \(actionURL, privacy: .public)")
            return
        }
        urlOpener.open(actionURL, options: [:]) { success in
            if !success {
                Loggers.network.error("No app claimed inbox action URL: \(actionURL, privacy: .public)")
            }
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
