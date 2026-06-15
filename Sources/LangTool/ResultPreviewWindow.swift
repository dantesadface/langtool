import AppKit

extension NSWindow {
    /// Centers the window on whichever screen currently contains the mouse
    /// cursor, so popups appear where the user is actually working rather than
    /// on a fixed display.
    func centerOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let area = screen?.visibleFrame else { center(); return }

        let size = frame.size
        let originX = area.midX - size.width / 2
        let originY = area.midY - size.height / 2
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}

/// A review popup that shows the original text and the suggested result before
/// it replaces the selection. The suggestion is editable so the user can tweak
/// it. In translate mode it also offers a target-language dropdown to
/// re-translate on the spot. Choose Replace, Copy, or Cancel.
final class ResultPreviewController: NSWindowController {
    static let shared = ResultPreviewController()

    private let titleLabel = NSTextField(labelWithString: "")
    private let originalView = NSTextView()
    private let suggestionView = NSTextView()

    private let languageRow = NSStackView()
    private let sourcePopup = NSPopUpButton()
    private let languagePopup = NSPopUpButton()
    private let spinner = NSProgressIndicator()

    private var replaceButton: NSButton!
    private var copyButton: NSButton!

    private var onReplace: ((String) -> Void)?
    private var onCopy: ((String) -> Void)?
    /// Produce a fresh translation of the original text using the current
    /// source/target language settings.
    private var retranslate: (() async throws -> String)?

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangTool"
        window.center()
        self.init(window: window)
        buildUI()
    }

    /// Present the popup. `retranslate` is provided for translate mode (enables
    /// the language dropdown); pass `nil` for grammar mode to hide it.
    func present(mode: TransformMode,
                 original: String,
                 suggestion: String,
                 retranslate: (() async throws -> String)?,
                 replace: @escaping (String) -> Void,
                 copy: @escaping (String) -> Void) {
        self.onReplace = replace
        self.onCopy = copy
        self.retranslate = retranslate

        titleLabel.stringValue = mode == .translate ? "Translation" : "Grammar suggestion"
        originalView.string = original
        suggestionView.string = suggestion

        // Language dropdowns only apply to translation.
        languageRow.isHidden = (retranslate == nil)
        if retranslate != nil {
            sourcePopup.removeAllItems()
            sourcePopup.addItems(withTitles: Settings.sourceLanguages)
            sourcePopup.selectItem(withTitle: Settings.shared.sourceLanguage)
            languagePopup.removeAllItems()
            languagePopup.addItems(withTitles: Settings.targetLanguages)
            languagePopup.selectItem(withTitle: Settings.shared.targetLanguage)
        }
        setBusy(false)

        NSApp.activate(ignoringOtherApps: true)
        window?.centerOnActiveScreen()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(suggestionView)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)

        // Language row: "From:" [source] "To:" [target] (spinner)
        let fromLabel = rowLabel("From:")
        let toLabel = rowLabel("To:")
        sourcePopup.target = self
        sourcePopup.action = #selector(languageChanged)
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        languageRow.orientation = .horizontal
        languageRow.spacing = 6
        languageRow.alignment = .centerY
        languageRow.setViews([fromLabel, sourcePopup, toLabel, languagePopup, spinner], in: .leading)

        let originalHeader = sectionLabel("Original")
        let suggestionHeader = sectionLabel("Suggestion (editable)")

        let originalScroll = makeTextScroll(originalView, editable: false)
        let suggestionScroll = makeTextScroll(suggestionView, editable: true)

        replaceButton = NSButton(title: "Replace", target: self, action: #selector(replaceTapped))
        replaceButton.keyEquivalent = "\r"
        replaceButton.bezelStyle = .rounded

        copyButton = NSButton(title: "Copy", target: self, action: #selector(copyTapped))
        copyButton.bezelStyle = .rounded

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Esc

        let buttonRow = NSStackView(views: [cancelButton, copyButton, replaceButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let stack = NSStackView(views: [
            titleLabel,
            languageRow,
            originalHeader, originalScroll,
            suggestionHeader, suggestionScroll,
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.defaultLow, for: .horizontal)
        stack.setCustomSpacing(12, after: languageRow)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),

            originalScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            suggestionScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            originalScroll.heightAnchor.constraint(equalToConstant: 110),
            suggestionScroll.heightAnchor.constraint(equalToConstant: 150),
            buttonRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
    }

    private func rowLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 12)
        l.textColor = .secondaryLabelColor
        return l
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        return l
    }

    private func makeTextScroll(_ textView: NSTextView, editable: Bool) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        textView.isEditable = editable
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]
        if !editable {
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .secondaryLabelColor
        }
        scroll.documentView = textView
        return scroll
    }

    /// Disables controls and shows the spinner while a re-translation runs.
    private func setBusy(_ busy: Bool) {
        busy ? spinner.startAnimation(nil) : spinner.stopAnimation(nil)
        languagePopup.isEnabled = !busy
        replaceButton.isEnabled = !busy
        copyButton.isEnabled = !busy
        suggestionView.isEditable = !busy
    }

    // MARK: - Actions

    @objc private func languageChanged() {
        guard let retranslate else { return }
        if let source = sourcePopup.titleOfSelectedItem {
            Settings.shared.sourceLanguage = source
        }
        if let target = languagePopup.titleOfSelectedItem {
            Settings.shared.targetLanguage = target
        }
        setBusy(true)
        Task {
            do {
                let result = try await retranslate()
                await MainActor.run {
                    self.suggestionView.string = result
                    self.setBusy(false)
                }
            } catch {
                await MainActor.run {
                    self.setBusy(false)
                    Notifier.show(title: "Re-translation failed",
                                  body: error.localizedDescription)
                }
            }
        }
    }

    @objc private func replaceTapped() {
        let text = suggestionView.string
        window?.close()
        onReplace?(text)
    }

    @objc private func copyTapped() {
        let text = suggestionView.string
        window?.close()
        onCopy?(text)
    }

    @objc private func cancelTapped() {
        window?.close()
    }
}
