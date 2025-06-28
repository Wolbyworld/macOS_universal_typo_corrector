# Luzia Universal Typo Correcter - Project Analysis

## Background and Motivation

Luzia Universal Typo Correcter is a macOS utility application designed to provide system-wide text correction capabilities. The app leverages OpenAI's APIs to automatically fix typos, grammatical errors, and awkward phrasing in any text field across the entire system. It aims to provide a seamless, universal text correction experience that works consistently across all applications.

**Core Value Proposition:**
- Universal text correction without requiring app-specific integrations
- Preserves text formatting when possible
- Uses user's own OpenAI API key for privacy
- Non-intrusive design with global keyboard shortcuts

**Current Enhancement Request:**
Add an "Open on Startup" toggle in settings to allow users to automatically launch the app when they log into macOS. This feature should be disabled by default to respect user choice but provide easy access for users who want the convenience of having the typo corrector always available.

## Key Challenges and Analysis

### Technical Challenges
1. **System-wide Text Access**: Requires Accessibility permissions to intercept and modify text across applications
2. **Rich Text Preservation**: Must maintain formatting (RTF/HTML) when correcting text
3. **Clipboard Management**: Complex clipboard state management to preserve user's original clipboard
4. **Cross-app Compatibility**: Must work reliably across different macOS applications
5. **Permission Management**: Requires careful handling of system permissions
6. **Login Items Management**: Implementing reliable startup behavior using modern macOS APIs

### Architecture Challenges
1. **State Management**: Balancing between local preferences and real-time processing
2. **Error Handling**: Graceful degradation when API calls fail or permissions are denied
3. **Performance**: Minimizing latency during text correction workflow
4. **User Experience**: Providing clear feedback during processing states
5. **Startup Integration**: Seamlessly integrating with macOS login items without disrupting user experience

## Current Project Structure

### Core Application Files
```
Luzia Universal Typo Correcter/
├── Luzia_Universal_Typo_CorrecterApp.swift    # Main app entry point
├── AppDelegate.swift                          # Core app logic and system integration
├── AppState.swift                            # Application state management
├── ContentView.swift                         # Main UI content
├── PreferencesView.swift                     # Settings interface
├── PopoverView.swift                         # Popup interface
└── Assets.xcassets/                          # App icons and images
```

### Service Layer
```
├── OpenAIService.swift                       # API communication with OpenAI
├── ClipboardManager.swift                    # Clipboard operations and state management
├── HotKey.swift                             # Global keyboard shortcut handling
└── SparkleUpdater.swift                     # Auto-update functionality
```

### Configuration & Build
```
├── Package.swift                            # Swift Package Manager dependencies
├── Luzia Universal Typo Correcter.xcodeproj/ # Xcode project configuration
├── Info.plist                              # App metadata and permissions
└── Luzia_Universal_Typo_Correcter.entitlements # App entitlements
```

## Feature Analysis

### ✅ Implemented Features

#### 1. Core Text Correction
- **Global Hotkey**: Default ⇧⌘G (Shift+Command+G) triggers correction
- **Accessibility Integration**: Uses both AX (Accessibility) and CGEvent fallbacks
- **OpenAI Integration**: Supports multiple models (gpt-4.1, gpt-4.5-preview)
- **Clipboard Management**: Sophisticated save/restore mechanism
- **Rich Text Support**: Attempts to preserve RTF/HTML formatting

#### 2. User Interface
- **Menu Bar Integration**: System tray icon with status indication
- **Preferences Window**: Tabbed interface for configuration
- **Status Feedback**: Animated icon during processing
- **Notifications**: macOS native notifications for errors

#### 3. Configuration Management
- **API Key Storage**: Secure storage in UserDefaults
- **Model Selection**: User can choose between available OpenAI models
- **System Prompt Customization**: Editable prompt with reset functionality
- **Excluded Apps**: Users can exclude specific applications

#### 4. System Integration
- **Accessibility Permissions**: Prompts and checks for required permissions
- **Auto-Updates**: Sparkle framework integration
- **Permission Handling**: Graceful degradation when permissions unavailable

### 🔄 Partially Implemented Features

#### 1. Hotkey Customization
- **Current State**: Shows ⇧⌘G as default in UI
- **Missing**: UI for customizing keyboard shortcuts
- **Note**: Backend HotKey.swift supports different key combinations

#### 2. Rich Text Formatting
- **Current State**: Attempts RTF/HTML preservation with best effort
- **Limitations**: Simple attribute application, may not handle complex formatting
- **Fallback**: Falls back to plain text when rich text fails

### ❌ Missing or Incomplete Features

#### 1. Advanced Error Recovery
- **Issue**: Limited retry mechanisms for failed operations
- **Impact**: Users may need to retry manually on temporary failures

#### 2. Usage Analytics
- **Missing**: No usage tracking or success rate monitoring
- **Note**: Intentionally omitted for privacy, but could help with UX improvements

#### 3. Keyboard Shortcut Customization UI
- **Status**: Backend supports it, UI shows placeholder text
- **Priority**: Medium - current default works for most users

## Technical Architecture

### Core Workflow
1. **Hotkey Pressed** → `AppDelegate.handleHotKeyPressed()`
2. **Save Clipboard** → `ClipboardManager.saveCurrentClipboard()`
3. **Copy Text** → Accessibility action or CGEvent fallback
4. **Wait for Clipboard** → `ClipboardManager.waitForChange()`
5. **Extract Text** → `ClipboardManager.getClipboardText()`
6. **Correct Text** → `OpenAIService.correctText()`
7. **Set Corrected Text** → `ClipboardManager.setClipboardText()`
8. **Paste** → Accessibility action or CGEvent fallback
9. **Restore Clipboard** → `ClipboardManager.restoreOriginalClipboardIfNeeded()`

### State Management Pattern
- **AppState**: Observable object with `@Published` properties
- **UserDefaults Integration**: Automatic persistence via Combine publishers
- **Environment Objects**: Shared across SwiftUI views

### Error Handling Strategy
- **Graceful Degradation**: Falls back to simpler methods when advanced features fail
- **User Feedback**: Clear error messages via notifications
- **Permission Prompts**: Automatic prompts for required system permissions

## Dependencies

### External Libraries
- **Sparkle (2.4.0+)**: Auto-update framework
- **Foundation**: Core iOS/macOS APIs
- **AppKit**: macOS-specific UI and system integration
- **SwiftUI**: Modern UI framework
- **Accessibility**: System accessibility APIs
- **Carbon**: Legacy APIs for global hotkeys

### System Requirements
- **macOS 11.0+**: Minimum supported version
- **Accessibility Permissions**: Required for text manipulation
- **Network Access**: Required for OpenAI API calls
- **Notification Permissions**: Optional, for error reporting

## Configuration & Settings

### User Configurable Settings
1. **OpenAI API Key**: Stored securely in UserDefaults
2. **Model Selection**: Choice between available OpenAI models
3. **System Prompt**: Customizable instruction prompt for OpenAI
4. **Excluded Apps**: List of application bundle IDs to skip
5. **Global Shortcut**: Currently fixed to ⇧⌘G (customization planned)

### Default Configuration
```swift
// Default system prompt
"You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.\n\nReturn ONLY the corrected text without explanations or additional commentary."

// Default model
"gpt-4.1"

// Default shortcut
"⇧⌘G" (Shift+Command+G)
```

## High-level Task Breakdown

### Current Project Status
- ✅ **Core functionality implemented and working**
- ✅ **Basic UI and preferences complete**
- ✅ **System integration functional**
- ✅ **Error handling and fallbacks in place**
- 🔄 **Documentation and user onboarding could be improved**
- 🔄 **Advanced features partially implemented**

### Active Enhancement: Open on Startup Feature

**Goal**: Add a user-configurable toggle in preferences to enable/disable automatic startup when the user logs into macOS.

**Implementation Plan**:

#### Task 1: Extend AppState for Startup Preference
- **Objective**: Add state management for the startup preference
- **Details**: 
  - Add `@Published var openOnStartup: Bool = false` to AppState
  - Implement UserDefaults persistence with key "openOnStartup"
  - Add observer to sync changes automatically
- **Success Criteria**: 
  - AppState properly stores and retrieves startup preference
  - Changes persist across app restarts
  - Default value is `false` (disabled by default)

#### Task 2: Implement Login Items Management Service
- **Objective**: Create service to manage macOS login items registration
- **Details**:
  - Create new `StartupManager.swift` class
  - Use `SMAppService` API (modern approach for macOS 13+) with fallback to `LSSharedFileList` for older versions
  - Implement `enableStartup()` and `disableStartup()` methods
  - Add error handling for permission issues
- **Success Criteria**:
  - Service can reliably add/remove app from login items
  - Works on macOS 11+ (app's minimum supported version)
  - Handles errors gracefully with user feedback

#### Task 3: Update Preferences UI
- **Objective**: Add toggle control in the General tab of preferences
- **Details**:
  - Add Toggle("Open on Startup", isOn: $appState.openOnStartup) in PreferencesView
  - Place in appropriate section (likely in General tab after Global Shortcut section)
  - Add descriptive text explaining the feature
  - Bind toggle to state management
- **Success Criteria**:
  - Toggle appears in preferences UI
  - State changes immediately when toggled
  - UI provides clear description of functionality

#### Task 4: Implement Startup Behavior Logic
- **Objective**: Connect UI toggle to actual system behavior
- **Details**:
  - Add observer in AppDelegate for `openOnStartup` changes
  - Call StartupManager methods when preference changes
  - Handle potential failures with user notifications
  - Ensure changes take effect immediately (no restart required)
- **Success Criteria**:
  - Toggling preference immediately adds/removes from login items
  - User receives feedback if operation fails
  - No app restart required for changes to take effect

#### Task 5: Testing and Validation
- **Objective**: Ensure feature works reliably across scenarios
- **Details**:
  - Test on different macOS versions (11.0, 12.0, 13.0+)
  - Test enabling/disabling multiple times
  - Test app actually launches on login when enabled
  - Test app doesn't launch when disabled
  - Test error scenarios (permissions, system limitations)
- **Success Criteria**:
  - Feature works consistently across supported macOS versions
  - App launches silently on startup when enabled
  - No crashes or errors in normal use cases
  - Graceful error handling for edge cases

### Future Enhancement Areas
1. **Keyboard Shortcut Customization**
   - Implement UI for shortcut configuration
   - Add validation for conflicting shortcuts
   
2. **Advanced Rich Text Support**
   - Improve formatting preservation algorithms
   - Add support for more text formats
   
3. **Performance Optimizations**
   - Implement request caching for repeated corrections
   - Add timeout configurations
   
4. **User Experience Improvements**
   - Better onboarding flow
   - In-app help and documentation
   - Usage statistics and feedback

## Project Status Board

### Completed Tasks
- [x] Core text correction workflow
- [x] OpenAI service integration
- [x] Accessibility permissions handling
- [x] Clipboard management with state preservation
- [x] Menu bar integration with status feedback
- [x] Preferences UI with tabbed interface
- [x] App exclusion functionality
- [x] Auto-update integration via Sparkle
- [x] Rich text formatting preservation (basic)
- [x] Error handling and notifications
- [x] **Open on Startup Feature** ✅ **COMPLETE**
  - [x] Task 1: Extend AppState for startup preference
  - [x] Task 2: Implement Login Items Management Service
  - [x] Task 3: Update Preferences UI with toggle
  - [x] Task 4: Implement startup behavior logic
  - [x] Task 5: Testing and validation

### In Progress Tasks
- [ ] None currently active

### Pending Tasks
- [ ] Keyboard shortcut customization UI
- [ ] Advanced rich text formatting improvements
- [ ] Performance optimization and caching
- [ ] Enhanced error recovery mechanisms
- [ ] User onboarding flow improvements

## Current Status / Progress Tracking

**Overall Status**: ✅ **Production Ready** + ✅ **Enhancement Complete**

The application is fully functional with all core features implemented. The codebase is well-structured, follows Swift/SwiftUI best practices, and includes proper error handling. The app successfully provides system-wide text correction capabilities while maintaining good user experience and system integration.

**Latest Enhancement**: Successfully implemented "Open on Startup" feature with full UI integration, system management, and error handling.

**Key Strengths**:
- Robust clipboard management with state preservation
- Comprehensive error handling with graceful fallbacks
- Clean separation of concerns in architecture
- Good accessibility integration
- Secure configuration management
- Well-defined enhancement process

**Known Limitations**:
- Fixed keyboard shortcut (customization UI not implemented)
- Basic rich text formatting preservation  
- No usage analytics or success tracking

## Executor's Feedback or Assistance Requests

**2025-01-27 - Planner Update**: 
- ✅ **Planning Complete** for "Open on Startup" feature
- **Analysis**: Feature requires 5 distinct tasks with clear success criteria
- **Technical Approach**: Using modern `SMAppService` API with fallback to `LSSharedFileList` for broader compatibility
- **Risk Assessment**: Low risk - standard macOS pattern with well-defined APIs
- **Ready for Execution**: All tasks are small, clearly defined, and have testable success criteria

**2025-01-27 - Executor Final Update**:
- ✅ **FEATURE COMPLETE**: All 5 tasks successfully implemented and tested
- **Implementation Summary**: 
  - AppState extended with `openOnStartup` property and UserDefaults persistence
  - StartupManager.swift created with modern/legacy API support and comprehensive error handling
  - PreferencesView updated with clear toggle and description in "App Behavior" section
  - AppDelegate integrated with reactive observer and immediate startup management
  - Full testing completed with user confirmation of functionality
- **Result**: Feature works perfectly with immediate effect, error recovery, and user notifications

## Lessons

### Development Best Practices Learned
- **Accessibility Testing**: Always test with actual accessibility permissions to ensure proper functionality
- **Clipboard Management**: Complex state management required for reliable clipboard operations
- **Error Handling**: Multiple fallback strategies essential for system-level integrations
- **User Feedback**: Clear status indication crucial for operations that take time
- **Permission Handling**: Proactive permission checking and user guidance improves UX

### Technical Insights
- **AX vs CGEvent**: Accessibility framework preferred but CGEvent needed as fallback
- **Rich Text Complexity**: RTF/HTML preservation more complex than initially expected
- **Global Hotkeys**: Carbon framework still needed for reliable global shortcuts
- **SwiftUI + AppKit**: Hybrid approach necessary for system-level macOS apps 