import SwiftUI
import AppKit
import Sparkle
import UserNotifications
import Accessibility
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var hotKey: HotKey?
    var prefWindowController: NSWindowController?

    private var statusItemMenu: NSMenu?  // Store menu to restore after popover
    private var clipboardManager = ClipboardManager()
    private var openAIService = OpenAIService()
    private var sparkleUpdater: SparkleUpdater?
    private var startupManager = StartupManager()
    private var isProcessing = false
    public var appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var lastSimulatedPasteAt: Date?
    private var hasAccessibilityPermissions = false  // Cache permission state
    private var accessibilityPermissionTimer: Timer?
    private var hasShownAccessibilityPermissionNotification = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app behaves as agent (LSUIElement now properly set in build settings)
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        setupMenuBarItem()
        
        // Initialize Sparkle
        sparkleUpdater = SparkleUpdater()
        
        updateAccessibilityPermissionState(prompt: true)
        if !hasAccessibilityPermissions {
            notifyAccessibilityPermissionRequired()
        }
        setupHotKey()
        startAccessibilityPermissionMonitor()
        
        // Add menu items to enable preferences access
        setupMenu()
        
        // Reconcile startup state on launch
        startupManager.reconcileStartupState()

        // Setup startup behavior observer
        setupStartupObserver()

        // Hide any main windows for agent app behavior
        hideMainWindows()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityPermissionTimer?.invalidate()
        accessibilityPermissionTimer = nil
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
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
        statusItemMenu = menu  // Store menu for later restoration
    }
    
    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? String else { return }
        appState.selectedModel = model
        setupMenu() // Refresh menu to update checkmarks
    }
    
    @objc public func openPreferences() {
        // Reuse existing window if available
        if let existingWindow = prefWindowController?.window {
            // CRITICAL: Change to .regular to enable Edit menu (Cut/Copy/Paste)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // Create new preferences window with delegate to restore .accessory on close
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "Preferences"
        window.contentViewController = NSHostingController(
            rootView: PreferencesView().environmentObject(appState)
        )

        // Set delegate to handle window close (restore .accessory policy)
        window.delegate = self

        prefWindowController = NSWindowController(window: window)

        // CRITICAL: Change activation policy to .regular to enable Edit menu
        // This allows standard Cut/Copy/Paste operations in text fields
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        prefWindowController?.window?.makeKeyAndOrderFront(nil)
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
        popover.delegate = self  // Set delegate to handle popover close
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
                statusItem.menu = nil // Clear the menu when showing popover
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func setupHotKey() {
        guard hotKey == nil else { return }
        guard HotKeyRegistrationPolicy.shouldRegisterCmdShiftG(accessibilityTrusted: hasAccessibilityPermissions) else {
            return
        }

        // Default shortcut: ⇧⌘G
        hotKey = HotKey(key: .g, modifiers: [.shift, .command])
        hotKey?.keyDownHandler = { [weak self] in
            self?.handleHotKeyPressed()
        }
    }

    private func tearDownHotKey() {
        guard hotKey != nil else { return }
        hotKey = nil
    }

    private func startAccessibilityPermissionMonitor() {
        guard accessibilityPermissionTimer == nil else { return }

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.updateAccessibilityPermissionState(prompt: false)
        }
        accessibilityPermissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @discardableResult
    private func updateAccessibilityPermissionState(prompt: Bool) -> Bool {
        let isTrusted: Bool

        if prompt {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            isTrusted = AXIsProcessTrustedWithOptions(options)
        } else {
            isTrusted = AXIsProcessTrusted()
        }

        guard isTrusted != hasAccessibilityPermissions else {
            if isTrusted {
                setupHotKey()
            }
            return isTrusted
        }

        hasAccessibilityPermissions = isTrusted

        if isTrusted {
            hasShownAccessibilityPermissionNotification = false
            print("Accessibility permissions: GRANTED")
            setupHotKey()
        } else {
            print("Accessibility permissions: MISSING")
            tearDownHotKey()
            notifyAccessibilityPermissionRequired()
        }

        return isTrusted
    }
    
    private func handleHotKeyPressed() {
        guard !isProcessing else {
            print("Already processing a correction, ignoring hotkey")
            return
        }
        guard updateAccessibilityPermissionState(prompt: false) else {
            print("Accessibility permissions missing, disabling hotkey until permission is granted")
            tearDownHotKey()
            notifyAccessibilityPermissionRequired()
            openAccessibilityPreferences()
            return
        }
        guard !shouldPassThroughHotKeyWithoutInterception() else {
            print("Finder or file dialog has focus, passing through hotkey")
            passthroughHotKey()
            return
        }
        guard !isExcludedApp() else {
            print("Current app is excluded, passing through hotkey")
            passthroughHotKey()
            return
        }
        if getSelectedText() == nil {
            print("No text selected, passing through hotkey")
            passthroughHotKey()
            return
        }
        
        isProcessing = true
        animateStatusItem(true)
        LoadingHUDManager.shared.show()
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
                // Dynamic pre-paste delay to give host app time to observe new pasteboard contents
                let isLong = correctedText.count > 120
                let prePasteDelayMs = isLong ? appState.prePasteDelayLong : appState.prePasteDelayShort
                let prePasteDelayNs: UInt64 = UInt64(prePasteDelayMs) * 1_000_000
                print("Using pre-paste delay: \(prePasteDelayMs)ms")
                try await Task.sleep(nanoseconds: prePasteDelayNs)
                
                print("Step 7: Performing AX Paste action")
                let pastePerformed = performAccessibilityAction(kAXPressAction, forMenuItem: "Paste", inMenu: "Edit")
                guard pastePerformed else {
                    print("Warning: Failed to perform AX Paste action. Falling back to CGEvent simulation.")
                    ErrorLogger.shared.log(stage: "ax_paste_failed",
                                           model: appState.selectedModel,
                                           reasoningEffort: UserDefaults.standard.string(forKey: "reasoningEffort"),
                                           inputLength: text.count,
                                           statusCode: nil,
                                           reason: "ax_failure",
                                           details: "menubar not found")
                    // CGEvent fallback paste: single paste with cooldown and robust delay
                    let now = Date()
                    if let last = lastSimulatedPasteAt, now.timeIntervalSince(last) < 1.0 {
                        print("Skipping duplicate fallback paste due to cooldown")
                    } else {
                        simulatePasteKeypress()
                        lastSimulatedPasteAt = now
                    }
                    let postPasteDelayMs = isLong ? appState.postPasteDelayLong : appState.postPasteDelayShort
                    let postCGDelayNs: UInt64 = UInt64(postPasteDelayMs) * 1_000_000
                    print("Using post-paste delay (CGEvent fallback): \(postPasteDelayMs)ms")
                    try await Task.sleep(nanoseconds: postCGDelayNs)
                    // Restore original clipboard after successful paste fallback
                    try await clipboardManager.restoreOriginalClipboardIfNeeded()
                    success = true
                    print("Step 9: Clipboard restored after fallback paste.")
                    return
                }

                print("Step 8: Waiting briefly after paste action")
                let postPasteDelayMs = isLong ? appState.postPasteDelayLong : appState.postPasteDelayShort
                let postAXDelayNs: UInt64 = UInt64(postPasteDelayMs) * 1_000_000
                print("Using post-paste delay (AX success): \(postPasteDelayMs)ms")
                try await Task.sleep(nanoseconds: postAXDelayNs)

                // Restore original clipboard after successful AX paste
                try await clipboardManager.restoreOriginalClipboardIfNeeded()
                success = true
                print("Step 9: Clipboard restored after paste.")
            } catch {
                print("Error during text correction process: \(error.localizedDescription)")

                // Log error to ErrorLogger
                let errorReason: String
                if let openAIError = error as? OpenAIError {
                    switch openAIError {
                    case .noApiKey:
                        errorReason = "no_api_key"
                    case .noProxyConfig:
                        errorReason = "no_proxy_config"
                    case .invalidURL:
                        errorReason = "invalid_url"
                    case .unauthorized:
                        errorReason = "unauthorized"
                    case .rateLimitExceeded:
                        errorReason = "rate_limit"
                    case .apiError(let statusCode):
                        errorReason = "api_error_\(statusCode)"
                    case .invalidResponse:
                        errorReason = "invalid_response"
                    case .noResponseContent:
                        errorReason = "no_content"
                    case .networkError:
                        errorReason = "network_error"
                    }
                } else {
                    errorReason = "unknown_error"
                }

                ErrorLogger.shared.log(stage: "correction_failed",
                                       model: appState.selectedModel,
                                       reasoningEffort: UserDefaults.standard.string(forKey: "reasoningEffort"),
                                       inputLength: nil,
                                       statusCode: nil,
                                       reason: errorReason,
                                       details: error.localizedDescription)

                showNotification("Error", error.localizedDescription)
            }
        }
    }
    
    private func resetState() {
        isProcessing = false
        animateStatusItem(false)
        LoadingHUDManager.shared.hide()
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
        // Check cached permission state first (no prompt)
        if !hasAccessibilityPermissions {
            // Double-check without prompting in case user granted permissions
            hasAccessibilityPermissions = AXIsProcessTrusted()

            if !hasAccessibilityPermissions {
                print("AX Error: Process not trusted. Permissions not granted.")
                return false
            } else {
                print("AX: Permissions detected as granted (cache updated)")
            }
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

    /// Query the focused UI element for selected text via Accessibility.
    /// Returns the selected string, or nil if nothing is selected or AX is unavailable.
    private func getSelectedText() -> String? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }

        guard let text = selectedText as? String, !text.isEmpty else {
            return nil
        }
        return text
    }

    /// Pass the hotkey keystroke through to the frontmost app by temporarily
    /// unregistering the Carbon handler, posting the CGEvent, then re-registering.
    private func passthroughHotKey() {
        // Tear down the Carbon handler so the posted event isn't caught by us
        hotKey = nil

        // Post ⇧⌘G via CGEvent
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCode: CGKeyCode = 0x05 // 'G'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)!
        keyDown.flags = [.maskCommand, .maskShift]
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)!
        keyUp.flags = [.maskCommand, .maskShift]
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Re-register after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupHotKey()
        }
    }

    private func shouldPassThroughHotKeyWithoutInterception() -> Bool {
        let context = HotKeyFocusContextReader.current()
        let shouldPassThrough = HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context)

        if shouldPassThrough {
            print("Finder/file picker context active, leaving ⇧⌘G to the system")
        }

        return shouldPassThrough
    }

    private func isExcludedApp() -> Bool {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            return appState.isAppExcluded(frontmostApp)
        }
        return false
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

    private func notifyAccessibilityPermissionRequired() {
        guard !hasShownAccessibilityPermissionNotification else { return }
        hasShownAccessibilityPermissionNotification = true
        showNotification("Permissions Required", "Please grant Accessibility permissions in System Settings > Privacy & Security > Accessibility")
    }
    
    @objc public func openAccessibilityPreferences() {
        // Open System Settings to Accessibility > Privacy
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func hideMainWindows() {
        // For agent applications, hide any main windows that might appear
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window.title.isEmpty || window.contentViewController is NSHostingController<EmptyView> {
                    window.orderOut(nil)
                    window.setIsVisible(false)
                }
            }
        }
    }
    
    // MARK: - Startup Management
    
    private func setupStartupObserver() {
        print("AppDelegate: Setting up startup behavior observer")

        // Track previous value to only react to actual changes (not initial load)
        var previousValue = appState.openOnStartup

        appState.$openOnStartup
            .sink { [weak self] isEnabled in
                // Only handle if value actually changed (user toggled, not initial load)
                if isEnabled != previousValue {
                    print("AppDelegate: Startup preference change detected: \(previousValue) -> \(isEnabled)")
                    previousValue = isEnabled
                    self?.handleStartupPreferenceChange(isEnabled)
                } else {
                    print("AppDelegate: Startup observer triggered with same value (\(isEnabled)), ignoring")
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleStartupPreferenceChange(_ isEnabled: Bool) {
        print("AppDelegate: Startup preference changed to: \(isEnabled)")
        
        Task { @MainActor in
            do {
                if isEnabled {
                    try startupManager.enableStartup()
                    showNotification("Startup Enabled", "Luzia will now launch automatically when you log in.")
                } else {
                    try startupManager.disableStartup()
                    showNotification("Startup Disabled", "Luzia will no longer launch automatically.")
                }
            } catch {
                print("AppDelegate Error: Failed to change startup setting - \(error.localizedDescription)")
                
                // Revert the UI state since the operation failed
                appState.openOnStartup = !isEnabled
                
                // Show user-friendly error
                showNotification("Startup Setting Failed", error.localizedDescription)
            }
        }
         }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        // Restore menu when popover closes
        print("AppDelegate: Popover closed, restoring menu")
        statusItem.menu = statusItemMenu
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // When preferences window closes, restore .accessory policy to hide from Dock
        if notification.object as? NSWindow === prefWindowController?.window {
            NSApp.setActivationPolicy(.accessory)
            print("Preferences closed - restored .accessory activation policy")
        }
    }
}
