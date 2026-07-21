//
//  DebugLogOverlay.swift
//  AttentiveExample
//
//  Created by Umair Sharif on 5/12/26.
//

import UIKit
import ATTNSDKFramework

/// A floating window that renders SDK log entries on top of any screen. Useful for
/// inspecting logs in TestFlight/release builds without attaching a debugger.
///
/// - Tap the floating "LOGS" button to show/hide the panel.
/// - Drag the LOGS button or the panel's title bar to reposition them.
///
/// Owned by `SceneDelegate` for the lifetime of the scene; tear down with `uninstall()`.
final class DebugLogOverlay {
    private let window: OverlayWindow
    private let streamTask: Task<Void, Never>

    init(windowScene: UIWindowScene) {
        let window = OverlayWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.isHidden = false
        let containerVC = OverlayContainerViewController()
        window.rootViewController = containerVC
        self.window = window

        let panelRef = containerVC.panel
        panelRef.replace(with: ATTNSDK.recentLogs())

        self.streamTask = Task {
            for await entry in ATTNSDK.logStream {
                await MainActor.run {
                    panelRef.append(entry)
                }
            }
        }
    }

    func uninstall() {
        streamTask.cancel()
        window.isHidden = true
    }

    deinit {
        streamTask.cancel()
    }
}

/// A window that ignores taps on its empty regions, so the underlying app keeps
/// receiving touches everywhere except on the LOGS button and the floating panel.
private final class OverlayWindow: UIWindow {
    /// Never become key: the app's main window must keep keyboard focus, and code
    /// that resolves the key window (alerts, creatives) must not land on the overlay.
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view === rootViewController?.view { return nil }
        return view
    }
}

/// Clamps a proposed center so at least `minVisible` points of the view stay inside
/// `bounds` on each axis, keeping dragged chrome reachable.
private func clampedCenter(_ proposed: CGPoint, viewSize: CGSize, bounds: CGRect, minVisible: CGFloat = 24) -> CGPoint {
    let visibleX = min(minVisible, viewSize.width)
    let visibleY = min(minVisible, viewSize.height)
    let minX = bounds.minX + visibleX - viewSize.width / 2
    let maxX = bounds.maxX - visibleX + viewSize.width / 2
    let minY = bounds.minY + visibleY - viewSize.height / 2
    let maxY = bounds.maxY - visibleY + viewSize.height / 2
    return CGPoint(
        x: min(max(proposed.x, minX), maxX),
        y: min(max(proposed.y, minY), maxY)
    )
}

private final class OverlayContainerViewController: UIViewController {
    let panel = DebugLogPanelView(frame: CGRect(x: 16, y: 80, width: 320, height: 240))
    private let toggleButton = UIButton(type: .system)
    private var didPositionToggle = false

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .clear
        view = root

        toggleButton.frame = CGRect(x: 0, y: 0, width: 60, height: 44)
        toggleButton.setTitle("LOGS", for: .normal)
        toggleButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toggleButton.layer.cornerRadius = 22
        toggleButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        toggleButton.layer.borderWidth = 1
        toggleButton.addTarget(self, action: #selector(togglePanel), for: .touchUpInside)
        toggleButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:))))
        root.addSubview(toggleButton)

        panel.isHidden = true
        root.addSubview(panel)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didPositionToggle {
            didPositionToggle = true
            let bounds = view.bounds
            let safeBottom = view.safeAreaInsets.bottom
            toggleButton.frame.origin = CGPoint(x: bounds.width - 76, y: bounds.height - safeBottom - 144)
        } else {
            // Preserve user-dragged positions across rotations, but re-clamp so a
            // position that was on-screen in the old orientation stays reachable.
            toggleButton.center = clampedCenter(toggleButton.center, viewSize: toggleButton.bounds.size, bounds: view.bounds)
            panel.center = clampedCenter(panel.center, viewSize: panel.bounds.size, bounds: view.bounds)
        }
    }

    @objc private func togglePanel() {
        let willShow = panel.isHidden
        panel.isHidden = !willShow
        if willShow { panel.flushPending() }
    }

    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        guard let target = gesture.view, let parent = target.superview else { return }
        let translation = gesture.translation(in: parent)
        let proposed = CGPoint(x: target.center.x + translation.x, y: target.center.y + translation.y)
        target.center = clampedCenter(proposed, viewSize: target.bounds.size, bounds: parent.bounds)
        gesture.setTranslation(.zero, in: parent)
    }
}

/// Compact, draggable floating log panel. The title bar is the drag handle.
private final class DebugLogPanelView: UIView {
    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.isEditable = false
        tv.backgroundColor = .clear
        tv.textColor = .white
        tv.alwaysBounceVertical = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let titleBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "SDK Logs"
        l.textColor = .white
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let clearButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Clear", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Source of truth: all retained lines, capped at `maxLines`.
    private var lines: [String] = []
    /// Count of lines from the front of `lines` that are already in `textStorage`.
    /// Lines past this index are pending and will be appended by `flushPending`.
    private var renderedCount = 0
    /// Number of leading rendered lines in `textStorage` that are now stale and
    /// must be spliced out on the next flush. Accumulates while the panel is hidden.
    private var pendingSplice = 0
    private static let maxLines = 1000

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.cornerRadius = 8
        layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        layer.borderWidth = 1
        clipsToBounds = true

        addSubview(titleBar)
        titleBar.addSubview(titleLabel)
        titleBar.addSubview(clearButton)
        addSubview(textView)

        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        titleBar.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:))))
        titleBar.isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -10),
            clearButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            textView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func append(_ entry: ATTNLogEntry) {
        appendLine(formatLine(entry))
    }

    func replace(with entries: [ATTNLogEntry]) {
        lines = entries.map(formatLine)
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
        renderedCount = 0
        pendingSplice = 0
        textView.textStorage.setAttributedString(NSAttributedString())
        if !isHidden { flushPending() }
    }

    /// Reconciles `textView.textStorage` with `lines`. Splices any pending leading
    /// lines out, then appends new tail entries. Cheap when nothing is pending.
    func flushPending() {
        if pendingSplice > 0 {
            spliceLeadingLines(pendingSplice)
            pendingSplice = 0
        }
        guard renderedCount < lines.count else { return }
        let pending = lines[renderedCount...]
        let prefix = renderedCount == 0 ? "" : "\n"
        textView.textStorage.append(
            NSAttributedString(string: prefix + pending.joined(separator: "\n"), attributes: lineAttributes)
        )
        renderedCount = lines.count
        scrollToBottom()
    }

    /// Pushes a single line into the array, trims if needed, and updates `textStorage`
    /// only if the panel is visible. While hidden, work is deferred to `flushPending`.
    private func appendLine(_ line: String) {
        lines.append(line)
        if lines.count > Self.maxLines {
            let drop = lines.count - Self.maxLines
            lines.removeFirst(drop)
            // Of the dropped lines, this many were already in textStorage and need
            // to be spliced out (now or later, depending on visibility).
            let renderedDrop = min(drop, renderedCount)
            renderedCount -= renderedDrop
            if isHidden {
                pendingSplice += renderedDrop
            } else if renderedDrop > 0 {
                spliceLeadingLines(renderedDrop)
            }
        }
        if !isHidden { flushPending() }
    }

    /// Removes the first `count` newline-terminated lines from the text view's storage
    /// in place, preserving attributes on the remaining text.
    private func spliceLeadingLines(_ count: Int) {
        let storage = textView.textStorage
        let plain = storage.string as NSString
        var location = 0
        for _ in 0..<count where location < plain.length {
            let nlRange = plain.range(of: "\n", options: [], range: NSRange(location: location, length: plain.length - location))
            guard nlRange.location != NSNotFound else {
                location = plain.length
                break
            }
            location = nlRange.location + nlRange.length
        }
        if location > 0 {
            storage.replaceCharacters(in: NSRange(location: 0, length: location), with: "")
        }
    }

    private func scrollToBottom() {
        let nsLength = (textView.text as NSString).length
        textView.scrollRangeToVisible(NSRange(location: max(0, nsLength - 1), length: 1))
    }

    private func formatLine(_ entry: ATTNLogEntry) -> String {
        entry.formatted(timestamp: Self.timestampFormatter.string(from: entry.date))
    }

    private var lineAttributes: [NSAttributedString.Key: Any] {
        [
            .font: textView.font ?? UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textView.textColor ?? UIColor.white
        ]
    }

    @objc private func clearTapped() {
        lines.removeAll(keepingCapacity: true)
        renderedCount = 0
        pendingSplice = 0
        textView.textStorage.setAttributedString(NSAttributedString())
    }

    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        let translation = gesture.translation(in: parent)
        let proposed = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        center = clampedCenter(proposed, viewSize: bounds.size, bounds: parent.bounds)
        gesture.setTranslation(.zero, in: parent)
    }
}
