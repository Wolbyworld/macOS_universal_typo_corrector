import Foundation
import Cocoa

class HotKey {
    var keyDownHandler: (() -> Void)?
    var keyUpHandler: (() -> Void)?
    var shouldPassThroughHandler: (() -> Bool)?
    
    let identifier: UInt32
    private let keyCode: Int
    private let modifiers: NSEvent.ModifierFlags
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    init(key: KeyCode, modifiers: NSEvent.ModifierFlags, identifier: UInt32 = 0) {
        self.keyCode = key.carbonKeyCode
        self.modifiers = modifiers
        self.identifier = identifier
        register()
    }
    
    deinit {
        unregister()
    }
    
    private func register() {
        guard eventTap == nil else { return }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (_, type, event, userData) -> Unmanaged<CGEvent>? in
                guard let userData = userData else {
                    return Unmanaged.passUnretained(event)
                }

                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    hotKey.enableEventTap()
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown, hotKey.matches(event) else {
                    return Unmanaged.passUnretained(event)
                }

                if hotKey.shouldPassThroughHandler?() == true {
                    return Unmanaged.passUnretained(event)
                }

                DispatchQueue.main.async {
                    hotKey.keyDownHandler?()
                }

                return nil
            },
            userInfo: selfPointer
        ) else {
            print("Failed to install hotkey event tap. Check Accessibility permissions.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        enableEventTap()
    }
    
    private func unregister() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func enableEventTap() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func matches(_ event: CGEvent) -> Bool {
        let eventKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return false }

        let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        let eventModifiers = event.flags.intersection(relevantFlags)
        return eventModifiers == requiredCGEventFlags.intersection(relevantFlags)
    }

    private var requiredCGEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
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
