# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Luzia Universal Typo Correcter is a macOS menubar app that corrects typos and grammar in any text field system-wide using OpenAI's API. It operates as an LSUIElement agent app (no Dock icon).

**Stack:** Swift 5.5+ / SwiftUI, macOS 11.0+, OpenAI Responses API, Sparkle (auto-updates), Carbon (global hotkeys), Accessibility APIs

## Build & Development Commands

```bash
# Quick build and launch (recommended)
./quick-deploy.sh

# Open in Xcode
open "Luzia Universal Typo Correcter.xcodeproj"

# Build from command line
xcodebuild -project "Luzia Universal Typo Correcter.xcodeproj" \
  -scheme "Luzia Universal Typo Correcter" -configuration Release

# Run tests
xcodebuild test -project "Luzia Universal Typo Correcter.xcodeproj" \
  -scheme "Luzia Universal Typo Correcter" -destination 'platform=macOS'

# Watch logs
./watch-logs.sh
# Or: log stream --predicate 'subsystem contains "luzia"' --level debug
```

**After rebuilding:** Reset Accessibility permissions in System Settings > Privacy & Security > Accessibility (remove and re-add the app).

## Architecture

### Core Workflow

The app uses a clipboard-based copy-correct-paste approach triggered by ⇧⌘G:

1. Save clipboard → Copy selected text (AX API with CGEvent fallback)
2. Wait for clipboard change (50ms polling, 1.5s timeout)
3. Send to OpenAI Responses API → Receive corrected text
4. Put corrected text in clipboard → Paste (AX API with CGEvent fallback)
5. Restore original clipboard → Log success

**Entry point:** `AppDelegate.handleHotKeyPressed()` (AppDelegate.swift:153)

### Key Components

| File | Purpose |
|------|---------|
| `AppDelegate.swift` | Main orchestrator: menubar UI, hotkey, permission checks, copy-correct-paste flow |
| `ClipboardManager.swift` | Clipboard save/restore, change detection (polling), RTF preservation (buggy) |
| `OpenAIService.swift` | Responses API client, reasoning effort for GPT-5, retry logic |
| `AppState.swift` | ObservableObject with UserDefaults persistence for all preferences |
| `HotKey.swift` | Carbon Event Manager wrapper for ⇧⌘G global hotkey |
| `StartupManager.swift` | Launch at login via SMAppService (macOS 13+) / SMLoginItemSetEnabled |
| `EvalLogger.swift` / `ErrorLogger.swift` | TSV logging for analytics and debugging |

### OpenAI API

Uses the **Responses API** (`/v1/responses`), not Chat Completions:

```json
{
  "model": "gpt-5-mini",
  "instructions": "<system_prompt>",
  "input": "<user_text>",
  "max_output_tokens": 4000,
  "reasoning": { "effort": "low" }  // GPT-5 only
}
```

**Models:** gpt-5, gpt-5-mini, gpt-5-nano (reasoning supported), gpt-4.1, gpt-4.1-mini

**Inline instructions:** Users can include `<<command>>` in text for special handling (e.g., `"meeting tomorrow <<make formal>>"`)

### UserDefaults Keys

```swift
"apiKey", "selectedModel", "systemPrompt", "globalShortcut",
"excludedApps", "openOnStartup", "reasoningEffort"
```

### Log Locations

- Success: `~/Library/Application Support/Luzia/Evals/evals_log.tsv`
- Errors: `~/Library/Application Support/Luzia/Evals/evals_errors.tsv`

## Common Tasks

### Adding a New Model

1. Update `AppState.availableModels`
2. If reasoning-capable, update `OpenAIService.isReasoningSupported()`

### Adjusting Timing

All timing in `AppDelegate.handleHotKeyPressed()`:
- Pre-paste: 50ms (short) / 150ms (long >120 chars)
- Post-paste: 300ms (short) / 800ms (long)
- Clipboard polling: 50ms intervals, 1.5s timeout in `ClipboardManager.waitForChange()`

### Testing Copy/Paste

1. Grant Accessibility permissions
2. Select text in any app (TextEdit works well)
3. Press ⇧⌘G
4. Watch console logs for execution trace

## Known Issues

See **TODO.md** for the complete bug tracker. Critical issues:

1. **Startup at Login broken** - Missing CFBundleIdentifier, force unwrap crash risk, state sync issues
2. **Rich text formatting lost** - `clearContents()` called before `getRichText()` in ClipboardManager
3. **Right-click menu breaks** - Menu set to nil when showing popover, never restored
4. **Accessibility prompts repeated** - Checks with prompt on every operation, no caching

## Permissions

- **Accessibility:** Required for menu automation and CGEvent simulation
- **Notifications:** Optional, for error/success messages

Requested on first launch in `AppDelegate.applicationDidFinishLaunching()`.
