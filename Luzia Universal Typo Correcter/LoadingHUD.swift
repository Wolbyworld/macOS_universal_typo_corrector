import SwiftUI
import AppKit

class LoadingHUDManager {
    static let shared = LoadingHUDManager()
    private var hudWindow: NSPanel?

    private init() {}

    func show() {
        DispatchQueue.main.async { [weak self] in
            // Remove existing HUD if present
            self?.hide()

            // Create a simple panel
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 140, height: 40),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

            // Create visual effect view for blur
            let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 140, height: 40))
            visualEffect.material = .hudWindow
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 8
            visualEffect.blendingMode = .behindWindow

            // Create stack view for content
            let stackView = NSStackView(frame: NSRect(x: 10, y: 8, width: 120, height: 24))
            stackView.orientation = .horizontal
            stackView.spacing = 8
            stackView.alignment = .centerY

            // Add spinner
            let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isIndeterminate = true
            spinner.startAnimation(nil)

            // Add label
            let label = NSTextField(labelWithString: "Correcting...")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .labelColor

            stackView.addArrangedSubview(spinner)
            stackView.addArrangedSubview(label)

            visualEffect.addSubview(stackView)
            panel.contentView = visualEffect

            // Position near mouse cursor
            let mouseLocation = NSEvent.mouseLocation
            let screenFrame = NSScreen.main?.frame ?? .zero

            var hudOrigin = CGPoint(
                x: mouseLocation.x + 15,
                y: mouseLocation.y - 60
            )

            // Keep on screen
            if hudOrigin.x + 140 > screenFrame.maxX {
                hudOrigin.x = screenFrame.maxX - 150
            }
            if hudOrigin.y < screenFrame.minY + 10 {
                hudOrigin.y = screenFrame.minY + 10
            }

            panel.setFrameOrigin(hudOrigin)

            // Show with fade
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 1.0
            }

            self?.hudWindow = panel
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.hudWindow else { return }

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
