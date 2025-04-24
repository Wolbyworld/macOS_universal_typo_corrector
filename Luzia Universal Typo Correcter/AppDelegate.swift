import SwiftUI
import AppKit
import Sparkle
import UserNotifications
import Accessibility

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var hotKey: HotKey?
    
    private var clipboardManager = ClipboardManager()
    private var openAIService = OpenAIService()
    private var sparkleUpdater: SparkleUpdater?
    private var isProcessing = false
    public var appState = AppState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        setupMenuBarItem()
        setupHotKey()
        
        // Initialize Sparkle
        sparkleUpdater = SparkleUpdater()
        
        // Check for accessibility permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessibilityEnabled {
            showNotification("Permissions Required", "Please grant Accessibility permissions in System Settings > Privacy & Security > Accessibility")
        }
        
        // Add menu items to enable preferences access
        setupMenu()
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
                statusItem.menu = nil // Clear the menu when showing popover
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func setupHotKey() {
        // Default shortcut: ⇧⌘G
        hotKey = HotKey(key: .g, modifiers: [.shift, .command])
        hotKey?.keyDownHandler = { [weak self] in
            self?.handleHotKeyPressed()
        }
    }
    
    private func handleHotKeyPressed() {
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
    
    @objc public func openAccessibilityPreferences() {
        // Open System Settings to Accessibility > Privacy
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
} 