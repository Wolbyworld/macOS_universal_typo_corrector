import SwiftUI

struct ComposerView: View {
    @EnvironmentObject var appState: AppState
    @State private var bulletText: String = ""
    @State private var isLoading: Bool = false
    
    // Callback when the user submits with ⌘Enter
    var onSubmit: (String) -> Void
    // Callback when the window is closed
    var onClose: () -> Void
    
    // Active window info if available
    var activeWindowInfo: (appName: String, windowTitle: String)?
    
    // Custom colors
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)
    
    // Custom text field with placeholder text styling
    struct CustomTextEditor: NSViewRepresentable {
        @Binding var text: String
        var isEditable: Bool = true
        
        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSTextView.scrollableTextView()
            let textView = scrollView.documentView as! NSTextView
            
            textView.delegate = context.coordinator
            textView.isEditable = isEditable
            textView.isSelectable = true
            textView.allowsUndo = true
            textView.font = NSFont.systemFont(ofSize: 14)
            textView.backgroundColor = NSColor.textBackgroundColor
            textView.drawsBackground = true
            textView.isRichText = false
            textView.autoresizingMask = [.width]
            textView.textContainerInset = NSSize(width: 10, height: 10)
            
            // Improve the look of the text view
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            
            // Initialize with empty text
            textView.string = ""
            textView.textColor = NSColor.textColor
            
            return scrollView
        }
        
        func updateNSView(_ nsView: NSScrollView, context: Context) {
            // No update needed
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, NSTextViewDelegate {
            var parent: CustomTextEditor
            
            init(_ parent: CustomTextEditor) {
                self.parent = parent
                super.init()
            }
            
            func textDidChange(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView else { return }
                
                // Safe update of the binding
                DispatchQueue.main.async {
                    self.parent.text = textView.string
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Minimalist bullet text editor
                CustomTextEditor(text: $bulletText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Footer with keyboard hints
                HStack {
                    Text("⌘Return to generate • Escape to cancel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        isLoading = true
                        onSubmit(bulletText)
                    }) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                        }
                    }
                    .disabled(bulletText.isEmpty || isLoading)
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.return, modifiers: [.command])
                }
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(minWidth: 450, minHeight: 250)
        .onAppear {
            // Auto-focus the text field immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let windows = NSApplication.shared.windows
                if let window = windows.first(where: { $0.isKeyWindow }) {
                    if let contentView = window.contentView {
                        // Find the NSTextView inside our view hierarchy and make it first responder
                        if let textView = findTextView(in: contentView) {
                            window.makeFirstResponder(textView)
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to find the NSTextView in the view hierarchy
    private func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        
        for subview in view.subviews {
            if let textView = findTextView(in: subview) {
                return textView
            }
        }
        
        return nil
    }
}

// Preview provider for SwiftUI Canvas
struct ComposerView_Previews: PreviewProvider {
    static var previews: some View {
        ComposerView(
            onSubmit: { _ in },
            onClose: {},
            activeWindowInfo: ("Safari", "Apple - Official Website")
        )
        .environmentObject(AppState())
    }
} 