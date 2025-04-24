import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    private let defaultSystemPrompt = """
    You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.
    
    Return ONLY the corrected text without explanations or additional commentary.
    """
    
    @Published var apiKey: String = ""
    @Published var systemPrompt: String = ""
    @Published var selectedModel: String = "gpt-4o"
    @Published var globalShortcut: String = "⇧⌘G"
    @Published var excludedApps: [String] = []
    
    let availableModels = ["gpt-4o", "gpt-4o-mini"]
    
    init() {
        // Load values from UserDefaults after properties are initialized
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? defaultSystemPrompt
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-4o"
        self.globalShortcut = UserDefaults.standard.string(forKey: "globalShortcut") ?? "⇧⌘G"
        
        if let data = UserDefaults.standard.data(forKey: "excludedApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedApps = decoded
        }
        
        // Setup UserDefaults observers
        setupObservers()
    }
    
    private func setupObservers() {
        $apiKey.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "apiKey")
        }.store(in: &cancellables)
        
        $systemPrompt.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "systemPrompt")
        }.store(in: &cancellables)
        
        $selectedModel.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "selectedModel")
        }.store(in: &cancellables)
        
        $globalShortcut.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "globalShortcut")
        }.store(in: &cancellables)
        
        $excludedApps.sink { [weak self] newValue in
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "excludedApps")
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
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
