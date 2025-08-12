import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    private let defaultSystemPrompt = """
    You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.
    
    Return ONLY the corrected text without explanations or additional commentary.
    """
    
    // User-configurable state
    @Published var apiKey: String = ""
    @Published var systemPrompt: String = ""
    @Published var selectedModel: String = "gpt-5-mini"
    @Published var globalShortcut: String = "⇧⌘G"
    @Published var excludedApps: [String] = []
    @Published var openOnStartup: Bool = false
    @Published var reasoningEffort: String = "minimum"

    // Available choices
    let availableModels = ["gpt-5-mini", "gpt-5", "gpt-5-nano", "gpt-4.1","gpt-4.1-mini"]

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load initial values from UserDefaults
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? defaultSystemPrompt
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-5-mini"
        self.globalShortcut = UserDefaults.standard.string(forKey: "globalShortcut") ?? "⇧⌘G"
        self.openOnStartup = UserDefaults.standard.bool(forKey: "openOnStartup")
        self.reasoningEffort = UserDefaults.standard.string(forKey: "reasoningEffort") ?? "minimum"

        if let data = UserDefaults.standard.data(forKey: "excludedApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedApps = decoded
        }

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


