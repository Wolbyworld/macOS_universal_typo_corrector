import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "textformat.abc.dottedunderline")
                    .font(.title)
                
                Text("Luzia Typo Correcter")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.bottom, 5)
            
            Divider()
            
            // Quick status section
            Group {
                HStack {
                    Text("API Key:")
                        .bold()
                    
                    Text(appState.apiKey.isEmpty ? "Not Set" : "Configured")
                        .foregroundColor(appState.apiKey.isEmpty ? .red : .green)
                    
                    if appState.apiKey.isEmpty {
                        Button("Set") {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                
                HStack {
                    Text("Model:")
                        .bold()
                    
                    Text(appState.selectedModel)
                }
                
                HStack {
                    Text("Shortcut:")
                        .bold()
                    
                    Text("⇧⌘G")
                }
            }
            
            Divider()
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Open Preferences...") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .frame(maxWidth: .infinity)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 250)
    }
} 