import AppKit
import Carbon.HIToolbox

/// Captures the current selection from the frontmost app, transforms it via Claude,
/// and pastes the result back in place. Works in any app because it drives the
/// system clipboard with synthetic ⌘C / ⌘V keystrokes (requires Accessibility access).
final class TextProcessor {
    static let shared = TextProcessor()

    private let client = ClaudeClient()
    private var isBusy = false

    /// The app that was frontmost when the hotkey fired — we reactivate it
    /// before pasting so the result lands back in the original text field.
    private var sourceApp: NSRunningApplication?

    func run(mode: TransformMode) {
        guard !isBusy else { return }

        guard PermissionManager.ensureAccessibility() else {
            Notifier.show(title: "LangTool needs Accessibility access",
                          body: "Enable LangTool in System Settings ▸ Privacy & Security ▸ Accessibility, then try again.")
            return
        }

        guard Settings.shared.hasAPIKey else {
            Notifier.show(title: "No API key set",
                          body: "Open LangTool ▸ Preferences to add your Anthropic API key.")
            return
        }

        // Remember the frontmost app before we (possibly) show our own window.
        sourceApp = NSWorkspace.shared.frontmostApplication

        guard let selected = copySelection(), !selected.isEmpty else {
            Notifier.show(title: "No text selected",
                          body: "Select some text first, then press the LangTool hotkey.")
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let result = try await client.transform(selected, mode: mode)
                await MainActor.run {
                    if Settings.shared.previewBeforeReplace {
                        self.presentPreview(mode: mode, original: selected, suggestion: result)
                    } else {
                        self.applyReplacement(result)
                    }
                }
            } catch {
                Notifier.show(title: "LangTool failed", body: error.localizedDescription)
            }
        }
    }

    @MainActor
    private func presentPreview(mode: TransformMode, original: String, suggestion: String) {
        // In translate mode, let the popup re-translate when the user changes
        // the source/target language. The popup updates Settings before calling
        // this closure, so transform() picks up the new languages.
        let retranslate: (() async throws -> String)? = mode == .translate
            ? { [client] in try await client.transform(original, mode: .translate) }
            : nil

        ResultPreviewController.shared.present(
            mode: mode,
            original: original,
            suggestion: suggestion,
            retranslate: retranslate,
            replace: { [weak self] finalText in
                self?.applyReplacement(finalText)
            },
            copy: { finalText in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(finalText, forType: .string)
            }
        )
    }

    // MARK: - Clipboard capture

    /// Simulates ⌘C, waits for the pasteboard to update, and returns the copied string.
    private func copySelection() -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        sendKeystroke(keyCode: CGKeyCode(kVK_ANSI_C), command: true)

        // Poll briefly for the pasteboard to register the copy.
        let deadline = Date().addingTimeInterval(1.0)
        while pasteboard.changeCount == previousChangeCount && Date() < deadline {
            usleep(20_000) // 20ms
        }

        guard pasteboard.changeCount != previousChangeCount else { return nil }
        return pasteboard.string(forType: .string)
    }

    // MARK: - Clipboard replace

    @MainActor
    private func applyReplacement(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Reactivate the original app so the paste lands in the right place.
        // (When previewing, our own window is frontmost at this point.)
        let needsReactivation = !(sourceApp?.isActive ?? true)
        sourceApp?.activate(options: [])

        // Give focus time to return to the source app before pasting.
        let delay = needsReactivation ? 0.20 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.sendKeystroke(keyCode: CGKeyCode(kVK_ANSI_V), command: true)
        }
    }

    // MARK: - Synthetic keystrokes

    private func sendKeystroke(keyCode: CGKeyCode, command: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let flags: CGEventFlags = command ? .maskCommand : []

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
