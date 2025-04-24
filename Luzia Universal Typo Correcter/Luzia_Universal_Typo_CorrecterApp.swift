//
//  Luzia_Universal_Typo_CorrecterApp.swift
//  Luzia Universal Typo Correcter
//
//  Created by Alvaro Martinez Higes on 4/23/25.
//

import SwiftUI
import AppKit

@main
struct Luzia_Universal_Typo_CorrecterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(appDelegate.appState)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    NSApp.sendAction(#selector(AppDelegate.openPreferences), to: nil, from: nil)
                }.keyboardShortcut(",")
            }
        }
    }
}
