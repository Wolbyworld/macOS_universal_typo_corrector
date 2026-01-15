import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    private let defaultSystemPrompt = """
    Fix typos and grammar errors. Execute any instructions in <<>>. Return ONLY the final text.

    INLINE INSTRUCTIONS <<>>:
    Text inside <<>> are commands for you - execute them and remove the markers.

    EXAMPLES:
    ✗ "Meeting at 10PM Madrid tim <<add brazil time>>"
    ✓ "Meeting at 10PM Madrid time (3PM Brazil time)"
    (Fixed: tim→time. Executed: added Brazil time. Removed: <<>> markers)

    ✗ "The API returns JSON data <<explain what JSON is>>"
    ✓ "The API returns JSON data (JavaScript Object Notation, a lightweight data format)"
    (Executed instruction, removed markers)

    ✗ "gonna meet him tomorrow <<make this more formal>>"
    ✓ "I will meet with him tomorrow"
    (Executed: formalized. Note: <<>> overrides normal preservation rules)

    RULES:
    • Fix typos/grammar in main text
    • Execute all <<instructions>>
    • Remove <<>> markers from output
    • Instructions override normal rules (can change tone, add info, etc.)
    • If no errors/instructions, return unchanged
    """
    
    // User-configurable state
    @Published var apiKey: String = ""
    @Published var systemPrompt: String = ""
    @Published var selectedModel: String = "openai/gpt-oss-20b"
    @Published var globalShortcut: String = "⇧⌘G"
    @Published var excludedApps: [String] = []
    @Published var openOnStartup: Bool = false
    @Published var reasoningEffort: String = "minimum"

    // Proxy mode configuration
    @Published var useProxy: Bool = false
    @Published var proxyURL: String = ""
    @Published var proxySecret: String = ""

    // Computed properties for enterprise/bundled configuration
    var isEnterpriseMode: Bool {
        guard let enterpriseMode = Bundle.main.object(forInfoDictionaryKey: "LuziaEnterpriseMode") as? String else {
            return false
        }
        return enterpriseMode.uppercased() == "YES"
    }

    var bundledProxyURL: String? {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "LuziaProxyURL") as? String,
              !url.isEmpty,
              !url.starts(with: "$") else { // Check for unsubstituted variable
            return nil
        }
        return url
    }

    var bundledProxySecret: String? {
        guard let hash = Bundle.main.object(forInfoDictionaryKey: "LuziaProxySecretHash") as? String,
              !hash.isEmpty,
              !hash.starts(with: "$") else {
            return nil
        }
        // Deobfuscate: XOR with bundle identifier
        return deobfuscate(hash)
    }

    // Clipboard settings
    @Published var plainTextOnly: Bool = false

    // Advanced timing settings (in milliseconds)
    @Published var prePasteDelayShort: Int = 30
    @Published var prePasteDelayLong: Int = 80
    @Published var postPasteDelayShort: Int = 150
    @Published var postPasteDelayLong: Int = 400

    // Available choices
    let availableModels = [
        "openai/gpt-oss-20b",
        "openai/gpt-oss-120b",
        "gpt-5-mini",
        "gpt-5",
        "gpt-5-nano",
        "gpt-4.1",
        "gpt-4.1-mini"
    ]

    // Display names for models (shown in UI)
    let modelDisplayNames: [String: String] = [
        "openai/gpt-oss-20b": "GPT-OSS 20B (Fast)",
        "openai/gpt-oss-120b": "GPT-OSS 120B (Quality)",
        "gpt-5-mini": "GPT-5 Mini",
        "gpt-5": "GPT-5",
        "gpt-5-nano": "GPT-5 Nano",
        "gpt-4.1": "GPT-4.1",
        "gpt-4.1-mini": "GPT-4.1 Mini"
    ]

    func displayName(for model: String) -> String {
        modelDisplayNames[model] ?? model
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load initial values from UserDefaults
        // No default API key - users must provide their own
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""

        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? defaultSystemPrompt
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "openai/gpt-oss-20b"
        self.globalShortcut = UserDefaults.standard.string(forKey: "globalShortcut") ?? "⇧⌘G"
        self.openOnStartup = UserDefaults.standard.bool(forKey: "openOnStartup")
        self.reasoningEffort = UserDefaults.standard.string(forKey: "reasoningEffort") ?? "minimum"

        // Load proxy configuration
        // Priority: 1) Bundled config, 2) Keychain, 3) UserDefaults (for migration)
        if let bundledURL = bundledProxyURL, let bundledSecret = bundledProxySecret {
            // Enterprise build with bundled configuration
            self.useProxy = true
            self.proxyURL = bundledURL
            self.proxySecret = bundledSecret
        } else {
            // Standard build - load from user preferences
            self.useProxy = UserDefaults.standard.bool(forKey: "useProxy")
            self.proxyURL = UserDefaults.standard.string(forKey: "proxyURL") ?? ""

            // Try Keychain first, then UserDefaults (for migration)
            if let keychainSecret = KeychainHelper.shared.retrieve(forKey: "proxySecret") {
                self.proxySecret = keychainSecret
            } else {
                // Migration: Check old UserDefaults location
                let oldSecret = UserDefaults.standard.string(forKey: "proxySecret") ?? ""
                self.proxySecret = oldSecret
                if !oldSecret.isEmpty {
                    // Migrate to Keychain
                    _ = KeychainHelper.shared.save(oldSecret, forKey: "proxySecret")
                    UserDefaults.standard.removeObject(forKey: "proxySecret")
                }
            }
        }

        // Load clipboard settings
        self.plainTextOnly = UserDefaults.standard.bool(forKey: "plainTextOnly")

        // Load advanced timing settings (defaults: conservative Phase 1 values)
        self.prePasteDelayShort = UserDefaults.standard.integer(forKey: "prePasteDelayShort")
        if self.prePasteDelayShort == 0 { self.prePasteDelayShort = 30 } // Default if not set

        self.prePasteDelayLong = UserDefaults.standard.integer(forKey: "prePasteDelayLong")
        if self.prePasteDelayLong == 0 { self.prePasteDelayLong = 80 }

        self.postPasteDelayShort = UserDefaults.standard.integer(forKey: "postPasteDelayShort")
        if self.postPasteDelayShort == 0 { self.postPasteDelayShort = 150 }

        self.postPasteDelayLong = UserDefaults.standard.integer(forKey: "postPasteDelayLong")
        if self.postPasteDelayLong == 0 { self.postPasteDelayLong = 400 }

        if let data = UserDefaults.standard.data(forKey: "excludedApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedApps = decoded
        }

        // Save defaults to UserDefaults if they weren't already there
        // This ensures OpenAIService can read them directly from UserDefaults
        UserDefaults.standard.set(self.apiKey, forKey: "apiKey")
        UserDefaults.standard.set(self.systemPrompt, forKey: "systemPrompt")
        UserDefaults.standard.set(self.selectedModel, forKey: "selectedModel")

        setupObservers()
    }

    private func setupObservers() {
        $apiKey.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "apiKey")
        }.store(in: &cancellables)

        $systemPrompt.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "systemPrompt")
        }.store(in: &cancellables)

        $selectedModel.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "selectedModel")
        }.store(in: &cancellables)

        $globalShortcut.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "globalShortcut")
        }.store(in: &cancellables)

        $excludedApps.sink { newValue in
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "excludedApps")
        }.store(in: &cancellables)

        $openOnStartup.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "openOnStartup")
        }.store(in: &cancellables)

        $reasoningEffort.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "reasoningEffort")
        }.store(in: &cancellables)

        $plainTextOnly.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "plainTextOnly")
        }.store(in: &cancellables)

        $prePasteDelayShort.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "prePasteDelayShort")
        }.store(in: &cancellables)

        $prePasteDelayLong.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "prePasteDelayLong")
        }.store(in: &cancellables)

        $postPasteDelayShort.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "postPasteDelayShort")
        }.store(in: &cancellables)

        $postPasteDelayLong.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "postPasteDelayLong")
        }.store(in: &cancellables)

        $useProxy.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "useProxy")
        }.store(in: &cancellables)

        $proxyURL.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: "proxyURL")
        }.store(in: &cancellables)

        $proxySecret
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { secret in
                if secret.isEmpty {
                    _ = KeychainHelper.shared.delete(forKey: "proxySecret")
                } else {
                    _ = KeychainHelper.shared.save(secret, forKey: "proxySecret")
                }
            }
            .store(in: &cancellables)
    }

    // Helper to deobfuscate bundled secret
    private func deobfuscate(_ obfuscated: String) -> String {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let data = Data(base64Encoded: obfuscated) else {
            return ""
        }

        let keyData = bundleID.data(using: .utf8) ?? Data()
        var result = Data()

        for (i, byte) in data.enumerated() {
            let keyByte = keyData[i % keyData.count]
            result.append(byte ^ keyByte)
        }

        return String(data: result, encoding: .utf8) ?? ""
    }

    // Helpers
    func isAppExcluded(_ bundleId: String) -> Bool {
        return excludedApps.contains(bundleId)
    }

    func addExcludedApp(_ bundleId: String) {
        if !excludedApps.contains(bundleId) {
            excludedApps.append(bundleId)
        }
    }

    func removeExcludedApp(_ bundleId: String) {
        excludedApps.removeAll { $0 == bundleId }
    }
}


