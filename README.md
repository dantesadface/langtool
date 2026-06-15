# LangTool

A macOS menu-bar app that translates or grammar-corrects text **in any app**.
Select text anywhere, press a hotkey, and LangTool replaces it in place using
the Claude API.

- **⌥⌘T** — Translate the selection (default **Tagalog → English**)
- **⌥⌘G** — Fix grammar/spelling in the selection (keeps the original language)

It works in any text field — browsers, Slack, Notes, Mail, etc. — because it
drives the system clipboard with synthetic ⌘C / ⌘V keystrokes rather than
relying on each app to expose its text.

## How it works

1. You select text and press a hotkey.
2. LangTool copies the selection (synthetic ⌘C) and reads the clipboard.
3. It sends the text to the Claude API with a translate or grammar prompt.
4. It writes the result to the clipboard and pastes it back (synthetic ⌘V).

## Requirements

- macOS 13+
- Swift toolchain (Xcode or Command Line Tools — `xcode-select --install`)
- An Anthropic API key (`sk-ant-...`)

## Build & install

```bash
./scripts/build-app.sh --install
```

This builds a release binary, packages it into `LangTool.app`, ad-hoc
code-signs it, copies it to `/Applications`, and launches it. Omit `--install`
to build into `./dist/LangTool.app` without installing.

> Ad-hoc signing into a real `.app` bundle matters: macOS attributes the
> Accessibility permission to LangTool itself rather than to your terminal.

## First-run setup

1. **Accessibility** — On first launch macOS prompts to allow LangTool under
   *System Settings ▸ Privacy & Security ▸ Accessibility*. Enable it (required
   to send the copy/paste keystrokes). The menu has a shortcut to this pane.
2. **API key** — Preferences opens automatically when no key is set. Paste your
   Anthropic API key (stored in the macOS Keychain) and click Save.
3. **Languages** — Set source/target languages and the model in Preferences.
   Default is Tagalog → English on Haiku 4.5.

## Usage

Select text in any app, then:

- **⌥⌘T** to translate it
- **⌥⌘G** to fix its grammar

The selection is replaced with the result. The same actions are available from
the menu-bar icon (the speech-bubble glyph).

## Configuration

| Setting | Default | Notes |
|---|---|---|
| Translate from | Tagalog | Or Auto-detect / other languages |
| Translate to | English | Any supported language |
| Model | `claude-haiku-4-5-20251001` | Haiku / Sonnet / Opus selectable |
| API key | — | Stored in Keychain, never on disk |

## Project layout

```
langtool/
├── Package.swift
├── Sources/LangTool/
│   ├── main.swift            # NSApplication entry (menu-bar accessory)
│   ├── AppDelegate.swift     # Menu bar + actions
│   ├── HotKeyManager.swift   # Global ⌥⌘T / ⌥⌘G hotkeys (Carbon)
│   ├── TextProcessor.swift   # Copy → transform → paste pipeline
│   ├── ClaudeClient.swift    # Anthropic Messages API client
│   ├── Settings.swift        # Preferences (UserDefaults)
│   ├── KeychainHelper.swift  # API key storage
│   ├── PermissionManager.swift
│   ├── Notifier.swift
│   └── PreferencesWindow.swift
├── Resources/Info.plist      # LSUIElement (menu-bar only) bundle metadata
└── scripts/build-app.sh      # Build + bundle + sign + (optional) install
```

## Notes & limitations

- Requires a network connection and a valid API key; each transform is a
  billed Claude API call.
- Some apps don't update the clipboard instantly; LangTool waits up to ~1s for
  the copy before giving up with a "No text selected" notice.
- Hotkeys are currently fixed at ⌥⌘T / ⌥⌘G.
