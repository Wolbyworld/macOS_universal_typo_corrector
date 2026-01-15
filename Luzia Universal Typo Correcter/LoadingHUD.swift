import SwiftUI
import AppKit

class LoadingHUDWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Ignore mouse events so it doesn't interfere with user interaction
        self.ignoresMouseEvents = true

        // Set up the content view
        let hostingView = NSHostingView(rootView: LoadingHUDView())
        hostingView.frame = self.contentView?.bounds ?? .zero
        self.contentView = hostingView
    }
}

struct LoadingHUDView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.small)

            Text("Correcting...")
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .frame(width: 120, height: 50)
    }
}

class LoadingHUDManager {
    static let shared = LoadingHUDManager()
    private var hudWindow: LoadingHUDWindow?

    private init() {}

    func show() {
        DispatchQueue.main.async { [weak self] in
            // Remove existing HUD if present
            self?.hide()

            // Create new HUD window
            let window = LoadingHUDWindow()

            // Position near mouse cursor (slightly below and to the right)
            if let mouseLocation = NSEvent.mouseLocation as CGPoint? {
                let screenFrame = NSScreen.main?.frame ?? .zero

                // Adjust position to be below and slightly right of cursor
                var hudOrigin = CGPoint(
                    x: mouseLocation.x + 20,
                    y: mouseLocation.y - 70
                )

                // Ensure HUD stays on screen
                if hudOrigin.x + window.frame.width > screenFrame.maxX {
                    hudOrigin.x = screenFrame.maxX - window.frame.width - 10
                }
                if hudOrigin.y < screenFrame.minY {
                    hudOrigin.y = screenFrame.minY + 10
                }

                window.setFrameOrigin(hudOrigin)
            }

            // Show window with fade-in animation
            window.alphaValue = 0
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 1.0
            }

            self?.hudWindow = window
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.hudWindow else { return }

            // Fade out animation
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.close()
                self?.hudWindow = nil
            })
        }
    }
}
