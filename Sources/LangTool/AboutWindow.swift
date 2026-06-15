import AppKit

/// "About LangTool" window — shows app info and the TabsWorks company section.
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About LangTool"
        window.center()
        self.init(window: window)
        buildUI()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.centerOnActiveScreen()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // App icon
        let appIconView = NSImageView()
        appIconView.image = NSImage(named: "AppIcon") ?? bundledImage("AppIcon")
        appIconView.imageScaling = .scaleProportionallyUpOrDown

        let appName = centeredLabel("LangTool", font: .systemFont(ofSize: 22, weight: .bold))
        let version = centeredLabel("Version \(appVersion())",
                                    font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
        let tagline = centeredLabel("Translate & refine text in any app.",
                                    font: .systemFont(ofSize: 12), color: .secondaryLabelColor)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        // Company section
        let aboutHeader = centeredLabel("ABOUT THE COMPANY",
                                        font: .systemFont(ofSize: 10, weight: .semibold),
                                        color: .tertiaryLabelColor)

        let companyLogo = NSImageView()
        companyLogo.image = bundledImage("tabsworks-logo")
        companyLogo.imageScaling = .scaleProportionallyUpOrDown

        let estLabel = centeredLabel("Established 2026",
                                     font: .systemFont(ofSize: 12, weight: .medium))
        let companyTagline = centeredLabel("Building Solutions. Empowering Growth.",
                                           font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
        let copyright = centeredLabel("© 2026 TabsWorks. All rights reserved.",
                                      font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)

        let stack = NSStackView(views: [
            appIconView, appName, version, tagline,
            divider, aboutHeader, companyLogo, estLabel, companyTagline, copyright
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(14, after: tagline)
        stack.setCustomSpacing(14, after: divider)
        stack.setCustomSpacing(12, after: aboutHeader)
        stack.setCustomSpacing(12, after: companyLogo)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            appIconView.widthAnchor.constraint(equalToConstant: 88),
            appIconView.heightAnchor.constraint(equalToConstant: 88),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            companyLogo.widthAnchor.constraint(equalToConstant: 150),
            companyLogo.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    // MARK: - Helpers

    private func centeredLabel(_ text: String,
                               font: NSFont,
                               color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font
        l.textColor = color
        l.alignment = .center
        return l
    }

    private func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return v ?? "1.0"
    }

    /// Loads an image bundled in Contents/Resources by base name.
    private func bundledImage(_ name: String) -> NSImage? {
        for ext in ["icns", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }
}
