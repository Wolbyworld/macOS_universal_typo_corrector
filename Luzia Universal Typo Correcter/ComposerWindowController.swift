import SwiftUI
import AppKit

class ComposerWindowController: NSWindowController {
    private var onCloseCallback: (() -> Void)?
    
    init<Content: View>(rootView: Content) {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        window.title = "Compose Your Message"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        
        // Make the window appear with a nice animation
        window.animationBehavior = .documentWindow
        
        // Set up the content view with proper styling
        let hostingView = NSHostingView(
            rootView: rootView
                .frame(minWidth: 500, minHeight: 350)
        )
        
        // Apply some nice rounded corners and shadow to the hosting view
        hostingView.wantsLayer = true
        
        window.contentView = hostingView
        
        // Initialize superclass
        super.init(window: window)
        
        // Set delegate
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setOnCloseCallback(_ callback: @escaping () -> Void) {
        self.onCloseCallback = callback
    }
    
    override func showWindow(_ sender: Any?) {
        // Activate the app to ensure our window gets focus
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure window is initialized and configured
        guard let window = window else { return }
        
        // Position the window in a prominent location
        positionWindowProminently()
        
        // Start with reduced opacity for animation
        window.alphaValue = 0.85
        
        // Make it the key window and bring to front with higher priority
        window.orderFrontRegardless()
        window.makeKey()
        
        // Animate the window appearance for better visibility
        animateWindowAppearance()
        
        // Set initial responder to ensure proper focus for typing
        window.makeFirstResponder(window.contentView)
    }
    
    private func positionWindowProminently() {
        guard let window = window, let screen = NSScreen.main else { return }
        
        // Position in the center of the screen
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        let centerX = screenFrame.midX - (windowFrame.width / 2)
        let centerY = screenFrame.midY - (windowFrame.height / 2)
        
        window.setFrameOrigin(NSPoint(x: centerX, y: centerY))
        
        // Add a slight vertical offset to make it more prominent
        let yOffset: CGFloat = 50 // Pixels above center
        if screenFrame.height > windowFrame.height + (yOffset * 2) {
            let adjustedY = centerY + yOffset
            window.setFrameOrigin(NSPoint(x: centerX, y: adjustedY))
        }
    }
    
    private func animateWindowAppearance() {
        guard let window = window else { return }
        
        // Animate to full opacity
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        })
        
        // Optional: Subtle bounce effect
        let originalFrame = window.frame
        var expandedFrame = originalFrame
        expandedFrame.size.width += 10
        expandedFrame.size.height += 10
        expandedFrame.origin.x -= 5
        expandedFrame.origin.y -= 5
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(expandedFrame, display: true)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().setFrame(originalFrame, display: true)
            })
        })
    }
}

// Extend window controller to handle window delegate callbacks
extension ComposerWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Call the onClose handler
        onCloseCallback?()
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Additional focus handling if needed
        guard let window = window else { return }
        
        // Ensure the window is at the front of all windows
        window.level = .floating
        
        // Reset to normal level after a brief delay to not interfere with other operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            window.level = .normal
        }
    }
} 
