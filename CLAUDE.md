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

**Models:** openai/gpt-oss-20b, openai/gpt-oss-120b (Groq-hosted, fast inference), gpt-5, gpt-5-mini, gpt-5-nano (reasoning supported), gpt-4.1, gpt-4.1-mini

**Groq models:** The `openai/gpt-oss-*` models are routed through Groq's infrastructure by the backend automatically. No client-side changes needed for routing.

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

1. Add model ID to `AppState.availableModels`
2. Add display name to `AppState.modelDisplayNames` (e.g., `"model-id": "Friendly Name"`)
3. If reasoning-capable (gpt-5 prefix), `OpenAIService.isReasoningSupported()` handles it automatically

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

### Creating a Distribution DMG

```bash
./create-dmg.sh [output-name]  # Default: Luzia-Enterprise
```

The script creates a styled DMG with:
- Dark gradient background with drag-to-install arrow
- App icon on left, Applications folder on right
- Professional installer appearance

**Files:**
- `create-dmg.sh` - Main DMG creation script (uses AppleScript for Finder customization)
- `dmg-resources/generate-background.swift` - Generates background image (pure Swift, no dependencies)
- `dmg-resources/dmg-background.png` - 660x400 background image

**Customizing DMG appearance:** Edit variables at top of `create-dmg.sh`:
- `WINDOW_WIDTH/HEIGHT` - Window dimensions (must match background image)
- `APP_ICON_X/Y`, `APPS_ICON_X/Y` - Icon positions
- `ICON_SIZE` - Icon size (default: 100)

To regenerate background: `swift dmg-resources/generate-background.swift`

## Enterprise Build & Deployment

### Build Scripts

| Script | Purpose |
|--------|---------|
| `build-enterprise.sh` | Full enterprise build: compiles app, injects config, creates signed DMG |
| `release.sh` | Creates versioned releases with Sparkle signing for OTA updates |
| `quick-deploy.sh` | Quick local build and launch for development |
| `create-dmg.sh` | Standalone DMG creation with styled installer |

### Enterprise Build Process

```bash
./build-enterprise.sh
```

This script:
1. Builds Release configuration with `xcodebuild`
2. **Injects enterprise config** into built app's Info.plist via PlistBuddy:
   - `LuziaProxyURL` - Backend proxy URL
   - `LuziaProxySecretHash` - XOR-obfuscated API secret
   - `LuziaEnterpriseMode` - Enables enterprise features
   - `SUFeedURL` - Sparkle appcast URL for OTA updates
   - `SUPublicEDKey` - EdDSA public key for update verification
3. Ad-hoc signs the app with `codesign --force --deep --sign -`
4. Creates DMG with Applications symlink

**Critical:** Xcode strips custom Info.plist keys during build. Enterprise config MUST be injected via PlistBuddy after `xcodebuild` completes, not in the source Info.plist.

### Version Management

**Xcode overrides Info.plist versions.** To change version:
1. Edit `project.pbxproj`:
   - `MARKETING_VERSION` = display version (e.g., "4.0.0")
   - `CURRENT_PROJECT_VERSION` = build number (e.g., 400)
2. Source Info.plist values are ignored during build

### Deployment Chain

```
build-enterprise.sh → GitHub Release → Cloudflare Pages website
                           ↓
                    appcast.xml (OTA updates)
```

1. Build with `./build-enterprise.sh` → outputs `Luzia-Enterprise.dmg`
2. Create GitHub release: `gh release create vX.X.X --title "vX.X.X" --notes "..."`
3. Upload DMG: `gh release upload vX.X.X Luzia-Enterprise.dmg`
4. Website auto-links to latest release (no update needed)

### Website Deployment (Cloudflare Pages)

The website uses GitHub's **latest release URL** which auto-points to newest release:
```
https://github.com/Wolbyworld/macOS_universal_typo_corrector/releases/latest/download/Luzia-Enterprise.dmg
```

**To update the website** (only needed for HTML/CSS changes, not new releases):
```bash
npx wrangler pages deploy website --project-name=luzia-enterprise
```

Website URL: `https://luzia-enterprise.pages.dev`

**Key insight:** The DMG filename must be `Luzia-Enterprise.dmg` in every release for auto-linking to work.

## Over-the-Air (OTA) Updates via Sparkle

### Configuration

Sparkle 2.x is integrated via Swift Package Manager. Key files:

| File | Purpose |
|------|---------|
| `SparkleUpdater.swift` | Updater controller, delegates, "Check for Updates" action |
| `appcast.xml` | Update feed with version info and signatures |
| `Package.swift` | Sparkle dependency declaration |

### Info.plist Keys (injected by build-enterprise.sh)

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/Wolbyworld/macOS_universal_typo_corrector/main/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>6GZWiKhcsOojOzy0S4PWEtOqVzmkD675xYRvAOq/7Kw=</string>
```

### Signing Updates

EdDSA private key is stored in macOS Keychain (created by `generate_keys` tool).

```bash
# Get public key
./.build/artifacts/sparkle/Sparkle/bin/generate_keys -p

# Sign a zip for release
./.build/artifacts/sparkle/Sparkle/bin/sign_update releases/Luzia-X.X.X.zip
# Output: sparkle:edSignature="..." length="..."
```

### Creating a Release with OTA Support

```bash
# 1. Update version in project.pbxproj (MARKETING_VERSION, CURRENT_PROJECT_VERSION)

# 2. Build enterprise version
./build-enterprise.sh

# 3. Create zip from built app (for OTA, separate from DMG)
cd build/Build/Products/Release
zip -r --symlinks ../../../../releases/Luzia-X.X.X.zip "Luzia Universal Typo Correcter.app" -x "*.DS_Store" -x "*._*"

# 4. Sign the zip
./.build/artifacts/sparkle/Sparkle/bin/sign_update releases/Luzia-X.X.X.zip

# 5. Update appcast.xml with new version entry (signature and length from step 4)

# 6. Upload to GitHub
gh release create vX.X.X --title "vX.X.X" --notes "Release notes"
gh release upload vX.X.X releases/Luzia-X.X.X.zip
gh release upload vX.X.X Luzia-Enterprise.dmg

# 7. Commit and push appcast.xml
git add appcast.xml && git commit -m "Release vX.X.X" && git push
```

### appcast.xml Format

```xml
<item>
    <title>Version X.X.X</title>
    <description><![CDATA[Release notes here]]></description>
    <pubDate>Wed, 15 Jan 2026 22:30:00 +0000</pubDate>
    <enclosure
        url="https://github.com/Wolbyworld/macOS_universal_typo_corrector/releases/download/vX.X.X/Luzia-X.X.X.zip"
        sparkle:version="XXX"           <!-- Build number, must be higher than installed -->
        sparkle:shortVersionString="X.X.X"
        sparkle:edSignature="..."       <!-- From sign_update tool -->
        length="..."                    <!-- File size in bytes -->
        type="application/octet-stream"
    />
    <sparkle:minimumSystemVersion>11.0</sparkle:minimumSystemVersion>
</item>
```

### SparkleUpdater.swift Critical Setting

```swift
// MUST be true for updater to work
updaterController = SPUStandardUpdaterController(
    startingUpdater: true,  // false = "updater hasn't been started" error
    updaterDelegate: self,
    userDriverDelegate: self
)
```

## OTA Signature Validation - RESOLVED

**Status:** Fixed in v4.0.3+

**Original symptom:** Sparkle showed "The update is improperly signed and could not be validated."

### Root Causes (all three needed fixing)

1. **Missing Sparkle keys in release zip**: `release.sh` wasn't injecting `SUFeedURL` and `SUPublicEDKey` into the built app before zipping. The keys were in the source Info.plist but Xcode strips custom keys during build.

2. **Broken code signature**: Building with `CODE_SIGNING_ALLOWED=NO` created a corrupt `_CodeSignature` that referenced resources that weren't signed. Error: "code has no resources but signature indicates they must be present"

3. **Resource forks in zip**: Using `ditto` included `._*` macOS resource fork files that corrupted the code signature validation.

### Fixes Applied to release.sh

```bash
# 1. Inject Sparkle keys after build (before zipping)
APP_PLIST="$BUILT_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SUFeedURL string '...'" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string '...'" "$APP_PLIST"

# 2. Re-sign frameworks and app after plist modifications (inside-out)
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$BUILT_APP"

# 3. Use zip instead of ditto (excludes resource forks)
zip -r --symlinks "$ZIP_PATH" "$APP_NAME" -x "*.DS_Store" -x "*._*" -x "*.__*"
```

### Verification Commands

```bash
# Check Sparkle keys in zip
unzip -p releases/Luzia-X.X.X.zip "Luzia Universal Typo Correcter.app/Contents/Info.plist" | grep SUPublicEDKey

# Verify code signature (should say "valid on disk")
TMP=$(mktemp -d) && unzip -q releases/Luzia-X.X.X.zip -d "$TMP" && codesign -vvv "$TMP/Luzia Universal Typo Correcter.app"; rm -rf "$TMP"

# Verify EdDSA signature
./.build/artifacts/sparkle/Sparkle/bin/sign_update releases/Luzia-X.X.X.zip
```

### Key Lessons

- **Don't use `ditto`** for Sparkle zips - it includes resource forks that break signatures
- **Always re-sign after modifying Info.plist** - any plist change invalidates the signature
- **Sign inside-out**: frameworks/XPC services first, then the main app
- **Xcode strips custom Info.plist keys** - must inject via PlistBuddy post-build

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
