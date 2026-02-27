import Foundation
import AppKit

class ClipboardManager {
    private let pasteboard = NSPasteboard.general
    private var originalItems: [NSPasteboardItem]?
    private var originalTypes: [NSPasteboard.PasteboardType]?
    private var originalChangeCount: Int = 0
    private var savedClipboardSuccessfully = false
    
    func getChangeCount() -> Int {
        return pasteboard.changeCount
    }
    
    func saveCurrentClipboard() async throws {
        self.originalChangeCount = pasteboard.changeCount
        self.savedClipboardSuccessfully = false // Reset flag
        print("ClipboardManager: Saving clipboard with change count: \(originalChangeCount)")
        
        if let items = pasteboard.pasteboardItems, !items.isEmpty {
            // Perform a deep copy of items
            self.originalItems = items.compactMap { item in
                let newItem = NSPasteboardItem()
                var copiedSomething = false
                for type in item.types {
                    if let data = item.data(forType: type) {
                        newItem.setData(data, forType: type)
                        copiedSomething = true
                    }
                }
                return copiedSomething ? newItem : nil
            }
            self.originalTypes = pasteboard.types
            
            if let items = self.originalItems, !items.isEmpty {
                 print("ClipboardManager: Saved \(items.count) clipboard items with \(pasteboard.types?.count ?? 0) types")
                 self.savedClipboardSuccessfully = true
            } else {
                 print("ClipboardManager: Failed to copy any data from clipboard items")
                 self.originalItems = nil
                 self.originalTypes = nil
            }
        } else {
            print("ClipboardManager: No items in clipboard to save")
            self.originalItems = nil
            self.originalTypes = nil
        }
    }
    
    func restoreOriginalClipboardIfNeeded() async throws {
        guard savedClipboardSuccessfully,
              let originalItems = originalItems, 
              let originalTypes = originalTypes else {
            print("ClipboardManager: No valid saved clipboard to restore or save failed initially")
            // Only throw if we actually intended to save something
            if savedClipboardSuccessfully { throw ClipboardError.noSavedClipboard }
            return
        }
        
        print("ClipboardManager: Restoring clipboard from \(originalItems.count) saved items")
        
        pasteboard.clearContents()
        let success = pasteboard.writeObjects(originalItems)
        
        if !success {
            print("ClipboardManager: Failed to write original objects back to clipboard")
        } else {
            print("ClipboardManager: Successfully restored original clipboard")
        }
        
        // Clear our saved clipboard state
        self.originalItems = nil
        self.originalTypes = nil
        self.savedClipboardSuccessfully = false
    }
    
    func waitForChange(since initialCount: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        var currentCount = pasteboard.changeCount
        
        while currentCount == initialCount && Date() < deadline {
            // Check frequently
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            currentCount = pasteboard.changeCount
        }
        
        let changed = currentCount > initialCount
        if changed {
            print("ClipboardManager: Change detected! New count: \(currentCount)")
        } else {
            print("ClipboardManager: Timed out waiting for clipboard change. Count remained \(currentCount). Initial was \(initialCount).")
        }
        return changed
    }
    
    func getClipboardText() -> String? {
        if let string = pasteboard.string(forType: .string) {
            print("ClipboardManager: Retrieved text from clipboard, length: \(string.count)")
            return string
        } else {
            print("ClipboardManager: No text found in clipboard")
            return nil
        }
    }
    
    func getRichText() -> NSAttributedString? {
        print("ClipboardManager: Attempting to get rich text")
        
        if let rtfData = pasteboard.data(forType: .rtf) {
            do {
                let attrString = try NSAttributedString(data: rtfData, options: [:], documentAttributes: nil)
                print("ClipboardManager: Retrieved RTF text, length: \(attrString.length)")
                return attrString
            } catch {
                print("ClipboardManager: Error converting RTF data: \(error)")
            }
        }
        
        if let htmlData = pasteboard.data(forType: .html) {
            do {
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.html
                ]
                let attrString = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
                print("ClipboardManager: Retrieved HTML text, length: \(attrString.length)")
                return attrString
            } catch {
                print("ClipboardManager: Error converting HTML data: \(error)")
            }
        }
        
        print("ClipboardManager: No rich text found in clipboard")
        return nil
    }
    
    func setClipboardText(_ text: String) {
        print("ClipboardManager: Setting clipboard text, length: \(text.count)")

        // Check if plain text only mode is enabled
        let plainTextOnly = UserDefaults.standard.bool(forKey: "plainTextOnly")

        if plainTextOnly {
            // Plain text only mode - skip all formatting
            pasteboard.clearContents()
            let success = pasteboard.setString(text, forType: .string)
            print("ClipboardManager: Set plain text only result: \(success)")
            return
        }

        // CRITICAL: Get rich text BEFORE clearing clipboard
        let originalRichText = getRichText()

        // Start a new pasteboard writing session
        pasteboard.clearContents()

        // 1. Always set plain text
        let ptSuccess = pasteboard.setString(text, forType: .string)
        print("ClipboardManager: Set plain text result: \(ptSuccess)")

        // 2. Always set clean HTML with <br> for newlines
        //    This ensures contentEditable editors (Gmail, Notion, etc.) preserve line breaks.
        //    NSAttributedString HTML export produces heavy Cocoa-specific markup that
        //    web editors may strip, so we use minimal HTML instead.
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        let html = "<html><body>\(escaped)</body></html>"
        if let htmlData = html.data(using: .utf8) {
            let htmlSuccess = pasteboard.setData(htmlData, forType: .html)
            print("ClipboardManager: Set HTML result: \(htmlSuccess)")
        }

        // 3. If original had rich text, also set RTF for native rich text apps (Pages, TextEdit, etc.)
        if let originalRichText = originalRichText,
           text.count > 0, originalRichText.length > 0 {
            print("ClipboardManager: Preserving RTF formatting")
            let attributedString = NSMutableAttributedString(string: text)
            let originalRange = NSRange(location: 0, length: originalRichText.length)

            originalRichText.enumerateAttributes(in: originalRange, options: []) { attributes, attrRange, _ in
                let newTextLength = attributedString.length
                let newRange = NSRange(
                    location: min(attrRange.location, newTextLength),
                    length: min(attrRange.length, max(0, newTextLength - attrRange.location))
                )
                if newRange.location < newTextLength && newRange.length > 0 {
                    attributedString.addAttributes(attributes, range: newRange)
                }
            }

            do {
                let rtfOptions: [NSAttributedString.DocumentAttributeKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.rtf
                ]
                let rtfData = try attributedString.data(
                    from: NSRange(location: 0, length: attributedString.length),
                    documentAttributes: rtfOptions)
                let rtfSuccess = pasteboard.setData(rtfData, forType: .rtf)
                print("ClipboardManager: Set RTF result: \(rtfSuccess)")
            } catch {
                print("ClipboardManager: Error setting RTF: \(error)")
            }
        }
    }
}

enum ClipboardError: Error {
    case noSavedClipboard
} 