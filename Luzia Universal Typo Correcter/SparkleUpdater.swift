import Foundation
import Sparkle

// We need to implement both protocols to handle updates correctly
class SparkleUpdater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private var updaterController: SPUStandardUpdaterController
    
    override init() {
        // Create the updater controller with self as both delegates
        // This is the correct way to set up Sparkle 2.x
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil, // Will be set after init
            userDriverDelegate: nil // Will be set after init
        )
        
        super.init()
        
        // Set up delegates properly by creating a new controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
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