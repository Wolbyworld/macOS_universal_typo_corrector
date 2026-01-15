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
                Section("API Configuration") {
                    // Show enterprise mode badge if applicable
                    if appState.isEnterpriseMode {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.blue)
                            Text("Enterprise Mode")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    // Option 1: Company Proxy
                    Button(action: {
                        appState.useProxy = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: appState.useProxy ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(appState.useProxy ? .accentColor : .gray)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Company Proxy")
                                    .foregroundColor(.primary)
                                if appState.isEnterpriseMode {
                                    Text("Pre-configured")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    // Option 2: Personal API Key
                    Button(action: {
                        appState.useProxy = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: !appState.useProxy ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(!appState.useProxy ? .accentColor : .gray)
                                .font(.system(size: 18))

                            Text("Personal OpenAI API Key")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    // Show API key field only when not using proxy
                    if !appState.useProxy {
                        SecureField("", text: $appState.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    Picker("Model", selection: $appState.selectedModel) {
                        ForEach(appState.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                Section("System Prompt") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $appState.systemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 200)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)

                        Button("Reset to Default") {
                            appState.systemPrompt = """
                            You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.

                            Return ONLY the corrected text without explanations or additional commentary.
                            """
                        }
                        .font(.caption)
                    }
                }
                
                Section("Global Shortcut") {
                    Text("⇧⌘G (Default)")
                        .foregroundColor(.secondary)
                    Text("Note: Custom shortcut configuration coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("App Behavior") {
                    Toggle("Open on Startup", isOn: $appState.openOnStartup)
                    Text("Automatically launch Luzia when you log into macOS")
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
            
            // Advanced Tab
            Form {
                Section("Timing Settings") {
                    Text("Adjust delays to optimize latency. Lower values = faster, but may fail on slow apps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pre-Paste Delay")
                            .font(.headline)
                        Text("Time between writing to clipboard and pasting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Text("Short (<120 chars):")
                                .frame(width: 140, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(appState.prePasteDelayShort) },
                                set: { appState.prePasteDelayShort = Int($0) }
                            ), in: 0...200, step: 5)
                            Text("\(appState.prePasteDelayShort)ms")
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Long (≥120 chars):")
                                .frame(width: 140, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(appState.prePasteDelayLong) },
                                set: { appState.prePasteDelayLong = Int($0) }
                            ), in: 0...200, step: 5)
                            Text("\(appState.prePasteDelayLong)ms")
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Post-Paste Delay")
                            .font(.headline)
                        Text("Wait after paste before restoring clipboard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Text("Short (<120 chars):")
                                .frame(width: 140, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(appState.postPasteDelayShort) },
                                set: { appState.postPasteDelayShort = Int($0) }
                            ), in: 0...1000, step: 10)
                            Text("\(appState.postPasteDelayShort)ms")
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Long (≥120 chars):")
                                .frame(width: 140, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(appState.postPasteDelayLong) },
                                set: { appState.postPasteDelayLong = Int($0) }
                            ), in: 0...1000, step: 10)
                            Text("\(appState.postPasteDelayLong)ms")
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presets")
                            .font(.headline)

                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Button("Conservative") {
                                    appState.prePasteDelayShort = 30
                                    appState.prePasteDelayLong = 80
                                    appState.postPasteDelayShort = 150
                                    appState.postPasteDelayLong = 400
                                }
                                .buttonStyle(.bordered)

                                Button("Balanced") {
                                    appState.prePasteDelayShort = 20
                                    appState.prePasteDelayLong = 50
                                    appState.postPasteDelayShort = 100
                                    appState.postPasteDelayLong = 250
                                }
                                .buttonStyle(.bordered)

                                Button("Aggressive") {
                                    appState.prePasteDelayShort = 10
                                    appState.prePasteDelayLong = 30
                                    appState.postPasteDelayShort = 50
                                    appState.postPasteDelayLong = 100
                                }
                                .buttonStyle(.bordered)

                                Button("Original") {
                                    appState.prePasteDelayShort = 50
                                    appState.prePasteDelayLong = 150
                                    appState.postPasteDelayShort = 300
                                    appState.postPasteDelayLong = 800
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Text("Conservative: Safe default • Balanced: Good speed • Aggressive: Fastest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tabItem {
                Label("Advanced", systemImage: "slider.horizontal.3")
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
        .frame(width: 600, height: 550)
    }
} 