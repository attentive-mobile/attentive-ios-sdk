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
final class DebugLogOverlay {
    static let shared = DebugLogOverlay()

    private var window: OverlayWindow?
    private var streamTask: Task<Void, Never>?

    private init() {}

    func install(on windowScene: UIWindowScene) {
        guard window == nil else { return }
        let window = OverlayWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.isHidden = false
        window.rootViewController = OverlayContainerViewController()
        self.window = window

        let containerVC = window.rootViewController as? OverlayContainerViewController
        containerVC?.panel.replace(with: ATTNSDK.recentLogs())

        let containerRef = containerVC
        streamTask = Task {
            for await entry in ATTNSDK.logStream {
                await MainActor.run {
                    containerRef?.panel.append(entry)
                }
            }
        }
    }
}

/// A window that ignores taps on its empty regions, so the underlying app keeps
/// receiving touches everywhere except on the LOGS button and the floating panel.
private final class OverlayWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view === rootViewController?.view { return nil }
        return view
    }
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
        // Preserve user-dragged position across rotations.
        guard !didPositionToggle else { return }
        didPositionToggle = true
        let bounds = view.bounds
        let safeBottom = view.safeAreaInsets.bottom
        toggleButton.frame.origin = CGPoint(x: bounds.width - 76, y: bounds.height - safeBottom - 144)
    }

    @objc private func togglePanel() {
        let willShow = panel.isHidden
        panel.isHidden = !willShow
        if willShow { panel.flushPending() }
    }

    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        guard let target = gesture.view, let parent = target.superview else { return }
        let translation = gesture.translation(in: parent)
        target.center = CGPoint(x: target.center.x + translation.x, y: target.center.y + translation.y)
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

    /// Lines pending append when the panel is hidden. Flushed in one batch on show.
    private var pendingLines: [String] = []
    private var lineCount = 0
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
        let line = formatLine(entry)
        guard !isHidden else {
            pendingLines.append(line)
            if pendingLines.count > Self.maxLines {
                pendingLines.removeFirst(pendingLines.count - Self.maxLines)
            }
            return
        }
        appendVisibleLine(line)
    }

    func replace(with entries: [ATTNLogEntry]) {
        let text = entries.map(formatLine).joined(separator: "\n")
        textView.text = text
        lineCount = entries.count
        scrollToBottom()
    }

    /// Apply any entries received while hidden. Called by the container on show.
    func flushPending() {
        guard !pendingLines.isEmpty else { return }
        let chunk = pendingLines.joined(separator: "\n")
        pendingLines.removeAll(keepingCapacity: true)
        appendVisibleLine(chunk)
    }

    private func appendVisibleLine(_ line: String) {
        let prefix = textView.text.isEmpty ? "" : "\n"
        textView.textStorage.append(NSAttributedString(
            string: prefix + line,
            attributes: [
                .font: textView.font ?? UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: textView.textColor ?? UIColor.white
            ]
        ))
        lineCount += 1
        trimIfNeeded()
        scrollToBottom()
    }

    private func trimIfNeeded() {
        guard lineCount > Self.maxLines else { return }
        let text = textView.text ?? ""
        var dropCount = lineCount - Self.maxLines
        var idx = text.startIndex
        while dropCount > 0, let nl = text[idx...].firstIndex(of: "\n") {
            idx = text.index(after: nl)
            dropCount -= 1
        }
        textView.text = String(text[idx...])
        lineCount = Self.maxLines
    }

    private func scrollToBottom() {
        let nsLength = (textView.text as NSString).length
        textView.scrollRangeToVisible(NSRange(location: max(0, nsLength - 1), length: 1))
    }

    private func formatLine(_ entry: ATTNLogEntry) -> String {
        entry.formatted(timestamp: Self.timestampFormatter.string(from: entry.date))
    }

    @objc private func clearTapped() {
        textView.text = ""
        pendingLines.removeAll(keepingCapacity: true)
        lineCount = 0
    }

    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        let translation = gesture.translation(in: parent)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: parent)
    }
}
