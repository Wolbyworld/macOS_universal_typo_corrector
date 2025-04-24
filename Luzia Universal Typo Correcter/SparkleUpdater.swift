import Foundation
import Sparkle

// We need to implement both protocols to handle updates correctly
class SparkleUpdater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private var updaterController: SPUStandardUpdaterController
    
    override init() {
        // Create the updater controller with self as both delegates
        // This is the correct way to set up Sparkle 2.x
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false, // Changed to false to prevent automatic checks
            updaterDelegate: nil, // Will be set after init
            userDriverDelegate: nil // Will be set after init
        )
        
        super.init()
        
        // Set up delegates properly by creating a new controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false, // Changed to false to prevent automatic checks
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }
    
    func checkForUpdates() {
        // Only check if we have a valid URL
        if let feedURL = Bundle.main.infoDictionary?["SUFeedURL"] as? String,
           !feedURL.contains("your-domain.com") { // Don't check if using placeholder URL
            updaterController.checkForUpdates(nil)
        } else {
            print("Update check skipped: No valid appcast URL configured")
        }
    }
    
    // MARK: - SPUUpdaterDelegate methods
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate appcastItem: SUAppcastItem) {
        print("Update found: \(appcastItem.displayVersionString)")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        print("No update found")
    }
    
    // MARK: - SPUStandardUserDriverDelegate methods
    
    func standardUserDriverDidFinishUpdate(acknowledgedUpdate: Bool) {
        print("Update finished. Acknowledged: \(acknowledgedUpdate)")
    }
    
    func standardUserDriverWillShowModalAlert() {
        print("Will show modal alert")
    }
    
    func standardUserDriverDidShowModalAlert() {
        print("Did show modal alert")
    }
} 