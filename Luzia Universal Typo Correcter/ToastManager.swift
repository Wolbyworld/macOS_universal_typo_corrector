import SwiftUI

class ToastManager: ObservableObject {
    // Ensure isShowing is always false by default to prevent welcome toasts
    @Published private(set) var isShowing = false
    @Published private(set) var message = ""
    @Published private(set) var icon: String = "doc.on.clipboard"
    
    // Don't show any toast during initialization
    init() {
        // Explicitly set initial state to hidden
        self.isShowing = false
        self.message = ""
    }
    
    func showToast(message: String, duration: TimeInterval = 2.5, icon: String = "doc.on.clipboard.fill") {
        // Clear any existing toast first
        withAnimation {
            self.isShowing = false
        }
        
        // Set new toast properties
        self.message = message
        self.icon = icon
        
        // Small delay before showing to prevent conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                self.isShowing = true
            }
            
            // Hide after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation {
                    self.isShowing = false
                }
            }
        }
    }
    
    // Add a method to explicitly hide any toast
    func hideToast() {
        withAnimation {
            self.isShowing = false
        }
    }
}

struct ToastView: View {
    @ObservedObject var toastManager: ToastManager
    
    var body: some View {
        // Only show if explicitly triggered
        if toastManager.isShowing {
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: toastManager.icon)
                        .font(.system(size: 14))
                    
                    Text(toastManager.message)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.windowBackgroundColor).opacity(0.9))
                .cornerRadius(16)
                .shadow(radius: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
                
                Spacer()
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            // Empty view when not showing
            EmptyView()
        }
    }
} 