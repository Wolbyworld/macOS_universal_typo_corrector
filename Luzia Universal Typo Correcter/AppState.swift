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
    @Published var selectedModel: String = "gpt-5-mini"
    @Published var globalShortcut: String = "⇧⌘G"
    @Published var excludedApps: [String] = []
    @Published var openOnStartup: Bool = false
    @Published var reasoningEffort: String = "minimum"

    // Advanced timing settings (in milliseconds)
    @Published var prePasteDelayShort: Int = 30
    @Published var prePasteDelayLong: Int = 80
    @Published var postPasteDelayShort: Int = 150
    @Published var postPasteDelayLong: Int = 400

    // Available choices
    let availableModels = ["gpt-5-mini", "gpt-5", "gpt-5-nano", "gpt-4.1","gpt-4.1-mini"]

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load initial values from UserDefaults
        // No default API key - users must provide their own
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""

        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? defaultSystemPrompt
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-5-mini"
        self.globalShortcut = UserDefaults.standard.string(forKey: "globalShortcut") ?? "⇧⌘G"
        self.openOnStartup = UserDefaults.standard.bool(forKey: "openOnStartup")
        self.reasoningEffort = UserDefaults.standard.string(forKey: "reasoningEffort") ?? "minimum"

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


