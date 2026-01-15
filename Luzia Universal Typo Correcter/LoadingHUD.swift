import AppKit
import ApplicationServices

@MainActor
class LoadingHUDManager {
    static let shared = LoadingHUDManager()

    private var window: NSWindow?
    private var spinner: NSProgressIndicator?

    private init() {}

    nonisolated func show() {
        Task { @MainActor in
            self.createAndShowHUD()
        }
    }

    private func createAndShowHUD() {
        // Clean up existing
        hideImmediately()

        // Try to get position at end of selected text, fallback to mouse
        var position = NSEvent.mouseLocation
        if let textPosition = getSelectedTextEndPosition() {
            // Validate position is on screen
            if let screen = NSScreen.main, screen.frame.contains(NSPoint(x: textPosition.x, y: textPosition.y)) {
                position = textPosition
            }
        }

        // Create spinner (small, 16x16)
        let spin = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        spin.style = .spinning
        spin.controlSize = .small
        self.spinner = spin

        // Create transparent window just big enough for spinner
        let windowRect = NSRect(x: position.x + 4, y: position.y - 8, width: 16, height: 16)
        let win = NSWindow(contentRect: windowRect, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.contentView = spin
        self.window = win

        // Start spinner and show
        spin.startAnimation(nil)
        win.orderFrontRegardless()
    }

    private func getSelectedTextEndPosition() -> NSPoint? {
        // Get the system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        let axElement = element as! AXUIElement

        // Get selected text range
        var selectedRangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)

        guard rangeResult == .success, let rangeValue = selectedRangeValue else {
            return nil
        }

        // Get bounds for the selected text range
        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            axElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )

        guard boundsResult == .success, let bounds = boundsValue else {
            return nil
        }

        // Convert to CGRect
        var rect = CGRect.zero
        if AXValueGetValue(bounds as! AXValue, .cgRect, &rect) {
            // AX coordinates: origin at top-left of main screen
            // NSWindow coordinates: origin at bottom-left of main screen
            // Convert Y coordinate
            let screenHeight = NSScreen.main?.frame.height ?? 0
            let bottomY = screenHeight - rect.origin.y - rect.height

            // Return the right edge of the selection, vertically centered
            return NSPoint(x: rect.origin.x + rect.width, y: bottomY + rect.height / 2)
        }

        return nil
    }

    nonisolated func hide() {
        Task { @MainActor in
            self.hideImmediately()
        }
    }

    private func hideImmediately() {
        spinner?.stopAnimation(nil)
        window?.orderOut(nil)
        window = nil
        spinner = nil
    }
}
