import SwiftUI
import Carbon

struct DiagnosticsView: View {
    @State private var accessibilityStatus = "Checking..."
    @State private var hotkeysStatus = "Checking..."
    @State private var systemInfo = "Checking..."
    @State private var testHotkey: HotKey? = nil
    @State private var testHotkeyTriggered = false
    @State private var appHasScreenRecordingPermission = "Checking..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Luzia Diagnostics")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            Group {
                Text("Accessibility Permissions:")
                    .font(.headline)
                Text(accessibilityStatus)
                    .foregroundColor(accessibilityStatus.contains("Granted") ? .green : .red)
                
                Button("Request Accessibility Permissions") {
                    requestAccessibilityPermissions()
                }
                
                Text("Global Hotkeys Status:")
                    .font(.headline)
                Text(hotkeysStatus)
                    .foregroundColor(hotkeysStatus.contains("OK") ? .green : .red)
                
                Button("Test Hotkey Registration (⌘⇧T)") {
                    registerTestHotkey()
                }
                
                Text(testHotkeyTriggered ? "Test hotkey was successfully triggered! ✅" : "Test hotkey not triggered yet ❌")
                    .foregroundColor(testHotkeyTriggered ? .green : .orange)
                
                Button("Reset All Hotkeys") {
                    resetAllHotkeys()
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
                
                // Add Emergency Reset button with stronger visual styling
                Button("EMERGENCY PERMISSIONS RESET") {
                    performEmergencyReset()
                }
                .padding()
                .background(Color.red.opacity(0.3))
                .foregroundColor(.red)
                .cornerRadius(8)
                .help("Use this only as a last resort if hotkeys aren't working at all. This will help reset the system's permission cache.")
                
                // Add button to check for hotkey conflicts
                Button("Check for Hotkey Conflicts") {
                    checkForHotkeyConflicts()
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
                
                Text("Screen Recording Permission:")
                    .font(.headline)
                Text(appHasScreenRecordingPermission)
                    .foregroundColor(appHasScreenRecordingPermission.contains("Granted") ? .green : .red)
                
                Button("Request Screen Recording Permission") {
                    requestScreenRecordingPermission()
                }
                
                Text("System Information:")
                    .font(.headline)
                Text(systemInfo)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Troubleshooting Steps:")
                    .font(.headline)
                
                Text("1. Click 'Request Accessibility Permissions' and grant in System Settings")
                Text("2. Click 'Test Hotkey Registration' to see if hotkeys can be registered")
                Text("3. Try pressing ⌘⇧T to test if global hotkeys work")
                Text("4. If the test hotkey works but app hotkeys don't, restart the app")
                Text("5. If nothing works, try these advanced steps:")
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("• Restart your Mac")
                    Text("• Open Terminal and run: tccutil reset Accessibility com.luzia.typocorrecter")
                    Text("• Remove the app from Accessibility list in System Settings and re-add it")
                }
                .padding(.leading)
            }
            
            Spacer()
            
            HStack {
                Button("Refresh Diagnostics") {
                    refreshAllDiagnostics()
                }
                .keyboardShortcut("r")
                
                Spacer()
                
                Button("Open Accessibility Settings") {
                    openAccessibilitySettings()
                }
            }
        }
        .padding()
        .frame(width: 600, height: 700)
        .onAppear {
            refreshAllDiagnostics()
        }
    }
    
    private func refreshAllDiagnostics() {
        checkAccessibilityPermissions()
        checkHotkeysStatus()
        gatherSystemInfo()
        checkScreenRecordingPermission()
    }
    
    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if accessibilityEnabled {
            accessibilityStatus = "Granted ✅ - App has accessibility permissions"
        } else {
            accessibilityStatus = "Not Granted ❌ - App needs accessibility permissions"
        }
    }
    
    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options)
        
        // Open System Settings directly to the app's accessibility settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        
        // Re-check after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            checkAccessibilityPermissions()
        }
    }
    
    private func checkHotkeysStatus() {
        // Check if we can register a basic hotkey
        let testKey = HotKey(key: .t, modifiers: [.shift, .command], identifier: 999)
        
        if testKey.isRegistered {
            hotkeysStatus = "OK ✅ - Test hotkey could be registered"
        } else {
            hotkeysStatus = "Failed ❌ - Unable to register test hotkey"
        }
    }
    
    private func registerTestHotkey() {
        // Clean up previous hotkey if any
        testHotkey = nil
        
        // Create a new test hotkey
        testHotkey = HotKey(key: .t, modifiers: [.shift, .command], identifier: 999)
        testHotkey?.keyDownHandler = {
            self.testHotkeyTriggered = true
        }
        
        hotkeysStatus = "Test hotkey registered - Press ⌘⇧T to test"
    }
    
    private func checkScreenRecordingPermission() {
        let hasPermission = CGPreflightScreenCaptureAccess()
        appHasScreenRecordingPermission = hasPermission ? "Granted ✅" : "Not Granted ❌"
    }
    
    private func requestScreenRecordingPermission() {
        let _ = CGRequestScreenCaptureAccess()
        
        // Open System Settings directly to the screen recording settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        
        // Re-check after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            checkScreenRecordingPermission()
        }
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func gatherSystemInfo() {
        // Get basic system info
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBundleID = Bundle.main.bundleIdentifier ?? "Unknown"
        
        systemInfo = """
        macOS Version: \(osVersion)
        App Version: \(appVersion)
        Bundle ID: \(appBundleID)
        Architecture: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
    }
    
    private func resetAllHotkeys() {
        // Find the AppDelegate instance
        if let appDelegate = NSApp.delegate as? AppDelegate {
            // Call the resetHotkeys method
            appDelegate.resetHotkeys()
            
            // Update status after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkHotkeysStatus()
                self.testHotkeyTriggered = false
            }
        }
    }
    
    private func performEmergencyReset() {
        // Create confirmation alert
        let alert = NSAlert()
        alert.messageText = "Confirm Emergency Reset"
        alert.informativeText = "This will completely reset all hotkeys and request a permissions reset. You'll need to restart the app after this process. Continue?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Reset Everything")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // User confirmed, perform emergency reset
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.forceResetPermissions()
            }
        }
    }
    
    private func checkForHotkeyConflicts() {
        let alert = NSAlert()
        alert.messageText = "Checking for Hotkey Conflicts"
        alert.informativeText = "This will list all running applications that might be using the same keyboard shortcuts. Continue?"
        alert.addButton(withTitle: "Check")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Get all running applications
            let runningApps = NSWorkspace.shared.runningApplications
            
            // Create a report
            var report = "# Hotkey Conflict Check Report\n\n"
            report += "## Luzia Keyboard Shortcuts\n"
            report += "- Command+Shift+G (Typo Correction)\n"
            report += "- Command+Shift+M (Composer)\n\n"
            
            report += "## Running Applications\n"
            let suspectApps = ["Alfred", "Keyboard Maestro", "BetterTouchTool", "Raycast", "LaunchBar", "TextExpander", "Karabiner", "Shortcat", "Magnet"]
            
            var foundSuspects = false
            for app in runningApps {
                guard let bundleID = app.bundleIdentifier, let appName = app.localizedName else { continue }
                
                // Check if this app is known to use global shortcuts
                let isSuspect = suspectApps.contains { appName.contains($0) }
                
                if isSuspect {
                    foundSuspects = true
                    report += "- **\(appName)** (\(bundleID)) - Known to use global shortcuts\n"
                }
            }
            
            if !foundSuspects {
                report += "No applications known for keyboard shortcut conflicts were detected.\n"
            }
            
            report += "\n## Recommendations\n"
            report += "If you are experiencing hotkey issues, try temporarily quitting these applications to check if the conflict is resolved.\n"
            report += "You can also try changing Luzia's keyboard shortcuts in Preferences.\n"
            
            // Show report in a separate window
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
            textView.string = report
            textView.isEditable = false
            textView.font = NSFont.systemFont(ofSize: 12)
            
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
            scrollView.documentView = textView
            scrollView.hasVerticalScroller = true
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Hotkey Conflict Report"
            window.contentView = scrollView
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

extension HotKey {
    var isRegistered: Bool {
        hotKeyRef != nil
    }
} 