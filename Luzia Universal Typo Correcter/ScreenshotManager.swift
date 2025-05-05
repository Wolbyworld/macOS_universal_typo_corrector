import Foundation
import AppKit

class ScreenshotManager {
    
    enum ScreenshotError: Error {
        case captureFailure
        case imageConversionFailure
        case noActiveWindow
    }
    
    /// Captures all screens individually
    /// - Returns: Array of NSImage, one for each screen
    /// - Throws: ScreenshotError if the capture fails
    func captureAllScreensIndividually() throws -> [NSImage] {
        let screens = NSScreen.screens
        var screenImages = [NSImage]()
        
        print("ScreenshotManager: Capturing \(screens.count) screens individually")
        
        for (index, screen) in screens.enumerated() {
            let displayID = getDisplayIDFromScreen(screen)
            print("ScreenshotManager: Capturing screen \(index) with ID \(displayID)")
            
            if let image = CGDisplayCreateImage(displayID) {
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                screenImages.append(nsImage)
                print("ScreenshotManager: Successfully captured screen \(index) with size: \(image.width)x\(image.height)")
            } else {
                print("ScreenshotManager: Failed to capture screen \(index), using fallback method")
                
                // Fallback to window list method for this screen
                let screenRect = screen.frame
                if let cgImage = CGWindowListCreateImage(screenRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) {
                    let nsImage = NSImage(cgImage: cgImage, size: screenRect.size)
                    screenImages.append(nsImage)
                    print("ScreenshotManager: Successfully captured screen \(index) with fallback method")
                } else {
                    print("ScreenshotManager: Failed to capture screen \(index) with fallback method as well")
                }
            }
        }
        
        if screenImages.isEmpty {
            throw ScreenshotError.captureFailure
        }
        
        return screenImages
    }
    
    /// Helper function to get CGDirectDisplayID from NSScreen
    private func getDisplayIDFromScreen(_ screen: NSScreen) -> CGDirectDisplayID {
        var displayID: CGDirectDisplayID = 0
        
        // Try to get the display ID from the screen's device description
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            displayID = screenNumber.uint32Value
        } else {
            // Fallback: get main display ID
            displayID = CGMainDisplayID()
        }
        
        return displayID
    }
    
    /// Captures the entire screen (all displays combined)
    /// - Returns: NSImage of the entire screen
    /// - Throws: ScreenshotError if the capture fails
    func captureEntireScreen() throws -> NSImage {
        // Create a screenshot of all screens combined
        let screens = NSScreen.screens
        
        // Calculate the union of all screen frames
        var unionRect = NSRect.zero
        for screen in screens {
            unionRect = NSUnionRect(unionRect, screen.frame)
        }
        
        // Adjust to ensure all screens are included
        unionRect.size.width = ceil(unionRect.size.width)
        unionRect.size.height = ceil(unionRect.size.height)
        
        // Capture the screen content for the unionRect
        guard let cgImage = CGWindowListCreateImage(
            unionRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            print("ScreenshotManager: Failed to create CGImage for screen capture")
            throw ScreenshotError.captureFailure
        }
        
        // Convert to NSImage
        let image = NSImage(cgImage: cgImage, size: unionRect.size)
        print("ScreenshotManager: Successfully captured entire screen with size: \(unionRect.size)")
        return image
    }
    
    /// Alternative method to capture screen using NSBitmapImageRep
    /// - Returns: NSImage of the entire screen
    /// - Throws: ScreenshotError if the capture fails
    func captureEntireScreenWithBitmap() throws -> NSImage {
        // Use main screen for simplicity (we could combine all screens if needed)
        guard let mainScreen = NSScreen.main else {
            print("ScreenshotManager: Failed to get main screen")
            throw ScreenshotError.captureFailure
        }
        
        // Create bitmap rep with screen dimensions
        let screenRect = mainScreen.frame
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(screenRect.width),
            pixelsHigh: Int(screenRect.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let bitmap = bitmap else {
            print("ScreenshotManager: Failed to create bitmap for screen capture")
            throw ScreenshotError.captureFailure
        }
        
        // Create graphics context from bitmap
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            print("ScreenshotManager: Failed to create graphics context")
            throw ScreenshotError.captureFailure
        }
        
        NSGraphicsContext.current = context
        
        // Capture screen contents
        guard let windowImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            NSGraphicsContext.restoreGraphicsState()
            print("ScreenshotManager: Failed to create window image")
            throw ScreenshotError.captureFailure
        }
        
        let nsImage = NSImage(cgImage: windowImage, size: screenRect.size)
        nsImage.draw(in: NSRect(x: 0, y: 0, width: screenRect.width, height: screenRect.height))
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create final image
        let finalImage = NSImage(size: screenRect.size)
        finalImage.addRepresentation(bitmap)
        
        print("ScreenshotManager: Successfully captured entire screen with bitmap approach")
        return finalImage
    }
    
    /// A more reliable method using CGDisplay API
    /// - Returns: NSImage of the entire screen
    /// - Throws: ScreenshotError if the capture fails
    func captureAllScreensWithCGDisplay() throws -> NSImage {
        // Get the main display ID
        guard let mainDisplayID = CGMainDisplayID() as CGDirectDisplayID? else {
            print("ScreenshotManager: Failed to get main display ID")
            throw ScreenshotError.captureFailure
        }
        
        // Get a list of all active display IDs
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        
        if result != CGError.success {
            print("ScreenshotManager: Failed to get display count")
            throw ScreenshotError.captureFailure
        }
        
        let maxDisplays = Int(displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: maxDisplays)
        result = CGGetActiveDisplayList(UInt32(maxDisplays), &activeDisplays, &displayCount)
        
        if result != CGError.success {
            print("ScreenshotManager: Failed to get active displays")
            throw ScreenshotError.captureFailure
        }
        
        print("ScreenshotManager: Found \(displayCount) displays")
        
        // Create image for main display first
        guard let image = CGDisplayCreateImage(mainDisplayID) else {
            print("ScreenshotManager: Failed to create image for main display")
            throw ScreenshotError.captureFailure
        }
        
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        print("ScreenshotManager: Successfully captured screen with CGDisplay API: \(image.width)x\(image.height)")
        return nsImage
    }
    
    /// Gets the active window information
    /// - Returns: Tuple containing the window ID, app name, and window title
    /// - Throws: ScreenshotError if there's no active window
    func getActiveWindowInfo() throws -> (windowID: CGWindowID, appName: String, windowTitle: String) {
        // Get window list with active window only
        let options = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        // Find the frontmost window (typically the first one in the list with kCGWindowLayer = 0)
        for window in windowList {
            let windowLayer = window[kCGWindowLayer as String] as? Int ?? 999
            if windowLayer == 0 {
                let windowID = window[kCGWindowNumber as String] as? CGWindowID ?? 0
                let appName = window[kCGWindowOwnerName as String] as? String ?? "Unknown App"
                let windowTitle = window[kCGWindowName as String] as? String ?? "Untitled Window"
                
                // Additional information for debugging
                let bounds = window[kCGWindowBounds as String] as? [String: Any]
                let position = "Bounds: \(bounds ?? [:])"
                
                print("ScreenshotManager: Active window - \(appName): \(windowTitle) (\(position))")
                return (windowID, appName, windowTitle)
            }
        }
        
        print("ScreenshotManager: Failed to find active window")
        throw ScreenshotError.noActiveWindow
    }
    
    /// Captures a specific window by its ID with better error handling
    /// - Parameter windowID: The CGWindowID of the window to capture
    /// - Returns: NSImage of the window
    /// - Throws: ScreenshotError if the capture fails
    func captureWindow(windowID: CGWindowID) throws -> NSImage {
        print("ScreenshotManager: Attempting to capture window with ID \(windowID)")
        
        // Check screen recording permission first
        if !CGPreflightScreenCaptureAccess() {
            print("ScreenshotManager: Screen recording permission not granted")
            _ = CGRequestScreenCaptureAccess()
            throw ScreenshotError.captureFailure
        }
        
        // First try with optionIncludingWindow
        if let cgImage = CGWindowListCreateImage(
            CGRect.null,
            .optionIncludingWindow,
            windowID,
            .bestResolution
        ) {
            let size = CGSize(width: cgImage.width, height: cgImage.height)
            let image = NSImage(cgImage: cgImage, size: size)
            print("ScreenshotManager: Successfully captured window with ID \(windowID)")
            return image
        }
        
        print("ScreenshotManager: Failed with optionIncludingWindow, trying with optionOnScreenOnly")
        
        // Try to get window bounds first
        let options = CGWindowListOption.optionOnScreenOnly
        let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        for windowInfo in windowInfoList {
            let thisWindowID = windowInfo[kCGWindowNumber as String] as? CGWindowID ?? 0
            if thisWindowID == windowID {
                // Found our window, extract bounds
                if let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                   let x = bounds["X"] as? CGFloat,
                   let y = bounds["Y"] as? CGFloat,
                   let width = bounds["Width"] as? CGFloat,
                   let height = bounds["Height"] as? CGFloat {
                    
                    let windowRect = CGRect(x: x, y: y, width: width, height: height)
                    print("ScreenshotManager: Found window bounds: \(windowRect)")
                    
                    // Now try to capture just this region of the screen
                    if let cgImage = CGWindowListCreateImage(
                        windowRect,
                        .optionOnScreenOnly,
                        kCGNullWindowID,
                        .bestResolution
                    ) {
                        let image = NSImage(cgImage: cgImage, size: windowRect.size)
                        print("ScreenshotManager: Successfully captured window region with ID \(windowID)")
                        return image
                    }
                }
            }
        }
        
        // If all else fails, try to get a list of windows and see what's available
        print("ScreenshotManager: Failed all capture methods, listing available windows:")
        let allWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for (index, window) in allWindows.enumerated() {
            let wid = window[kCGWindowNumber as String] as? CGWindowID ?? 0
            let name = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let title = window[kCGWindowName as String] as? String ?? "Untitled"
            print("Window \(index): ID \(wid) - \(name): \(title)")
        }
        
        print("ScreenshotManager: Failed to capture window with ID \(windowID)")
        throw ScreenshotError.captureFailure
    }
    
    /// Converts NSImage to PNG Data
    /// - Parameter image: The NSImage to convert
    /// - Returns: Data representation of the image in PNG format
    /// - Throws: ScreenshotError if conversion fails
    func pngDataFromImage(_ image: NSImage) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("ScreenshotManager: Failed to convert NSImage to CGImage")
            throw ScreenshotError.imageConversionFailure
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("ScreenshotManager: Failed to convert image to PNG data")
            throw ScreenshotError.imageConversionFailure
        }
        
        print("ScreenshotManager: Successfully converted image to PNG data")
        return pngData
    }
    
    /// Converts NSImage to JPEG Data with specified quality
    /// - Parameters:
    ///   - image: The NSImage to convert
    ///   - quality: JPEG quality (0.0 to 1.0)
    /// - Returns: Data representation of the image in JPEG format
    /// - Throws: ScreenshotError if conversion fails
    func jpegDataFromImage(_ image: NSImage, quality: CGFloat = 0.8) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("ScreenshotManager: Failed to convert NSImage to CGImage")
            throw ScreenshotError.imageConversionFailure
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            print("ScreenshotManager: Failed to convert image to JPEG data")
            throw ScreenshotError.imageConversionFailure
        }
        
        print("ScreenshotManager: Successfully converted image to JPEG data")
        return jpegData
    }
    
    /// Saves an image to a temporary file
    /// - Parameters:
    ///   - image: The NSImage to save
    ///   - format: The format to save it as ("png" or "jpeg")
    /// - Returns: URL of the saved temporary file
    /// - Throws: ScreenshotError if saving fails
    func saveImageToTemporaryFile(_ image: NSImage, format: String = "png") throws -> URL {
        // Create a temporary file URL
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let filename = "screenshot_\(Date().timeIntervalSince1970).\(format)"
        let fileURL = temporaryDirectory.appendingPathComponent(filename)
        
        let imageData: Data
        
        // Convert image to the specified format
        if format.lowercased() == "png" {
            imageData = try pngDataFromImage(image)
        } else {
            imageData = try jpegDataFromImage(image)
        }
        
        // Write to file
        try imageData.write(to: fileURL)
        print("ScreenshotManager: Saved image to \(fileURL.path)")
        
        return fileURL
    }
} 