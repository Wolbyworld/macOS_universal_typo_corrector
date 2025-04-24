import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var newExcludedApp = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        TabView {
            // General Tab
            Form {
                Section("API Settings") {
                    SecureField("OpenAI API Key", text: $appState.apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Model", selection: $appState.selectedModel) {
                        ForEach(appState.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                
                Section("System Prompt") {
                    TextEditor(text: $appState.systemPrompt)
                        .font(.system(size: 14))
                        .frame(minHeight: 100)
                    
                    Button("Reset to Default") {
                        appState.systemPrompt = """
                        You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.
                        
                        Return ONLY the corrected text without explanations or additional commentary.
                        """
                    }
                }
                
                Section("Global Shortcut") {
                    Text("⇧⌘G (Default)")
                        .foregroundColor(.secondary)
                    Text("Note: Custom shortcut configuration coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // Excluded Apps Tab
            Form {
                Section("Add Application") {
                    HStack {
                        TextField("Bundle Identifier", text: $newExcludedApp)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            if !newExcludedApp.isEmpty {
                                appState.addExcludedApp(newExcludedApp.trimmingCharacters(in: .whitespacesAndNewlines))
                                newExcludedApp = ""
                            }
                        }
                        .disabled(newExcludedApp.isEmpty)
                    }
                    
                    Button("Add Current App") {
                        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
                           let bundleId = frontmostApp.bundleIdentifier {
                            appState.addExcludedApp(bundleId)
                            alertMessage = "Added: \(frontmostApp.localizedName ?? bundleId)"
                            showingAlert = true
                        } else {
                            alertMessage = "Couldn't detect current app"
                            showingAlert = true
                        }
                    }
                }
                
                Section("Excluded Applications") {
                    if appState.excludedApps.isEmpty {
                        Text("No excluded apps")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        List {
                            ForEach(appState.excludedApps, id: \.self) { bundleId in
                                HStack {
                                    Text(bundleId)
                                    Spacer()
                                    Button(action: {
                                        appState.removeExcludedApp(bundleId)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Excluded Apps", systemImage: "x.circle")
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            }
            
            // About Tab
            VStack(spacing: 20) {
                Image(systemName: "textformat.abc.dottedunderline")
                    .font(.system(size: 64))
                
                Text("Luzia Universal Typo Correcter")
                    .font(.title)
                
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Text("A lightweight app that corrects typos in any text field.\n" +
                     "Simply select text with your cursor and press ⇧⌘G.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
                
                Text("© 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
} 