import Foundation
import ServiceManagement

class StartupManager {
    private let bundleIdentifier = Bundle.main.bundleIdentifier!
    
    enum StartupError: Error, LocalizedError {
        case registrationFailed
        case unregistrationFailed
        case unsupportedSystem
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .registrationFailed:
                return "Failed to register app for startup. Please check System Settings > Login Items."
            case .unregistrationFailed:
                return "Failed to remove app from startup items."
            case .unsupportedSystem:
                return "This feature requires macOS 11.0 or later."
            case .permissionDenied:
                return "Permission denied. Please allow the app in System Settings > Login Items."
            }
        }
    }
    
    // MARK: - Public Methods
    
    func enableStartup() throws {
        print("StartupManager: Attempting to enable startup for bundle: \(bundleIdentifier)")
        
        if #available(macOS 13.0, *) {
            try enableStartupModern()
        } else {
            try enableStartupLegacy()
        }
        
        print("StartupManager: Successfully enabled startup")
    }
    
    func disableStartup() throws {
        print("StartupManager: Attempting to disable startup for bundle: \(bundleIdentifier)")
        
        if #available(macOS 13.0, *) {
            try disableStartupModern()
        } else {
            try disableStartupLegacy()
        }
        
        print("StartupManager: Successfully disabled startup")
    }
    
    func isStartupEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return isStartupEnabledModern()
        } else {
            return isStartupEnabledLegacy()
        }
    }
    
    // MARK: - Modern Implementation (macOS 13+)
    
    @available(macOS 13.0, *)
    private func enableStartupModern() throws {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("StartupManager Error (Modern): Failed to register - \(error.localizedDescription)")
            throw StartupError.registrationFailed
        }
    }
    
    @available(macOS 13.0, *)
    private func disableStartupModern() throws {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("StartupManager Error (Modern): Failed to unregister - \(error.localizedDescription)")
            throw StartupError.unregistrationFailed
        }
    }
    
    @available(macOS 13.0, *)
    private func isStartupEnabledModern() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    // MARK: - Legacy Implementation (macOS 11-12)
    
    private func enableStartupLegacy() throws {
        let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
        if !success {
            print("StartupManager Error (Legacy): Failed to enable login item")
            throw StartupError.registrationFailed
        }
    }
    
    private func disableStartupLegacy() throws {
        let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
        if !success {
            print("StartupManager Error (Legacy): Failed to disable login item")
            throw StartupError.unregistrationFailed
        }
    }
    
    private func isStartupEnabledLegacy() -> Bool {
        // For legacy systems, we'll check if the app is in the login items list
        // This is a simplified check - in practice, this is harder to reliably determine
        // with the legacy API, but for our use case it's sufficient to rely on our 
        // UserDefaults state as the source of truth
        return UserDefaults.standard.bool(forKey: "openOnStartup")
    }
} 