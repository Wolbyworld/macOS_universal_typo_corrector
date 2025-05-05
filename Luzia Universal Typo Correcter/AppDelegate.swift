import SwiftUI
import AppKit
import Sparkle
import UserNotifications
import Accessibility
import Foundation
import Combine
import ServiceManagement
import OSLog
import UniformTypeIdentifiers
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var hotKey: HotKey?
    var composerHotKey: HotKey?
    
    private var clipboardManager = ClipboardManager()
    private var openAIService = OpenAIService()
    private var sparkleUpdater: SparkleUpdater?
    private var isProcessing = false
    private var screenshotManager = ScreenshotManager()
    public var toastManager = ToastManager()
    public var appState = AppState()
    
    // Current composer session data
    private var currentScreenshots: [NSImage] = []
    private var screenshotPaths: [String] = []
    private var activeWindowInfo: (windowID: CGWindowID, appName: String, windowTitle: String)?
    private var bulletPoints: String = ""
    private var composerWindowController: ComposerWindowController?
    
    // Store a reference to prevent premature deallocation
    private var toastWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        // Explicitly ensure no toast is showing on startup
        toastManager.hideToast()
        
        setupMenuBarItem()
        
        // Reset and setup hotkeys to ensure they're properly registered
        setupHotKey()
        
        // Configure window behavior
        configureWindowBehavior()
        
        // Initialize Sparkle
        sparkleUpdater = SparkleUpdater()
        
        // Check for accessibility permissions but don't prompt on startup
        checkAccessibilityPermissions(showPrompt: false)
        
        // Add menu items to enable preferences access
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Add option to show main window
        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: ""))
        
        // Add option to reset hotkeys
        menu.addItem(NSMenuItem(title: "Reset Keyboard Shortcuts", action: #selector(resetHotkeys), keyEquivalent: ""))
        
        // Model selection section
        let currentModelItem = NSMenuItem(title: "Current Model: \(appState.selectedModel)", action: nil, keyEquivalent: "")
        currentModelItem.isEnabled = false
        menu.addItem(currentModelItem)
        
        for model in appState.availableModels {
            let item = NSMenuItem(title: model, action: #selector(selectModel(_:)), keyEquivalent: "")
            item.representedObject = model
            item.state = appState.selectedModel == model ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? String else { return }
        appState.selectedModel = model
        setupMenu() // Refresh menu to update checkmarks
    }
    
    @objc public func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        
        // If the above doesn't work, try a direct approach
        let prefWindowController = NSWindowController(
            window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
        )
        
        prefWindowController.window?.center()
        prefWindowController.window?.title = "Preferences"
        prefWindowController.contentViewController = NSHostingController(
            rootView: PreferencesView().environmentObject(appState)
        )
        prefWindowController.showWindow(nil)
    }
    
    @objc private func checkForUpdates() {
        sparkleUpdater?.checkForUpdates()
    }
    
    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "textformat.abc.dottedunderline", accessibilityDescription: "Luzia Typo Correcter")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView().environmentObject(appState))
    }
    
    @objc private func togglePopover(sender: AnyObject?) {
        // If right click, show the menu instead of the popover
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: statusItem.button)
            return
        }
        
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // If the app is hidden (minimized to menu bar), make it visible again
                if !NSApp.isActive {
                    unhideApp()
                }
                
                statusItem.menu = nil // Clear the menu when showing popover
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    // Method to unhide (show) the app when clicking menu bar icon
    private func unhideApp() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure the main window is visible
        for window in NSApp.windows where window.isVisible == false {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func showMainWindow() {
        unhideApp()
    }
    
    private func setupHotKey() {
        // First, check if we already have the permissions without prompting
        let hasPermission = checkAccessibilityPermissions(showPrompt: false)
        
        // Unregister any existing hotkeys first
        hotKey = nil
        composerHotKey = nil
        
        // Wait a moment to ensure previous hotkeys are fully unregistered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Try registering the typo correction hotkey with a slightly different technique
            print("Attempting to register typo correction hotkey with alternative approach")
            
            // Instead of using the convenience modifiers array, use the raw modifier flags
            // This sometimes works when the array approach doesn't
            var carbonModifiers: UInt32 = 0
            carbonModifiers |= UInt32(cmdKey)
            carbonModifiers |= UInt32(shiftKey)
            
            // For diagnostic purposes, also try registering with a different key (F instead of G)
            // to see if the problem is with the specific key
            self.hotKey = HotKey(key: .f, modifiers: [.shift, .command], identifier: 0)
            self.hotKey?.keyDownHandler = { [weak self] in
                print("Command+Shift+F key pressed - trigger typo correction")
                self?.handleHotKeyPressed()
            }
            
            // New shortcut: ⇧⌘M for composer with different identifier
            self.composerHotKey = HotKey(key: .m, modifiers: [.shift, .command], identifier: 1)
            self.composerHotKey?.keyDownHandler = { [weak self] in
                print("Command+Shift+M key pressed - trigger composer")
                self?.handleComposerHotKeyPressed()
            }
            
            // Only show a prompt if we don't have permission AND we're trying to register hotkeys
            if !hasPermission {
                print("No accessibility permission, will ask user when they try to use hotkeys")
            } else {
                print("Hotkeys registered: Command+Shift+F for correction, Command+Shift+M for composer")
                
                // Show a notification to inform the user about the key change
                self.showNotification(
                    "Keyboard Shortcut Changed",
                    "We've changed the typo correction shortcut to Command+Shift+F to resolve a conflict"
                )
            }
        }
    }
    
    // Method to reset hotkeys and permissions
    @objc public func resetHotkeys() {
        print("🔄 Starting complete hotkey reset process...")
        
        // Print the current registered hotkeys for debugging
        HotKey.printRegisteredHotKeys()
        
        // Unregister existing hotkeys first
        hotKey = nil
        composerHotKey = nil
        
        // Use the static method to ensure ALL hotkeys are unregistered
        HotKey.resetAllHotKeys()
        
        print("Waiting for hotkey system to stabilize...")
        
        // Re-register hotkeys after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Setup hotkeys again
            self.setupHotKey()
            
            // Print the new registered hotkeys for debugging
            HotKey.printRegisteredHotKeys()
            
            // Suggest refreshing accessibility permissions
            if !self.checkAccessibilityPermissions(showPrompt: true) {
                self.showNotification("Accessibility Permissions Required", "Please grant Accessibility permissions in System Settings")
            } else {
                self.showNotification("Hotkeys Reset", "The keyboard shortcuts have been reset successfully")
                print("✅ Hotkey reset completed")
            }
        }
    }
    
    private func handleHotKeyPressed() {
        // Check accessibility permissions only when actually needed - and show prompt
        if !checkAccessibilityPermissions(showPrompt: true) {
            return
        }
        
        guard !isProcessing else { 
            print("Already processing a correction, ignoring hotkey")
            return 
        }
        guard !isExcludedApp() else { 
            print("Current app is excluded, ignoring hotkey") 
            return 
        }
        
        isProcessing = true
        animateStatusItem(true)
        print("Starting text correction process (using AX)")
        
        Task {
            var success = false
            let initialChangeCount = clipboardManager.getChangeCount()
            print("Initial clipboard change count: \(initialChangeCount)")
            
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
            
            do {
                print("Step 1: Saving current clipboard contents")
                try await clipboardManager.saveCurrentClipboard()
                
                print("Step 2: Performing AX Copy action")
                var copySucceeded = performAccessibilityAction(kAXPressAction, forMenuItem: "Copy", inMenu: "Edit")
                var usedFallback = false

                if !copySucceeded {
                    print("Warning: Failed to perform AX Copy action. Falling back to CGEvent simulation.")
                    simulateCopyKeypress()
                    usedFallback = true
                    // Re-check clipboard change after fallback
                    print("Step 2b: Waiting for clipboard after CGEvent fallback")
                    copySucceeded = await clipboardManager.waitForChange(since: initialChangeCount, timeout: 1.5)
                }
                
                // Now check if copy ultimately succeeded (either via AX or CG fallback)
                guard copySucceeded else {
                    print("Error: Copy operation failed (both AX and CGEvent). Check Accessibility permissions.")
                    showNotification("Error", "Failed to copy selected text. Check Accessibility permissions.")
                    openAccessibilityPreferences()
                    return // Exit if both failed
                }
                
                // If AX succeeded initially, we still need to wait/verify the clipboard changed
                if !usedFallback {
                    print("Step 3: Waiting for clipboard update after successful AX copy")
                    let changeDetected = await clipboardManager.waitForChange(since: initialChangeCount, timeout: 1.5)
                     guard changeDetected else {
                        print("Error: Clipboard content did not change even after successful AX copy action.")
                        showNotification("Error", "Failed to copy selected text (clipboard didn't update).")
                        openAccessibilityPreferences()
                        return
                    }
                } // If fallback was used, waitForChange was already called.

                print("Clipboard change detected: \(clipboardManager.getChangeCount())")
                
                print("Step 4: Getting copied text from clipboard")
                guard let text = clipboardManager.getClipboardText(), !text.isEmpty else {
                    showNotification("Error", "No text was found in the clipboard after copying.")
                    return
                }
                print("Actual copied text: '\(text)'")
                
                print("Step 5: Sending text to OpenAI for correction")
                guard let correctedText = try await openAIService.correctText(text) else {
                    showNotification("Error", "Failed to correct text via OpenAI.")
                    return
                }
                
                print("Step 6: Received corrected text: '\(correctedText)'")
                clipboardManager.setClipboardText(correctedText)
                
                print("Step 7: Performing AX Paste action")
                let pastePerformed = performAccessibilityAction(kAXPressAction, forMenuItem: "Paste", inMenu: "Edit")
                 guard pastePerformed else {
                    print("Warning: Failed to perform AX Paste action. Falling back to CGEvent simulation.")
                    simulatePasteKeypress() // Fallback paste
                    return
                }

                print("Step 8: Waiting briefly after paste action")
                try await Task.sleep(nanoseconds: 200_000_000)

                success = true
                print("Step 9: Defer will restore original clipboard.")
            } catch {
                print("Error during text correction process: \(error.localizedDescription)")
                showNotification("Error", error.localizedDescription)
            }
        }
    }
    
    private func handleComposerHotKeyPressed() {
        // Check accessibility permissions only when actually needed - and show prompt
        if !checkAccessibilityPermissions(showPrompt: true) {
            return
        }
        
        guard !isProcessing else {
            print("Already processing, ignoring composer hotkey")
            return
        }
        guard !isExcludedApp() else {
            print("Current app is excluded, ignoring composer hotkey")
            return
        }
        
        isProcessing = true
        animateStatusItem(true)
        print("Starting composer flow")
        
        Task {
            defer {
                if currentScreenshots.isEmpty && composerWindowController == nil {
                    resetComposerState() // Only reset if we didn't successfully capture any screenshots or show the window
                }
            }
            
            // Check if screenshots are enabled in preferences
            let includeScreenshots = UserDefaults.standard.bool(forKey: "includeScreenshotsForContext", defaultValue: true)
            
            if includeScreenshots {
                // Step 1: Capture screenshots of all screens
                print("Step 1: Capturing all screens individually")
                do {
                    currentScreenshots = try screenshotManager.captureAllScreensIndividually()
                    print("Successfully captured \(currentScreenshots.count) screens")
                    
                    // Save the screenshots to temporary files
                    screenshotPaths = []
                    for (index, screenshot) in currentScreenshots.enumerated() {
                        do {
                            let url = try screenshotManager.saveImageToTemporaryFile(screenshot)
                            screenshotPaths.append(url.path)
                            print("Screen \(index) screenshot saved to: \(url.path)")
                        } catch {
                            print("Failed to save screenshot \(index): \(error)")
                        }
                    }
                } catch {
                    print("Error capturing screenshots: \(error)")
                    // Continue without screenshots
                    print("Continuing without screenshots")
                }
            } else {
                print("Screenshots are disabled in preferences - skipping screenshot capture")
            }
            
            // Step 2: Get active window information
            print("Step 2: Getting active window information")
            do {
                activeWindowInfo = try screenshotManager.getActiveWindowInfo()
                if let windowInfo = activeWindowInfo {
                    print("Active window: \(windowInfo.appName) - \(windowInfo.windowTitle)")
                } else {
                    print("No active window detected")
                }
                
                // Step 3: Show composer window
                print("Step 3: Showing composer window")
                DispatchQueue.main.async {
                    self.showComposerWindow()
                }
            } catch {
                print("Error in composer flow: \(error)")
                // Show an error to the user
                DispatchQueue.main.async {
                    self.showNotification("Error", error.localizedDescription)
                    self.resetComposerState()
                    self.animateStatusItem(false)
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func showComposerWindow() {
        // Create a window controller with our composer view
        let composerView = ComposerView(
            onSubmit: { bulletText in
                // Store the bullet points
                self.bulletPoints = bulletText
                
                // Handle bullet point submission
                self.handleBulletPointsSubmitted()
            },
            onClose: {
                // Handle window closing without submission
                print("Composer window closed without submission")
                self.resetComposerState()
                self.animateStatusItem(false)
                self.isProcessing = false
            },
            activeWindowInfo: activeWindowInfo.map { ($0.appName, $0.windowTitle) }
        )
        .environmentObject(appState)
        
        // Create the window controller with improved window handling
        composerWindowController = ComposerWindowController(rootView: composerView)
        
        // Let system know we're showing a window
        NSApp.activate(ignoringOtherApps: true)
        
        // Use the enhanced window showing functionality
        composerWindowController?.showWindow(nil)
        
        print("Composer window displayed")
    }
    
    private func handleBulletPointsSubmitted() {
        print("Step 4: Bullet points submitted, preparing data for OpenAI request")
        
        // Ensure we have the necessary data
        guard let windowInfo = activeWindowInfo else {
            print("Error: No active window information available")
            showNotification("Error", "No active window information")
            resetComposerState()
            animateStatusItem(false)
            isProcessing = false
            return
        }
        
        // Close the composer window immediately to show we're processing
        DispatchQueue.main.async {
            self.composerWindowController?.close()
            self.composerWindowController = nil
            self.showNotification("Processing", "Generating draft from your bullet points...")
        }
        
        // Process the bullet points with OpenAI
        Task {
            do {
                // Call OpenAI to generate the draft
                let generatedDraft = try await openAIService.prepareDraftFromScreenshots(
                    screenshotPaths: screenshotPaths,
                    activeWindowInfo: windowInfo,
                    bulletPoints: bulletPoints
                )
                
                // Put the generated draft in the clipboard
                DispatchQueue.main.async {
                    self.clipboardManager.setClipboardText(generatedDraft)
                    
                    // Show a preview of the draft in the notification
                    let previewText = generatedDraft.count > 100 
                        ? "\(generatedDraft.prefix(100))..." 
                        : generatedDraft
                    
                    // Show regular notification
                    self.showNotification(
                        "Draft Generated", 
                        "Your draft has been copied to the clipboard.\n\nPreview: \(previewText)"
                    )
                    
                    // Only use the custom toast window approach, not the ToastManager
                    // self.toastManager.showToast(
                    //     message: "Draft ready and copied to clipboard",
                    //     duration: 2.5,
                    //     icon: "checkmark.circle.fill"
                    // )
                    
                    // Show the toast in a separate window
                    self.showToastWindow(message: "Draft ready and copied to clipboard", 
                                       icon: "checkmark.circle.fill",
                                       duration: 2.5)
                    
                    self.resetComposerState()
                    self.animateStatusItem(false)
                    self.isProcessing = false
                }
            } catch {
                print("Error generating draft: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let errorMessage = (error as? OpenAIError)?.errorDescription ?? error.localizedDescription
                    self.showNotification("Draft Error", "Failed to generate draft: \(errorMessage)")
                    self.resetComposerState()
                    self.animateStatusItem(false)
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func resetComposerState() {
        // Clean up the temporary files
        for path in screenshotPaths {
            do {
                try FileManager.default.removeItem(atPath: path)
                print("Deleted temporary file: \(path)")
            } catch {
                print("Failed to delete temporary file: \(path) - \(error.localizedDescription)")
            }
        }
        
        // Reset the state
        currentScreenshots = []
        screenshotPaths = []
        activeWindowInfo = nil
        bulletPoints = ""
    }
    
    private func checkScreenRecordingPermission() {
        let screenRecordingAccess = CGPreflightScreenCaptureAccess()
        
        if !screenRecordingAccess {
            print("WARNING: Screen recording permission is not granted. Requesting permission...")
            showNotification("Permission Required", "Screen recording permission is needed to capture specific windows")
            
            // Request permission
            let success = CGRequestScreenCaptureAccess()
            print("Screen recording permission request result: \(success ? "Granted" : "Denied or pending")")
            
            // Open the Screen Recording privacy settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            print("Screen recording permission is already granted")
        }
    }
    
    private func resetState() {
        isProcessing = false
        animateStatusItem(false)
    }
    
    private func animateStatusItem(_ isProcessing: Bool) {
        DispatchQueue.main.async {
            if isProcessing {
                // Replace with spinning indicator
                if let button = self.statusItem.button {
                    button.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Processing")
                }
            } else {
                // Restore original system icon
                if let button = self.statusItem.button {
                    button.image = NSImage(systemSymbolName: "textformat.abc.dottedunderline", accessibilityDescription: "Luzia Typo Correcter")
                }
            }
        }
    }
    
    private func performAccessibilityAction(_ action: String, forMenuItem menuItemName: String, inMenu menuName: String) -> Bool {
        guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) else {
            print("AX Error: Process not trusted. Prompting for permissions.")
            // We prompted, but return false for now as it won't work immediately.
            return false
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("AX Error: Could not get frontmost application.")
            return false
        }
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        // Get the menu bar
        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBarElement = menuBar as! AXUIElement? else { // Fixed downcast
            print("AX Error: Could not get menu bar.")
            return false
        }

        // Get menu bar items (File, Edit, View, etc.)
        var menuBarItemsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &menuBarItemsRef) == .success,
              let items = menuBarItemsRef as? [AXUIElement] else {
            print("AX Error: Could not get menu bar items.")
            return false
        }

        // Find the specified top-level menu (e.g., "Edit")
        var targetMenuElement: AXUIElement?
        for item in items {
            var title: AnyObject?
            if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title) == .success,
               (title as? String) == menuName {
                targetMenuElement = item
                break
            }
        }
        guard let foundMenu = targetMenuElement else {
            print("AX Error: Could not find menu named '\(menuName)'.")
            return false
        }

        // Get the children of the target menu (the menu items)
        var menuItemsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(foundMenu, kAXChildrenAttribute as CFString, &menuItemsRef) == .success,
              let actualMenuItems = menuItemsRef as? [AXUIElement] else {
            print("AX Error: Could not get menu items for menu '\(menuName)'.")
            return false
        }

        // Find the specific menu item (e.g., "Copy")
        var targetMenuItemElement: AXUIElement?
        for menuItem in actualMenuItems {
            var title: AnyObject?
            if AXUIElementCopyAttributeValue(menuItem, kAXTitleAttribute as CFString, &title) == .success,
               (title as? String) == menuItemName {
                targetMenuItemElement = menuItem
                break
            }
        }
        guard let foundMenuItem = targetMenuItemElement else {
            print("AX Error: Could not find menu item named '\(menuItemName)' in menu '\(menuName)'.")
            return false
        }

        // Perform the specified action (e.g., kAXPressAction)
        let performError = AXUIElementPerformAction(foundMenuItem, action as CFString)
        if performError == .success {
            print("AX Success: Performed '\(action)' on menu item '\(menuName) > \(menuItemName)'")
            return true
        } else {
            print("AX Error: Failed to perform '\(action)' on menu item '\(menuName) > \(menuItemName)' (Error: \(performError.rawValue))")
            return false
        }
    }
    
    private func simulateCopyKeypress() {
        print("--> Simulating CGEvent Copy Keypress")
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCode: CGKeyCode = 0x08 // 'C'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)!
        keyDown.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)!
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        usleep(50000) // 50ms
        keyUp.post(tap: .cghidEventTap)
    }
    
    private func simulatePasteKeypress() {
        print("--> Simulating CGEvent Paste Keypress")
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCode: CGKeyCode = 0x09 // 'V'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)!
        keyDown.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)!
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        usleep(50000) // 50ms
        keyUp.post(tap: .cghidEventTap)
    }
    
    private func isExcludedApp() -> Bool {
        // Get the frontmost app's bundle identifier
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let bundleIdentifier = frontmostApp.bundleIdentifier ?? ""
        
        // Get the list of excluded apps from preferences
        let excludedApps = UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []
        
        return excludedApps.contains(bundleIdentifier)
    }
    
    private func showNotification(_ title: String, _ message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        // Also print to console for debugging
        print("\(title): \(message)")
    }
    
    @objc public func openAccessibilityPreferences() {
        // Open System Settings to Accessibility > Privacy
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Prevent app from terminating when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Don't quit when windows are closed
    }
    
    // Add a method to show toast in a separate window
    private func showToastWindow(message: String, icon: String, duration: TimeInterval) {
        DispatchQueue.main.async {
            // Create a very small window just for the toast
            let toastWindow = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            // Configure window properties
            toastWindow.backgroundColor = .clear
            toastWindow.isOpaque = false
            toastWindow.hasShadow = true
            toastWindow.level = .floating
            toastWindow.titleVisibility = .hidden
            toastWindow.titlebarAppearsTransparent = true
            
            // Position near the top center of the screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = toastWindow.frame
                let x = screenFrame.midX - (windowFrame.width / 2)
                let y = screenFrame.maxY - windowFrame.height - 60
                toastWindow.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            // Create a simple NSViewController instead of using SwiftUI
            let viewController = NSViewController()
            let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
            
            // Create the toast contents
            let imageView = NSImageView(frame: NSRect(x: 12, y: 12, width: 16, height: 16))
            imageView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            
            let textField = NSTextField(frame: NSRect(x: 36, y: 12, width: 250, height: 16))
            textField.stringValue = message
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.font = NSFont.systemFont(ofSize: 12)
            
            // Add elements to the view
            containerView.addSubview(imageView)
            containerView.addSubview(textField)
            
            // Add background
            containerView.wantsLayer = true
            containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
            containerView.layer?.cornerRadius = 16
            
            viewController.view = containerView
            toastWindow.contentViewController = viewController
            
            // Create a window controller to maintain a strong reference
            self.toastWindowController = NSWindowController(window: toastWindow)
            
            // Show the window
            self.toastWindowController?.showWindow(nil)
            
            // Auto-close after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                // Close the window and nil out the reference
                self.toastWindowController?.close()
                self.toastWindowController = nil
            }
        }
    }
    
    // Configure how windows behave when minimized
    private func configureWindowBehavior() {
        // Set the window to hide when minimized rather than showing in the Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Register for reopen events (when user clicks dock icon)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopenApp(event:replyEvent:)),
            forEventClass: kCoreEventClass,
            andEventID: kAEReopenApplication
        )
        
        // Configure any existing windows
        for window in NSApp.windows {
            // Use a decent animation for minimize
            window.animationBehavior = .documentWindow
            
            // Set to automatically hide title bar
            window.styleMask.insert(.fullSizeContentView)
            
            // Set title bar to be transparent
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // Make sure closing the window doesn't terminate the app
            window.isReleasedWhenClosed = false
            
            // Handle window close events by hiding the app instead
            window.standardWindowButton(.closeButton)?.action = #selector(hideApp)
        }
    }
    
    @objc private func hideApp() {
        NSApp.hide(nil)
    }
    
    @objc private func handleReopenApp(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        // When user clicks dock icon or app icon, show the window
        unhideApp()
    }
    
    // Check if we have accessibility permissions and prompt if needed
    private func checkAccessibilityPermissions(showPrompt: Bool = false) -> Bool {
        // Check without showing prompt first
        let checkOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(checkOptions)
        
        // If accessibility is not enabled and we want to show the prompt
        if !accessibilityEnabled && showPrompt {
            // Now show the prompt with a separate call
            let promptOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let _ = AXIsProcessTrustedWithOptions(promptOptions)
            
            print("Accessibility permissions not granted - prompting user")
            showNotification("Permissions Required", "Please grant Accessibility permissions in System Settings > Privacy & Security > Accessibility")
            
            // Only open preferences if explicitly requested
            if showPrompt {
                openAccessibilityPreferences()
            }
        }
        
        return accessibilityEnabled
    }
    
    // Add this new method for a comprehensive reset of permissions and hotkeys
    @objc public func forceResetPermissions() {
        print("🚨 PERFORMING EMERGENCY FORCE RESET OF PERMISSIONS AND HOTKEYS 🚨")
        
        // 1. Aggressively unregister ALL hotkeys
        print("Step 1: Forcefully unregistering all hotkeys")
        hotKey?.unregister()
        composerHotKey?.unregister()
        hotKey = nil
        composerHotKey = nil
        
        // Use the static method to ensure ALL hotkeys are unregistered system-wide
        HotKey.resetAllHotKeys()
        
        // 2. Add direct check of Carbon API status
        print("Step 2: Checking Carbon API status")
        let eventTarget = Carbon.GetApplicationEventTarget()
        if eventTarget == nil {
            print("⚠️ Warning: GetApplicationEventTarget() returned nil - Carbon event system may be unavailable")
        } else {
            print("Carbon event target available: \(eventTarget)")
        }
        
        // 3. Launch a separate terminal command to reset accessibility database
        print("Step 3: Requesting user to manually reset permissions cache")
        let message = """
        To fix the hotkey issue, please run this command in Terminal:
        
        tccutil reset Accessibility com.luzia.typocorrecter
        
        Then restart the app after running this command.
        
        If that doesn't work, please try:
        1. Open System Settings > Privacy & Security > Accessibility
        2. Remove Luzia from the list (if present)
        3. Restart your Mac
        4. Launch Luzia again and grant permissions when prompted
        """
        
        // Show both a notification and a dialog
        showNotification("Permission Reset Required", "Please check the dialog for instructions")
        
        DispatchQueue.main.async {
            // Create and configure alert
            let alert = NSAlert()
            alert.messageText = "Permission Reset Required"
            alert.informativeText = message
            alert.alertStyle = .warning
            
            // Add a copy button
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Cancel")
            
            // Show alert and handle response
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Copy the command to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("tccutil reset Accessibility com.luzia.typocorrecter", forType: .string)
                
                // Show confirmation
                self.showNotification("Command Copied", "The reset command has been copied to your clipboard")
            } else if response == .alertSecondButtonReturn {
                // Open Accessibility settings
                self.openAccessibilityPreferences()
            }
        }
        
        // 4. Reset HotKey internal state and test registration
        print("Step 4: Forcefully creating new test hotkey to verify registration system")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Try to register a test hotkey on a different key to see if the system works at all
            print("Attempting to register a diagnostic test hotkey...")
            let testHotKey = HotKey(key: .t, modifiers: [.shift, .command], identifier: 999)
            let success = testHotKey.hotKeyRef != nil
            print("Test hotkey registration result: \(success ? "SUCCESS ✅" : "FAILED ❌")")
            
            // Show the result to the user
            self.showNotification(
                success ? "Hotkey System Working" : "Hotkey System Failed",
                success ? "Test hotkey registered successfully. Try the app hotkeys again." : "Unable to register test hotkey. System restart may be required."
            )
            
            // Clean up test hotkey
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                testHotKey.unregister()
                print("Test hotkey unregistered")
            }
        }
        
        // 5. Final check of registered hotkeys
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("Final check of registered hotkeys:")
            HotKey.printRegisteredHotKeys()
        }
    }
    
    // Update the DiagnosticsView with a button to perform the emergency reset
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification response
        completionHandler()
    }
} 