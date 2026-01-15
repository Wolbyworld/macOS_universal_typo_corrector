import AppKit

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

        // Get mouse location
        let mouseLocation = NSEvent.mouseLocation

        // Create spinner (small, 16x16)
        let spin = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        spin.style = .spinning
        spin.controlSize = .small
        self.spinner = spin

        // Create transparent window just big enough for spinner
        let windowRect = NSRect(x: mouseLocation.x + 12, y: mouseLocation.y - 24, width: 16, height: 16)
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
