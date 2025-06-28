//
//  Luzia_Universal_Typo_CorrecterApp.swift
//  Luzia Universal Typo Correcter
//
//  Created by Alvaro Martinez Higes on 4/23/25.
//

import AppKit

// Pure NSApplication approach for agent applications
// This eliminates SwiftUI App structure that conflicts with LSUIElement
@main
class Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

