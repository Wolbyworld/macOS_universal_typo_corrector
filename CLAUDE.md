# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Luzia Universal Typo Correcter is a lightweight macOS menubar application that corrects typos and grammatical errors in any text field system-wide using OpenAI's API. It uses Swift + SwiftUI and operates as an LSUIElement agent app (no Dock icon).

**Key Technologies:**
- Swift 5.5+ / SwiftUI
- macOS 11.0+ (supports through macOS 14+)
- OpenAI Responses API (https://api.openai.com/v1/responses)
- Sparkle framework for auto-updates
- Carbon APIs for global hotkeys
- Accessibility APIs for copy/paste automation

## Build & Development Commands

### Building
```bash
# Open in Xcode
open "Luzia Universal Typo Correcter.xcodeproj"

# Build from command line (if needed)
xcodebuild -project "Luzia Universal Typo Correcter.xcodeproj" \
  -scheme "Luzia Universal Typo Correcter" \
  -configuration Release
```

### Quick Deployment Script
```bash
# Use the included deployment script for rapid testing
./quick-deploy.sh   # Builds and launches the app
```

### Running Tests
```bash
# Run unit tests
xcodebuild test -project "Luzia Universal Typo Correcter.xcodeproj" \
  -scheme "Luzia Universal Typo Correcter" \
  -destination 'platform=macOS'
```

### Viewing Logs
```bash
# Watch application logs in real-time
./watch-logs.sh

# Or manually view console logs filtered to the app
log stream --predicate 'subsystem contains "luzia"' --level debug
```

### Checking Setup
```bash
# Verify Xcode configuration
./check-setup.sh
```

## Architecture

### App Type & Design
- **Agent Application** with `LSUIElement = true` in Info.plist
- No Dock icon, runs in background, only visible as menu bar icon
- Uses `NSApp.setActivationPolicy(.accessory)` for proper agent behavior
- **Critical Issue:** `LSUIElement` agent apps can have compatibility issues with `SMAppService.mainApp` on macOS 13+ (see Bug #1)

### Core Workflow

The app operates through a carefully orchestrated copy-correct-paste workflow (`AppDelegate.handleHotKeyPressed()` at line 153):

```
1. HotKey triggered → handleHotKeyPressed() (AppDelegate.swift:153)
   ↓
2. Check if app is excluded (isExcludedApp)
   ↓
3. Save current clipboard contents (ClipboardManager.saveCurrentClipboard)
   - Deep copy of all pasteboard items to preserve all data types
   ↓
4. Copy selected text via:
   - Primary: Accessibility API → Menu Bar → Edit → Copy (performAccessibilityAction)
   - Fallback: CGEvent simulation (simulateCopyKeypress)
   ↓
5. Wait for clipboard change (ClipboardManager.waitForChange)
   - Polling with 50ms intervals, 1.5s timeout
   - Detects change via NSPasteboard.changeCount
   ↓
6. Retrieve copied text from clipboard (ClipboardManager.getClipboardText)
   ↓
7. Send to OpenAI API (OpenAIService.correctText)
   - Endpoint: https://api.openai.com/v1/responses
   - Headers: Bearer token, OpenAI-Beta: responses=v1
   - Body: model, instructions, input, max_output_tokens, reasoning (if gpt-5)
   - Retry logic: If 400 + reasoning unsupported, retry without reasoning
   - Retry logic: If 200 but incomplete (max_output_tokens), retry without reasoning
   ↓
8. Receive corrected text
   ↓
9. Put corrected text in clipboard (ClipboardManager.setClipboardText)
   - ⚠️ BUG HERE: Tries to preserve formatting but logic is broken (Bug #2)
   ↓
10. Dynamic pre-paste delay (50-150ms based on text length)
   ↓
11. Paste via:
    - Primary: Accessibility API → Menu Bar → Edit → Paste
    - Fallback: CGEvent simulation (simulatePasteKeypress)
    ↓
12. Dynamic post-paste delay (300-800ms based on text length)
   ↓
13. Restore original clipboard (ClipboardManager.restoreOriginalClipboardIfNeeded)
   ↓
14. Log success to EvalLogger (TSV format)
```

**Key Timing Parameters:**
- Clipboard polling: 50ms intervals, 1.5s timeout
- Pre-paste delay: 50ms (short text), 150ms (long text >120 chars)
- Post-paste delay: 300ms (short text), 800ms (long text >120 chars)
- Paste cooldown: 1.0s between fallback paste attempts

### Key Components

**AppDelegate.swift** (21KB, ~490 lines)
- Central coordinator for the entire application
- Manages menubar UI, hotkey registration, and permission checks
- Orchestrates the copy-correct-paste workflow with dual-path fallback:
  - Primary: Accessibility API menu item simulation (`performAccessibilityAction`)
  - Fallback: CGEvent keypress simulation (`simulateCopyKeypress`, `simulatePasteKeypress`)
- Handles startup management via Combine observers
- Uses `isProcessing` flag to prevent concurrent corrections

**ClipboardManager.swift** (8KB, ~190 lines)
- Deep copies clipboard items before modification to preserve all data types
- Attempts rich text (RTF/HTML) preservation during correction
- Polls `NSPasteboard.changeCount` to detect when copy operations complete
- **Known Issue:** Rich text preservation logic in `setClipboardText()` has a bug where it calls `getRichText()` AFTER clearing the clipboard (see TODO.md bug #2)

**OpenAIService.swift** (11KB, ~240 lines)
- Implements OpenAI Responses API client (not Chat Completions)
- Supports GPT-5 models with reasoning effort control (low/medium/high)
- Handles two retry scenarios:
  1. If 400 error mentions "reasoning.effort" → retry without reasoning
  2. If 200 but status="incomplete" due to max_output_tokens → retry without reasoning
- Logs successful corrections to EvalLogger

**AppState.swift** (4KB, ~110 lines)
- ObservableObject holding all user preferences (API key, model, prompt, etc.)
- Automatically syncs with UserDefaults via Combine publishers
- Default system prompt includes special `<<inline instructions>>` feature for user commands
- Available models: gpt-5-mini, gpt-5, gpt-5-nano, gpt-4.1, gpt-4.1-mini

**HotKey.swift** (4KB, ~135 lines)
- Wraps Carbon Event Manager APIs for global hotkey registration
- Currently hardcoded to ⇧⌘G (not yet customizable in UI)
- Uses EventHotKeyRef for system-wide key capture

**StartupManager.swift** (4KB, ~115 lines)
- Handles "Launch at Login" functionality
- Dual implementation: SMAppService (macOS 13+) / SMLoginItemSetEnabled (macOS 11-12)
- **Known Issue:** Has force-unwrap of Bundle.main.bundleIdentifier (crashes if nil), and startup registration is currently broken (see TODO.md bug #1)

**EvalLogger.swift / ErrorLogger.swift** (3-4KB each)
- Append-only TSV loggers for analytics and debugging
- Logs stored in `~/Library/Application Support/Luzia/Evals/`
- EvalLogger: Records each successful correction (prompt, completion, tokens, model)
- ErrorLogger: Records API failures, AX failures, and retry events

### State Management & Design Patterns

**State Management:**
- **User Preferences:** Managed by `AppState` (ObservableObject) with UserDefaults persistence
- **Clipboard State:** Managed by `ClipboardManager` with originalItems deep copy
- **Processing State:** Simple boolean `isProcessing` in AppDelegate prevents concurrent operations
- **No complex state machine:** Linear async/await workflow in handleHotKeyPressed()

**Design Patterns:**
- **Singleton:** OpenAIService, ClipboardManager, EvalLogger, ErrorLogger
- **Observer:** Combine publishers for AppState changes, startup preference observer (AppDelegate:454-487)
- **Delegate:** AppDelegate (NSApplicationDelegate), UNUserNotificationCenterDelegate
- **Fallback Strategy:** Accessibility API → CGEvent for Copy/Paste (graceful degradation)
- **Polling:** Clipboard change detection with 50ms intervals (ClipboardManager:77-94)
- **Async/Await:** Swift concurrency throughout for non-blocking operations
- **Dispatch Queues:** Background I/O for logging via `ioQueue` (prevents UI blocking)

**UserDefaults Keys:**
```swift
"apiKey"           // String: OpenAI API key
"selectedModel"    // String: Currently selected model (default: "gpt-5-mini")
"systemPrompt"     // String: Custom correction instructions
"globalShortcut"   // String: Keyboard shortcut display (not used for actual binding)
"excludedApps"     // Data: JSON-encoded array of bundle identifiers
"openOnStartup"    // Bool: Launch at login preference
"reasoningEffort"  // String: "minimum"/"low"/"medium"/"high"
```

### Error Handling Pattern

The app uses a defensive multi-layer approach:

1. **Graceful fallback:** AX Copy fails → CGEvent Copy (simulateCopyKeypress)
2. **Clipboard polling:** Waits up to 1.5s for clipboard to update (50ms intervals)
3. **API retry logic:**
   - If 400 error mentions "reasoning.effort" → retry without reasoning
   - If 200 but status="incomplete" due to max_output_tokens → retry without reasoning
4. **Notification on failure:** User-facing macOS notifications for critical errors
5. **Clipboard restoration:** Always attempts to restore original clipboard on failure via defer block (AppDelegate:172-186)

**Error Handling Paths:**
- **Copy fails:** Show notification, prompt for Accessibility permissions, call `openAccessibilityPreferences()`
- **API error 401:** Unauthorized - invalid API key notification
- **API error 429:** Rate limit exceeded notification
- **API other errors:** Generic API error with status code
- **Paste fails (AX):** Try CGEvent fallback (simulatePasteKeypress), log to ErrorLogger with stage "ax_paste_failed"
- **Clipboard restore fails:** Log error (⚠️ Bug #8: no user notification, silent data loss possible)

### Permission Requirements

- **Accessibility:** Required for Copy/Paste menu actions and CGEvent simulation
- **Notifications:** Optional, used for error/success messages
- App requests these on first launch via `AppDelegate.applicationDidFinishLaunching()`

## OpenAI API Integration

### Responses API (Not Chat Completions)

This app uses the newer **Responses API** (`/v1/responses`), not the traditional Chat Completions API. Key differences:

- Endpoint: `https://api.openai.com/v1/responses`
- Header: `OpenAI-Beta: responses=v1`
- Body structure:
  ```json
  {
    "model": "gpt-5-mini",
    "instructions": "<system_prompt>",
    "input": "<user_text>",
    "max_output_tokens": 4000,
    "text": { "format": { "type": "text" } },
    "reasoning": { "effort": "low" }  // Optional, GPT-5 only
  }
  ```
- Response parsing: Handles both `output_text` (simple) and `output[].content[]` (complex) response formats

### Model Support

- **GPT-5 models:** gpt-5, gpt-5-mini, gpt-5-nano → support reasoning effort
- **GPT-4.1 models:** gpt-4.1, gpt-4.1-mini → no reasoning support
- Reasoning effort values: minimum → "low", medium → "medium", high → "high"

### Inline Instructions Feature

The default system prompt supports `<<command>>` syntax for inline user instructions:

- Example: `"gonna meet him tomorrow <<make this more formal>>"` → `"I will meet with him tomorrow"`
- Example: `"Meeting at 10PM Madrid tim <<add brazil time>>"` → `"Meeting at 10PM Madrid time (3PM Brazil time)"`
- Instructions override normal preservation rules (can change tone, add info, etc.)

## Common Development Patterns

### Adding a New Model

1. Update `AppState.availableModels` array
2. Update `OpenAIService.isReasoningSupported()` if it's a reasoning model
3. No other changes needed (model is stored as string)

### Modifying the System Prompt

The default prompt is defined in `AppState.defaultSystemPrompt`. Users can override it in Preferences, but the default should be carefully maintained to preserve the inline instructions feature.

### Adjusting Timing/Delays

All timing-critical code is in `AppDelegate.handleHotKeyPressed()`:
- Pre-paste delay: Lines 242-245 (50-150ms based on text length)
- Post-paste delay: Lines 266, 276 (300-800ms based on text length)
- Clipboard polling: `ClipboardManager.waitForChange()` uses 50ms intervals, 1.5s timeout

### Testing Copy/Paste Workflow

1. Ensure Accessibility permissions are granted: System Settings > Privacy & Security > Accessibility
2. Select text in any app (TextEdit works well)
3. Press ⇧⌘G
4. Watch console logs for step-by-step execution trace
5. If AX path fails, CGEvent fallback should trigger automatically

## Known Issues & Technical Limitations

### Critical Bugs (See TODO.md for detailed tracker)

1. **Startup at Login broken** (StartupManager.swift:5, AppDelegate.swift:454-487)
   - Missing CFBundleIdentifier in Info.plist
   - Force unwrap crash risk: `Bundle.main.bundleIdentifier!`
   - State sync issue: `.dropFirst()` skips initial registration
   - No system state verification on app launch
   - LSUIElement + SMAppService compatibility issues on macOS 13+

2. **Rich text formatting lost** (ClipboardManager.swift:136-186)
   - Logic error: `clearContents()` called before `getRichText()`
   - Original formatting destroyed before it can be read
   - Only plain text survives correction

3. **Right-click menu breaks** (AppDelegate.swift:128-143)
   - Menu set to nil when showing popover (line 139)
   - Never restored when popover closes
   - Subsequent right-clicks fail

4. **Attribute range mismatch** (ClipboardManager.swift:153-158)
   - Variable shadowing: callback `range` shadows outer `range`
   - Length mismatch between new/original text
   - Potential crashes with certain text length combinations

5. **Repeated Accessibility prompts** (AppDelegate.swift:312)
   - Checks with prompt on every Copy/Paste operation
   - No permission state caching
   - Multiple interrupting dialogs possible

### Technical Limitations

1. **Clipboard-Based Approach**
   - Temporarily modifies user's clipboard during operation
   - Original clipboard restored after completion
   - **Risk:** If restoration fails, user loses clipboard content (Bug #8)

2. **Timing-Dependent Operations**
   - Relies on fixed/dynamic delays for clipboard and paste operations
   - May fail on slow systems or with certain applications
   - No adaptive timing based on system performance (Bug #7)

3. **Accessibility API Dependency**
   - Requires menu bar automation via AXUIElement
   - Not all apps implement standard Edit menu
   - Falls back to CGEvent keyboard simulation

4. **Formatting Preservation**
   - Attempts to preserve RTF/HTML formatting
   - Currently broken due to logic error (Bug #2)
   - Even when fixed, complex formatting may not transfer perfectly

5. **Agent App Limitations**
   - `LSUIElement = true` means no Dock icon, no standard activation
   - Can cause issues with SMAppService on macOS 13+ (Bug #1)
   - Preferences window uses floating window workaround

## File Locations

### Source Code
- Main app: `Luzia Universal Typo Correcter/*.swift`
- Tests: `Luzia Universal Typo CorrecterTests/*.swift`
- UI Tests: `Luzia Universal Typo CorrecterUITests/*.swift`

### Configuration
- Xcode project: `Luzia Universal Typo Correcter.xcodeproj/`
- Info.plist: `Luzia Universal Typo Correcter/Info.plist`
  - **CRITICAL:** Missing CFBundleIdentifier key (should be `luzia.Luzia-Universal-Typo-Correcter`)
  - Bundle ID defined in Xcode build settings but not explicitly in Info.plist
- Package.swift: Swift Package Manager dependencies (Sparkle)

### Runtime Data
- Eval logs: `~/Library/Application Support/Luzia/Evals/evals_log.tsv`
- Error logs: `~/Library/Application Support/Luzia/Evals/evals_errors.tsv`
- User preferences: `UserDefaults` standard domain

## Development Guidelines

### Code Style
- Use async/await for asynchronous operations (already adopted throughout)
- Extensive console logging for debugging (prefix with component name, e.g., "ClipboardManager:")
- Force unwraps are discouraged (but exist in StartupManager and ClipboardManager - see bugs)

### Testing Accessibility Features
When modifying copy/paste logic:
1. Test with multiple apps (TextEdit, Safari, Xcode, Terminal)
2. Test with excluded apps (preferences UI)
3. Test with various text lengths (timing-sensitive)
4. Test with rich text (bold, italic, links)
5. Monitor clipboard.changeCount behavior

### Debugging

**Log Locations:**
- Success log: `~/Library/Application Support/Luzia/Evals/evals_log.tsv`
- Error log: `~/Library/Application Support/Luzia/Evals/evals_errors.tsv`
- Console: Use `./watch-logs.sh` or `log stream --predicate 'subsystem contains "luzia"' --level debug`

**Key Entry Points for Debugging:**
1. **App Launch:** `Luzia_Universal_Typo_CorrecterApp.swift` → `AppDelegate.applicationDidFinishLaunching`
2. **Hotkey Press:** `HotKey.swift` → `AppDelegate.handleHotKeyPressed()` (line 153)
3. **API Call:** `OpenAIService.correctText()`
4. **Clipboard Save:** `ClipboardManager.saveCurrentClipboard()`
5. **Clipboard Restore:** `ClipboardManager.restoreOriginalClipboardIfNeeded()`
6. **Startup Toggle:** `AppDelegate.handleStartupPreferenceChange()` → `StartupManager.enableStartup()`

**Debugging Tips:**
- All operations log extensively to console with component prefixes (e.g., "ClipboardManager:", "AX Success:")
- Monitor clipboard.changeCount behavior during copy operations
- EvalLogger TSV files can be analyzed for API behavior patterns
- ErrorLogger TSV files track failure modes with stage, model, reasoning_effort, status_code
- Use step-by-step console logs in `handleHotKeyPressed()` to trace workflow execution

## Important Architectural Notes

### Why Responses API instead of Chat Completions?
The app uses OpenAI's newer **Responses API** (`/v1/responses`) rather than the traditional Chat Completions API. This provides:
- Better structured response format with `output_text` field
- Native support for reasoning effort in GPT-5 models
- Completion tracking with status fields (incomplete, max_output_tokens)
- Cleaner API for simple text correction tasks

### Why Clipboard-Based Approach?
The app modifies text by manipulating the clipboard rather than directly editing text fields because:
- Universal compatibility: Works with any app that supports copy/paste
- Leverages host app's undo system: Cmd+Z naturally undoes the paste operation
- Preserves app-specific text handling logic
- No need to interact with app-specific text APIs

**Tradeoff:** Temporarily disrupts user's clipboard (mitigated by saving/restoring)

### Why Accessibility API with CGEvent Fallback?
The dual-path approach provides robustness:
- **Primary (Accessibility API):** More reliable, respects app menus, proper event handling
- **Fallback (CGEvent):** Works when AX fails, requires same permissions, slightly less reliable
- Both paths require Accessibility permissions, so no additional permission burden

### Why Dynamic Delays Based on Text Length?
Different apps handle clipboard operations at different speeds:
- Short text: Most apps handle quickly (50ms pre-paste, 300ms post-paste)
- Long text: Some apps need more time to process (150ms pre-paste, 800ms post-paste)
- Threshold: 120 characters

**Alternative considered:** Event-based approach (e.g., KVO on pasteboard). Rejected due to timing complexity and clipboard API limitations.

### Why TSV Format for Logs?
- **Easy analysis:** Can be opened directly in Excel/Numbers/Google Sheets
- **Append-only:** Simple file I/O with FileHandle, no database needed
- **Tab-separated:** Handles newlines in data (escaped as `\n`)
- **Evaluation-ready:** Direct input for ML evaluation pipelines

### Why Force Unwrap in StartupManager?
**This is a bug** (Bug #1, #9). Bundle.main.bundleIdentifier should never be nil in a properly configured app, but the force unwrap is fragile and crashes have been reported. Needs error handling.

### Why .dropFirst() in Startup Observer?
The intent was to skip the initial value on app launch to avoid triggering registration when loading existing preferences. However, this creates Bug #1's state sync issue. The observer should instead check if actual system state matches desired state and reconcile on launch.
