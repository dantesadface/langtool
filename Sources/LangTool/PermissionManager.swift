import AppKit
import ApplicationServices

/// Helpers for the Accessibility permission required to post synthetic keystrokes.
enum PermissionManager {
    /// Returns true if the process is trusted for Accessibility. When `prompt` is
    /// true and access is missing, macOS shows its system prompt.
    @discardableResult
    static func ensureAccessibility(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Opens System Settings directly at the Accessibility pane.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
