import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        HotKeyManager.shared.register()

        // Nudge the user toward granting Accessibility on first launch.
        if !PermissionManager.isAccessibilityTrusted {
            PermissionManager.ensureAccessibility(prompt: true)
        }

        // Open Preferences automatically if no API key is configured yet.
        if !Settings.shared.hasAPIKey {
            PreferencesWindowController.shared.show()
        }
    }

    // MARK: - Main menu (Edit menu enables ⌘C/⌘V/⌘X in text fields)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (provides ⌘Q etc. when a window is key).
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit LangTool",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu — wires up the standard editing keyboard shortcuts.
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "character.bubble",
                                   accessibilityDescription: "LangTool")
            button.image?.isTemplate = true
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let translateItem = NSMenuItem(title: "Translate Selection",
                                       action: #selector(translate),
                                       keyEquivalent: "t")
        translateItem.keyEquivalentModifierMask = [.option, .command]
        translateItem.target = self
        menu.addItem(translateItem)

        let grammarItem = NSMenuItem(title: "Fix Grammar in Selection",
                                     action: #selector(fixGrammar),
                                     keyEquivalent: "g")
        grammarItem.keyEquivalentModifierMask = [.option, .command]
        grammarItem.target = self
        menu.addItem(grammarItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…",
                                   action: #selector(openPreferences),
                                   keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let accessItem = NSMenuItem(title: "Open Accessibility Settings",
                                    action: #selector(openAccessibility),
                                    keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        let aboutItem = NSMenuItem(title: "About LangTool",
                                   action: #selector(openAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit LangTool",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func translate() { TextProcessor.shared.run(mode: .translate) }
    @objc private func fixGrammar() { TextProcessor.shared.run(mode: .grammar) }
    @objc private func openPreferences() { PreferencesWindowController.shared.show() }
    @objc private func openAbout() { AboutWindowController.shared.show() }
    @objc private func openAccessibility() { PermissionManager.openAccessibilitySettings() }
}
