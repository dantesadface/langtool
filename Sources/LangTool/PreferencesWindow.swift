import AppKit

/// A simple AppKit preferences window: API key, source/target language, model.
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let apiKeyField = NSSecureTextField()
    private let sourcePopup = NSPopUpButton()
    private let targetPopup = NSPopUpButton()
    private let modelPopup = NSPopUpButton()
    private let previewCheckbox = NSButton(checkboxWithTitle: "Preview suggestion before replacing",
                                           target: nil, action: nil)

    private let languages = [
        "Auto-detect", "English", "Tagalog", "Cebuano", "Spanish",
        "Japanese", "Korean", "Chinese", "French", "German"
    ]

    private let models: [(label: String, id: String)] = [
        ("Haiku 4.5 (fast, cheap)", "claude-haiku-4-5-20251001"),
        ("Sonnet 4.6 (balanced)", "claude-sonnet-4-6"),
        ("Opus 4.8 (best quality)", "claude-opus-4-8")
    ]

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangTool Preferences"
        window.center()
        self.init(window: window)
        buildUI()
    }

    func show() {
        loadValues()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let grid = NSGridView(views: [
            [label("Anthropic API key:"), apiKeyField],
            [label("Translate from:"), sourcePopup],
            [label("Translate to:"), targetPopup],
            [label("Model:"), modelPopup]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing

        apiKeyField.placeholderString = "sk-ant-..."
        apiKeyField.widthAnchor.constraint(equalToConstant: 250).isActive = true

        sourcePopup.addItems(withTitles: languages)
        targetPopup.addItems(withTitles: languages)
        for model in models { modelPopup.addItem(withTitle: model.label) }

        let hint = NSTextField(wrappingLabelWithString:
            "Hotkeys:  ⌥⌘T translate   ·   ⌥⌘G fix grammar\nSelect text in any app, then press a hotkey.")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        previewCheckbox.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(grid)
        content.addSubview(previewCheckbox)
        content.addSubview(hint)
        content.addSubview(saveButton)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),

            previewCheckbox.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 14),
            previewCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            hint.topAnchor.constraint(equalTo: previewCheckbox.bottomAnchor, constant: 14),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            saveButton.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16)
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    // MARK: - Load / Save

    private func loadValues() {
        let settings = Settings.shared
        apiKeyField.stringValue = settings.apiKey ?? ""
        sourcePopup.selectItem(withTitle: settings.sourceLanguage)
        targetPopup.selectItem(withTitle: settings.targetLanguage)
        if let idx = models.firstIndex(where: { $0.id == settings.model }) {
            modelPopup.selectItem(at: idx)
        }
        previewCheckbox.state = settings.previewBeforeReplace ? .on : .off
    }

    @objc private func save() {
        let settings = Settings.shared
        settings.apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.sourceLanguage = sourcePopup.titleOfSelectedItem ?? "Tagalog"
        settings.targetLanguage = targetPopup.titleOfSelectedItem ?? "English"
        let modelIdx = modelPopup.indexOfSelectedItem
        if models.indices.contains(modelIdx) {
            settings.model = models[modelIdx].id
        }
        settings.previewBeforeReplace = (previewCheckbox.state == .on)
        window?.close()
    }
}
