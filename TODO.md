# Luzia Universal Typo Correcter - Bug Tracker

---

## 📚 Codebase Overview

### Purpose
**Luzia Universal Typo Correcter** is a lightweight macOS menu bar utility that automatically corrects typos, grammatical errors, and awkward phrasing in any text field across the system using OpenAI's API.

### Key Features
- Global keyboard shortcut (Shift+Command+G) to correct selected text
- Uses OpenAI API (Responses endpoint) with user's own API key
- Attempts to preserve text formatting when possible (RTF/HTML)
- Customizable system prompt for correction behavior
- Ability to exclude specific applications
- Auto-update support via Sparkle framework
- Runs as background agent without Dock icon (`LSUIElement = true`)
- Detailed TSV logging for evaluation and error tracking

---

## 🏗️ Architecture Overview

### App Type
- **Agent Application** (`LSUIElement = true` in Info.plist)
- No Dock icon, runs in background
- Only visible as menu bar icon
- Uses `NSApp.setActivationPolicy(.accessory)`

### Technology Stack
- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI + AppKit (hybrid approach)
- **Minimum macOS**: 11.0
- **Key Dependencies**:
  - Sparkle 2.4.0+ (auto-updates)
  - Carbon (global hotkey support)
  - Accessibility Framework (menu automation)
  - ServiceManagement (startup items)

### Bundle Information
- **Bundle Identifier**: `luzia.Luzia-Universal-Typo-Correcter` (defined in Xcode project)
- **⚠️ ISSUE**: CFBundleIdentifier missing from Info.plist (causes startup bugs)

---

## 📁 Core Components

### 1. **AppDelegate.swift** (Main Orchestrator)
- Entry point for application lifecycle
- Handles hotkey registration and triggering
- Manages status bar item and menu
- Orchestrates entire text correction flow
- Implements Accessibility API calls with CGEvent fallbacks
- Key method: `handleHotKeyPressed()` (line 153) - main workflow

### 2. **ClipboardManager.swift** (Clipboard Operations)
- Singleton pattern: `ClipboardManager()`
- Saves/restores clipboard contents
- Polls for clipboard changes (50ms intervals)
- Attempts to preserve RTF/HTML formatting
- **⚠️ CRITICAL BUG**: Rich text preservation logic is broken (Bug #2)

### 3. **OpenAIService.swift** (API Integration)
- Singleton pattern: `OpenAIService()`
- Uses OpenAI Responses API endpoint (`/v1/responses`)
- Supports multiple models: gpt-5-mini, gpt-5, gpt-5-nano, gpt-4.1, gpt-4.1-mini
- Optional reasoning effort parameter (low/medium/high) for gpt-5 models
- Graceful fallback: retries without reasoning if 400 error
- Handles incomplete responses (max_output_tokens exceeded)

### 4. **AppState.swift** (State Management)
- ObservableObject using Combine
- Persists to UserDefaults
- Tracks: API key, system prompt, model, excluded apps, startup preference, reasoning effort
- Syncs changes to UserDefaults automatically

### 5. **HotKey.swift** (Global Keyboard Shortcut)
- Lightweight Carbon Event Manager wrapper
- Registers Shift+Command+G globally
- Works without app focus

### 6. **StartupManager.swift** (Login Items)
- Modern path (macOS 13+): `SMAppService.mainApp`
- Legacy path (macOS 11-12): `SMLoginItemSetEnabled`
- **⚠️ CRITICAL BUG**: Multiple issues prevent startup from working (Bug #1)

### 7. **EvalLogger.swift** (Success Logging)
- Singleton pattern: `EvalLogger.shared`
- TSV format: `~/Library/Application Support/Luzia/Evals/evals_log.tsv`
- Columns: timestamp, prompt, completion, system_prompt, model, tokens_in, tokens_out, reasoning_effort
- Logs every successful correction for evaluation dataset

### 8. **ErrorLogger.swift** (Error Logging)
- Singleton pattern: `ErrorLogger.shared`
- TSV format: `~/Library/Application Support/Luzia/Evals/evals_errors.tsv`
- Columns: timestamp, stage, model, reasoning_effort, input_len, status_code, reason, details
- Logs key failure modes: API errors, paste failures, etc.

### 9. **PreferencesView.swift** (Settings UI)
- SwiftUI view with 3 tabs: General, Excluded Apps, About
- Settings: API key, model selection, system prompt, startup behavior
- Floating window approach (no Dock activation)

### 10. **PopoverView.swift** (Quick Status)
- Shows API key status, current model, keyboard shortcut
- Displayed on left-click of menu bar icon

---

## 🔄 Text Correction Flow (Critical Understanding)

This is the **core workflow** that executes when user presses Shift+Command+G:

```
1. HotKey triggered → handleHotKeyPressed() (AppDelegate.swift:153)
   ↓
2. Check if app is excluded (AppDelegate.swift:158)
   ↓
3. Save current clipboard contents (ClipboardManager.saveCurrentClipboard)
   ↓
4. Copy selected text via:
   - Primary: Accessibility API → Menu Bar → Edit → Copy (performAccessibilityAction)
   - Fallback: CGEvent simulation (simulateCopyKeypress)
   ↓
5. Wait for clipboard change (ClipboardManager.waitForChange)
   - Polling with 50ms intervals, 1.5s timeout
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
14. Log success to EvalLogger
```

### Key Timing Parameters
- **Clipboard polling**: 50ms intervals, 1.5s timeout
- **Pre-paste delay**: 50ms (short text), 150ms (long text >120 chars)
- **Post-paste delay**: 300ms (short text), 800ms (long text >120 chars)
- **Paste cooldown**: 1.0s between fallback paste attempts

### Error Handling Paths
- **Copy fails**: Show notification, prompt for Accessibility permissions
- **API error**: Show notification with error type (401, 429, etc.)
- **Paste fails**: Try CGEvent fallback, log error to ErrorLogger
- **Clipboard restore fails**: Log error, notify user (⚠️ BUG: not implemented fully)

---

## 🔐 Permissions Required

### Accessibility
- **Purpose**: Automate Edit menu (Copy/Paste) via AXUIElement
- **Prompt**: Shown on first Copy/Paste attempt
- **Check location**: `AppDelegate.swift:37-42, 312-316`
- **⚠️ BUG**: Permission checked with prompt on every operation (Bug #5)

### User Notifications
- **Purpose**: Show errors and status messages
- **Requested**: `AppDelegate.swift:27-28`

---

## 📊 Data Storage

### UserDefaults Keys
```swift
"apiKey"           // String: OpenAI API key
"selectedModel"    // String: Currently selected model (default: "gpt-5-mini")
"systemPrompt"     // String: Custom correction instructions
"globalShortcut"   // String: Keyboard shortcut display (not used for actual binding)
"excludedApps"     // Data: JSON-encoded array of bundle identifiers
"openOnStartup"    // Bool: Launch at login preference
"reasoningEffort"  // String: "minimum"/"low"/"medium"/"high"
```

### Log Files
- **Success log**: `~/Library/Application Support/Luzia/Evals/evals_log.tsv`
- **Error log**: `~/Library/Application Support/Luzia/Evals/evals_errors.tsv`

---

## 🎨 Design Patterns

| Pattern | Implementation |
|---------|-----------------|
| **Singleton** | OpenAIService, ClipboardManager, EvalLogger, ErrorLogger |
| **Observer** | Combine publishers for AppState changes, startup preference observer |
| **Delegate** | AppDelegate (NSApplicationDelegate), UNUserNotificationCenterDelegate |
| **Fallback** | Accessibility API → CGEvent for Copy/Paste (graceful degradation) |
| **Polling** | Clipboard change detection with 50ms intervals |
| **Async/Await** | Swift concurrency for non-blocking operations |
| **Dispatch Queues** | Background I/O for logging (`ioQueue`) |

---

## ⚠️ Known Technical Limitations

### 1. **Clipboard-Based Approach**
- Temporarily modifies user's clipboard during operation
- Original clipboard is restored after completion
- **Risk**: If restoration fails, user loses clipboard content (Bug #8)

### 2. **Timing-Dependent Operations**
- Relies on fixed/dynamic delays for clipboard and paste operations
- May fail on slow systems or with certain applications
- No adaptive timing based on system performance (Bug #7)

### 3. **Accessibility API Dependency**
- Requires menu bar automation via AXUIElement
- Not all apps implement standard Edit menu
- Falls back to CGEvent keyboard simulation

### 4. **Formatting Preservation**
- Attempts to preserve RTF/HTML formatting
- **⚠️ Currently broken** due to logic error (Bug #2)
- Even when fixed, complex formatting may not transfer perfectly

### 5. **Agent App Limitations**
- `LSUIElement = true` means no Dock icon, no standard activation
- Can cause issues with SMAppService on macOS 13+ (Bug #1)
- Preferences window uses floating window workaround

---

## 🔧 Development Environment

### Files to Ignore
- `.build/` - Swift Package Manager build artifacts
- `build/` - Xcode build products
- `.DS_Store` - macOS Finder metadata
- `*.xcuserdata` - User-specific Xcode settings

### Build Configuration
- **Xcode Project**: `Luzia Universal Typo Correcter.xcodeproj`
- **Swift Package**: `Package.swift` (primarily for Sparkle dependency)
- **Bundle ID**: Defined in project settings, not in Info.plist (Bug #9)

---

## 🐛 Critical Insights for Bug Fixing

### Startup Bug (Bug #1)
- Root issue: CFBundleIdentifier missing from Info.plist
- Force unwrap in StartupManager will crash if bundle ID is nil
- State sync issue: `.dropFirst()` skips initial registration
- No verification of actual system state vs. UserDefaults

### Rich Text Bug (Bug #2)
- Logic error: Clears clipboard before reading original formatting
- Fix: Must call `getRichText()` BEFORE `clearContents()`

### Menu Bar Bug (Bug #3)
- Menu set to nil when showing popover, never restored
- Fix: Use popover delegate or restore menu after popover closes

### Range Bug (Bug #4)
- Variable shadowing: `range` callback parameter shadows outer `range`
- Length mismatch: New text length vs. original text length
- Fix: Rename callback variable, handle length differences

---

## 📞 Key Entry Points for Debugging

1. **App Launch**: `Luzia_Universal_Typo_CorrecterApp.swift` → `AppDelegate.applicationDidFinishLaunching`
2. **Hotkey Press**: `HotKey.swift` → `AppDelegate.handleHotKeyPressed()`
3. **API Call**: `OpenAIService.correctText()`
4. **Clipboard Save**: `ClipboardManager.saveCurrentClipboard()`
5. **Clipboard Restore**: `ClipboardManager.restoreOriginalClipboardIfNeeded()`
6. **Startup Toggle**: `AppDelegate.handleStartupPreferenceChange()` → `StartupManager.enableStartup()`

---

## Critical Bugs

### 1. ⚠️ Startup at System Login Not Working
**Location:** `StartupManager.swift`, `Info.plist`, `AppDelegate.swift:454-487`
**Severity:** CRITICAL
**Status:** 🔴 Not Working

**Root Causes:**
1. **Missing CFBundleIdentifier in Info.plist**
   - Info.plist is missing the `CFBundleIdentifier` key entirely
   - While Xcode build settings have `PRODUCT_BUNDLE_IDENTIFIER = "luzia.Luzia-Universal-Typo-Correcter"`, the Info.plist should explicitly declare it
   - This can cause issues with ServiceManagement framework

2. **Force Unwrap Crash Risk** (`StartupManager.swift:5`)
   ```swift
   private let bundleIdentifier = Bundle.main.bundleIdentifier!
   ```
   - If bundle identifier is nil, app will crash on startup
   - No graceful error handling

3. **State Synchronization Issue** (`AppDelegate.swift:457`)
   - Observer uses `.dropFirst()` which skips initial value
   - If user has `openOnStartup = true` in UserDefaults but system login item is not registered, nothing triggers registration on app launch
   - App state can become out of sync with actual system state

4. **No System State Verification**
   - App never verifies if it's actually registered as a login item on launch
   - If user manually removes app from System Settings > Login Items, app still shows toggle as "on"
   - No reconciliation between UserDefaults and actual system state

5. **LSUIElement + SMAppService Issues**
   - Apps with `LSUIElement = true` (agent apps without Dock icon) can have compatibility issues with `SMAppService.mainApp` on macOS 13+
   - May require additional entitlements or configuration

**Fix Required:**
- [ ] Add CFBundleIdentifier to Info.plist
- [ ] Remove force unwrap, add error handling
- [ ] Add system state verification on app launch
- [ ] Sync UserDefaults with actual system state
- [ ] Consider alternative approach for LSUIElement apps
- [ ] Test on macOS 11, 12, 13, and 14+

---

### 2. 🔴 Rich Text Formatting Lost During Correction
**Location:** `ClipboardManager.swift:136-186`
**Severity:** HIGH
**Status:** 🔴 Broken

**Issue:**
The `setClipboardText()` method attempts to preserve rich text formatting (bold, italic, fonts, colors) but has a critical logic error:

```swift
func setClipboardText(_ text: String) {
    pasteboard.clearContents()  // Line 140: Clears clipboard

    pasteboard.setString(text, forType: .string)  // Line 143: Sets new plain text

    if let originalRichText = getRichText() {  // Line 147: Tries to read rich text
        // But at this point, the original formatting is GONE!
```

**Root Cause:**
1. Clears clipboard (destroys original formatting)
2. Writes new plain text
3. THEN tries to read original rich text (which no longer exists)

**Impact:**
- All rich text formatting is permanently lost during correction
- Only plain text is preserved
- User loses bold, italic, fonts, colors, etc.

**Fix Required:**
- [ ] Call `getRichText()` BEFORE `clearContents()`
- [ ] Store formatting in a variable
- [ ] Apply stored formatting to corrected text

---

### 3. 🟠 Menu Bar Right-Click Breaks After First Popover Use
**Location:** `AppDelegate.swift:128-143`
**Severity:** MEDIUM
**Status:** 🔴 Broken after first use

**Issue:**
```swift
@objc private func togglePopover(sender: AnyObject?) {
    if let event = NSApp.currentEvent, event.type == .rightMouseUp {
        statusItem.menu?.popUp(...)  // Right-click shows menu
        return
    }

    if let button = statusItem.button {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            statusItem.menu = nil  // Line 139: Menu set to nil
            popover.show(...)
        }
    }
}
```

**Root Cause:**
- When showing popover, `statusItem.menu` is set to `nil` (line 139)
- Menu is never restored when popover closes
- Subsequent right-clicks fail because `statusItem.menu` is nil

**Impact:**
- Right-click functionality stops working after first left-click on menu bar icon
- User must restart app to regain right-click access

**Fix Required:**
- [ ] Restore menu when popover closes
- [ ] Use popover delegate to handle cleanup
- [ ] Or use different approach to handle left vs right click

---

### 4. 🟠 Attribute Range Mismatch in Rich Text Preservation
**Location:** `ClipboardManager.swift:153-158`
**Severity:** MEDIUM
**Status:** 🔴 Unreliable, potential crash

**Issue:**
```swift
let range = NSRange(location: 0, length: min(text.count, originalRichText.length))
originalRichText.enumerateAttributes(in: range, options: []) { attributes, range, _ in
    attributedString.addAttributes(attributes, range: range)
}
```

**Root Causes:**
1. Uses `text.count` (new text length) vs `originalRichText.length` (original length)
2. If corrected text is longer, extra characters get no formatting
3. If corrected text is shorter, applying attributes beyond text length could crash
4. The `range` parameter in enumeration callback shadows outer `range`, causing attributes to be applied to arbitrary subranges of the new text

**Impact:**
- Formatting preservation is unreliable
- Potential crashes with certain text length combinations
- Inconsistent formatting results

**Fix Required:**
- [ ] Fix range calculation logic
- [ ] Rename callback parameter to avoid shadowing
- [ ] Handle length mismatches gracefully
- [ ] Add bounds checking

---

## Medium Priority Bugs

### 5. 🟡 Repeated Accessibility Permission Prompts
**Location:** `AppDelegate.swift:312`
**Severity:** LOW
**Status:** 🟠 Annoying UX

**Issue:**
```swift
guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) else {
```

**Root Cause:**
- Checks permissions with prompt option on every Copy and Paste operation
- Can show system dialog multiple times during single correction attempt
- No caching of permission state

**Impact:**
- Poor user experience if permissions aren't granted
- Multiple interrupting system dialogs

**Fix Required:**
- [ ] Check permissions once at app launch
- [ ] Cache permission state
- [ ] Only prompt when actually needed
- [ ] Use `kAXTrustedCheckOptionPrompt: false` for ongoing checks

---

### 6. 🟡 Force Unwrap in ClipboardManager
**Location:** `ClipboardManager.swift:36`
**Severity:** LOW
**Status:** 🟠 Fragile

**Issue:**
```swift
if !(self.originalItems?.isEmpty ?? true) {
    print("ClipboardManager: Saved \(self.originalItems!.count) clipboard items...")
```

**Root Cause:**
- Force unwrap in print statement
- While logically safe due to conditional, fragile if code is refactored

**Impact:**
- Potential crash if conditional logic changes
- Code smell / maintenance risk

**Fix Required:**
- [ ] Use optional binding or nil-coalescing

---

## Potential Issues / Technical Debt

### 7. ⚪ Better Error Visibility When API Key Missing
**Location:** `AppDelegate.swift`, `OpenAIService.swift`
**Severity:** LOW
**Status:** 🟡 Error handled but could be more visible

**Issue:**
- When API key is missing, error is thrown and shown in notification
- Error is now logged to errors.tsv (after recent fix)
- However, notification might be missed by user
- No persistent indicator in menu bar when key is missing

**Current Behavior:**
- User presses Shift+Cmd+G
- Error notification appears: "OpenAI API key is not set. Please add it in Preferences."
- Error logged to `evals_errors.tsv`
- No visual feedback in menu bar icon

**Potential Improvements:**
- [ ] Show warning icon in menu bar when key is missing on app launch
- [ ] Add API key status to popover (currently shows "API Key: Set/Not Set" but not prominent)
- [ ] Consider persistent notification or alert sheet instead of toast
- [ ] Add first-run experience to prompt for API key setup

**Impact:**
- Low severity - error is handled correctly
- Just a UX improvement opportunity for better discoverability

---

### 8. ⚪ Brittle Timing Dependencies
**Location:** Multiple files
**Severity:** LOW
**Status:** 🟡 Works but fragile

**Areas:**
1. **Dynamic delays** (`AppDelegate.swift:243-245, 266-267, 276-277`)
   - Pre-paste and post-paste delays based on text length
   - May fail on slow systems or with certain apps

2. **Clipboard polling** (`ClipboardManager.swift:77-94`)
   - 50ms polling interval with 1.5s timeout
   - Could fail with slow clipboard operations

**Impact:**
- May fail intermittently on slow systems
- No adaptive timing based on system performance

**Fix Consideration:**
- [ ] Consider event-based approach instead of polling
- [ ] Add adaptive timing based on historical performance
- [ ] Increase timeouts for reliability

---

### 9. ⚪ No Clipboard Recovery After Failure
**Location:** `AppDelegate.swift:172-186`
**Severity:** LOW
**Status:** 🟡 User clipboard lost on error

**Issue:**
```swift
defer {
    if success {
        print("Text correction process completed successfully")
    } else {
        print("Text correction process failed or aborted")
        Task {
            do {
               try await clipboardManager.restoreOriginalClipboardIfNeeded()
            } catch {
                print("Error restoring original clipboard after failure: \(error)")
            }
        }
    }
    resetState()
}
```

**Root Cause:**
- If restoration fails, error is only logged
- User's original clipboard content is permanently lost
- No user notification of clipboard loss

**Impact:**
- Silent data loss if restoration fails
- User may lose important clipboard content

**Fix Required:**
- [ ] Notify user if clipboard restoration fails
- [ ] Consider persistent clipboard backup
- [ ] Add retry logic for restoration

---

### 10. ⚪ Missing CFBundleIdentifier Validation
**Location:** `Info.plist`, `StartupManager.swift`
**Severity:** MEDIUM
**Status:** 🟠 Missing validation

**Issue:**
- Info.plist completely missing CFBundleIdentifier key
- No validation that bundle identifier exists before use
- Force unwrap crashes if identifier is nil

**Fix Required:**
- [ ] Add CFBundleIdentifier to Info.plist explicitly:
  ```xml
  <key>CFBundleIdentifier</key>
  <string>luzia.Luzia-Universal-Typo-Correcter</string>
  ```
- [ ] Add validation and graceful error handling

---

## Bug Priority Summary

| Priority | Count | Status |
|----------|-------|--------|
| 🔴 Critical | 4 | Need immediate fix |
| 🟠 Medium | 2 | Should fix soon |
| 🟡 Low | 4 | Technical debt |

---

## Testing Checklist

After fixes, verify:
- [ ] Startup at system login works on macOS 11, 12, 13, 14+
- [ ] Rich text formatting preserved (bold, italic, fonts, colors)
- [ ] Right-click menu works after using left-click popover
- [ ] No crashes with varying text lengths
- [ ] Single accessibility permission prompt per session
- [ ] Clipboard restored after failures
- [ ] State syncs between app and System Settings

---

**Last Updated:** 2026-01-10
**App Version:** 1.0 (Build 1)
