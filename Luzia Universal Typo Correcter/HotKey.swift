import Foundation
import Cocoa
import Carbon

class HotKey {
    // Static property to keep track of all registered hotkeys
    static private var registeredHotKeys: [UInt32: HotKey] = [:]
    
    // Add static methods to manage all hotkeys
    static func resetAllHotKeys() {
        print("⚠️ Performing global reset of ALL hotkeys")
        
        // Make a copy of the keys to avoid modification during iteration
        let identifiers = Array(registeredHotKeys.keys)
        
        // Unregister all hotkeys
        for identifier in identifiers {
            registeredHotKeys[identifier]?.unregister()
            print("Unregistered hotkey with ID \(identifier)")
        }
        
        // Clear the registration dictionary
        registeredHotKeys.removeAll()
        print("Cleared all hotkey registrations")
    }
    
    // Add debugging method to list all currently registered hotkeys
    static func printRegisteredHotKeys() {
        print("--- Currently Registered Hotkeys ---")
        if registeredHotKeys.isEmpty {
            print("No hotkeys currently registered")
        } else {
            for (identifier, hotkey) in registeredHotKeys {
                print("HotKey ID \(identifier): keyCode=\(hotkey.keyCode), modifiers=\(hotkey.modifiers), registered=\(hotkey.hotKeyRef != nil)")
            }
        }
        print("-----------------------------------")
    }
    
    var keyDownHandler: (() -> Void)?
    var keyUpHandler: (() -> Void)?
    
    let identifier: UInt32
    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags
    private var eventHandler: EventHandlerRef?
    var hotKeyRef: EventHotKeyRef?
    
    init(key: KeyCode, modifiers: NSEvent.ModifierFlags, identifier: UInt32 = 0) {
        self.keyCode = key.carbonKeyCode
        self.modifiers = modifiers
        self.identifier = identifier
        
        print("Creating hotkey: \(key) with modifiers \(modifiers) and ID \(identifier)")
        
        // Register in the static dictionary
        if HotKey.registeredHotKeys[identifier] != nil {
            print("⚠️ Warning: Overwriting previously registered hotkey with ID \(identifier)")
            HotKey.registeredHotKeys[identifier]?.unregister()
        }
        HotKey.registeredHotKeys[identifier] = self
        
        register()
        
        if hotKeyRef != nil {
            print("✅ Successfully registered hotkey \(key) with ID \(identifier)")
        } else {
            print("❌ Failed to register hotkey \(key) with ID \(identifier)")
            
            // Remove from registry if registration failed
            HotKey.registeredHotKeys.removeValue(forKey: identifier)
        }
    }
    
    deinit {
        unregister()
        HotKey.registeredHotKeys.removeValue(forKey: identifier)
        print("Unregistered hotkey with ID \(identifier) in deinit")
    }
    
    private func register() {
        guard hotKeyRef == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerCallback: EventHandlerUPP = { (_, eventRef, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            
            var theHotKeyID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &theHotKeyID)
            
            if theHotKeyID.id == hotKey.identifier {
                print("Hotkey with ID \(hotKey.identifier) triggered!")
                hotKey.keyDownHandler?()
            }
            
            return OSStatus(noErr)
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        
        if status != noErr {
            print("Failed to install event handler: \(status)")
            return
        }
        
        var hotKeyID = EventHotKeyID(signature: OSType(0x4C555A49), id: identifier) // "LUZI" in ASCII
        
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        
        let regStatus = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, hotKeyID, GetApplicationEventTarget(), OptionBits(0), &hotKeyRef)
        if regStatus != noErr {
            print("Failed to register hotkey: \(regStatus)")
        }
    }
    
    func unregister() {
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
            print("Removed event handler for hotkey \(identifier)")
        }
        
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            print("Unregistered hotkey \(identifier)")
        }
    }
    
    func reregister() {
        print("Re-registering hotkey with ID \(identifier)")
        unregister()
        register()
    }
}

enum KeyCode {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case zero, one, two, three, four, five, six, seven, eight, nine
    case escape, delete, space, returnKey
    
    var carbonKeyCode: Int {
        switch self {
        case .a: return 0x00
        case .b: return 0x0B
        case .c: return 0x08
        case .d: return 0x02
        case .e: return 0x0E
        case .f: return 0x03
        case .g: return 0x05
        case .h: return 0x04
        case .i: return 0x22
        case .j: return 0x26
        case .k: return 0x28
        case .l: return 0x25
        case .m: return 0x2E
        case .n: return 0x2D
        case .o: return 0x1F
        case .p: return 0x23
        case .q: return 0x0C
        case .r: return 0x0F
        case .s: return 0x01
        case .t: return 0x11
        case .u: return 0x20
        case .v: return 0x09
        case .w: return 0x0D
        case .x: return 0x07
        case .y: return 0x10
        case .z: return 0x06
        case .zero: return 0x1D
        case .one: return 0x12
        case .two: return 0x13
        case .three: return 0x14
        case .four: return 0x15
        case .five: return 0x17
        case .six: return 0x16
        case .seven: return 0x1A
        case .eight: return 0x1C
        case .nine: return 0x19
        case .escape: return 0x35
        case .delete: return 0x33
        case .space: return 0x31
        case .returnKey: return 0x24
        }
    }
} 