# LangTool

A macOS menu-bar app that translates or grammar-corrects text **in any app**.
Select text anywhere, press a hotkey, and LangTool transforms it in place using
the Claude API.

- **⌥⌘T** — Translate the selection (default **Tagalog → English**)
- **⌥⌘G** — Fix grammar/spelling in the selection (keeps the original language)

It works in any text field — browsers, Slack, Notes, Mail, etc. — because it
drives the system clipboard with synthetic ⌘C / ⌘V keystrokes rather than
relying on each app to expose its text.

_LangTool by TabsWorks · Established 2026._

## How it works

1. You select text and press a hotkey.
2. LangTool copies the selection (synthetic ⌘C) and reads the clipboard.
3. It sends the text to the Claude API with a translate or grammar prompt.
4. By default it shows a **preview window** with the suggestion (editable). You
   choose **Replace**, **Copy**, or **Cancel**. (Turn the preview off to replace
   instantly.)
5. On Replace, it writes the result to the clipboard and pastes it back into the
   original app (synthetic ⌘V).

## Requirements

- macOS 13+
- An Anthropic API key (`sk-ant-...`) — see [Getting an API key](#getting-an-api-key)
- To build from source: the Swift toolchain (Xcode or Command Line Tools —
  `xcode-select --install`). Not needed if you install from the prebuilt DMG.

## Install

### Option A — DMG (recommended)

The easiest path. Build the installer once, then drag-to-Applications:

```bash
./scripts/make-dmg.sh
open dist/LangTool.dmg
```

In the window that opens, drag **LangTool** onto the **Applications** shortcut.
Share `dist/LangTool.dmg` with anyone who wants to install it.

### Option B — Build & install directly

```bash
./scripts/build-app.sh --install
```

Builds a release binary, packages it into `LangTool.app`, ad-hoc code-signs it,
copies it to `/Applications`, and launches it. Omit `--install` to build into
`./dist/LangTool.app` without installing.

> **Why a real `.app` bundle (not a bare binary):** macOS attributes the
> Accessibility permission to the bundled, signed app — not to your terminal.

## First-run setup

1. **Accessibility** — On first launch macOS prompts to allow LangTool under
   *System Settings ▸ Privacy & Security ▸ Accessibility*. Enable it (required
   to send the copy/paste keystrokes). The menu-bar icon has a shortcut to this
   pane.
2. **API key** — Preferences opens automatically when no key is set. Paste your
   Anthropic API key (stored in the macOS Keychain) and click **Save**.
3. **Languages & options** — Set source/target languages, model, and the preview
   toggle in Preferences. Default is Tagalog → English on Haiku 4.5.

> **Reinstalling / rebuilding?** Ad-hoc builds get a new signature each time, so
> macOS treats a rebuilt app as "new" and the old Accessibility grant goes
> stale. After replacing the app, re-enable it under Accessibility. To clear a
> stale grant: `tccutil reset Accessibility com.langtool.app`.

## Usage

Select text in any app, then:

- **⌥⌘T** to translate it
- **⌥⌘G** to fix its grammar

With preview on (default), review/edit the suggestion and click **Replace**. The
same actions, plus **About** and **Preferences**, are in the menu-bar dropdown
(the speech-bubble icon).

## Getting an API key

LangTool uses the Anthropic API (separate from a Claude.ai chat subscription).

1. Sign in at <https://console.anthropic.com>.
2. Add credits under **Settings → Billing** (API usage is pay-as-you-go).
3. Create a key under **Settings → API Keys** — it starts with `sk-ant-...` and
   is shown only once.
4. Paste it into LangTool ▸ Preferences (stored in the macOS Keychain).

Default model is **Haiku 4.5**, which is very cheap; a few dollars of credit
lasts a long time. Switch to Sonnet/Opus in Preferences for higher quality.

## Configuration

| Setting | Default | Notes |
|---|---|---|
| Translate from | Tagalog | Or Auto-detect / other languages |
| Translate to | English | Any supported language |
| Model | `claude-haiku-4-5-20251001` | Haiku / Sonnet / Opus selectable |
| Preview before replacing | On | Show an editable suggestion window first |
| API key | — | Stored in Keychain, never on disk |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/build-app.sh [--install]` | Build + bundle + ad-hoc sign `LangTool.app` (optionally install to /Applications). |
| `scripts/make-dmg.sh` | Build the app and package a drag-to-Applications `LangTool.dmg`. |
| `scripts/make-icon.sh <png>` | Regenerate `Resources/AppIcon.icns` from a source logo. |

## Project layout

```
langtool/
├── Package.swift
├── Sources/LangTool/
│   ├── main.swift              # NSApplication entry (menu-bar accessory)
│   ├── AppDelegate.swift       # Menu bar, main menu, actions
│   ├── HotKeyManager.swift     # Global ⌥⌘T / ⌥⌘G hotkeys (Carbon)
│   ├── TextProcessor.swift     # Copy → transform → (preview) → paste pipeline
│   ├── ClaudeClient.swift      # Anthropic Messages API client
│   ├── Settings.swift          # Preferences (UserDefaults)
│   ├── KeychainHelper.swift    # API key storage (Keychain)
│   ├── PermissionManager.swift # Accessibility permission helpers
│   ├── Notifier.swift          # User notifications
│   ├── PreferencesWindow.swift # Settings UI
│   ├── ResultPreviewWindow.swift # Editable suggestion preview
│   └── AboutWindow.swift       # About + TabsWorks company section
├── Resources/
│   ├── Info.plist              # LSUIElement (menu-bar only) + icon metadata
│   ├── AppIcon.icns            # App icon
│   ├── logo-source.png         # Source artwork for the app icon
│   └── tabsworks-logo.png      # Company logo (About window)
└── scripts/
    ├── build-app.sh            # Build + bundle + sign + (optional) install
    ├── make-dmg.sh             # Package distributable .dmg
    └── make-icon.sh            # Generate AppIcon.icns from a PNG
```

## Notes & limitations

- Requires a network connection and a valid API key; each transform is a billed
  Claude API call.
- Some apps don't update the clipboard instantly; LangTool waits up to ~1s for
  the copy before giving up with a "No text selected" notice.
- Hotkeys are currently fixed at ⌥⌘T / ⌥⌘G.
- Builds are ad-hoc signed, so Gatekeeper may warn on first open and the
  Accessibility grant must be re-applied after each rebuild (see setup notes).
