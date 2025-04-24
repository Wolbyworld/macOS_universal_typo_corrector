//
//  ContentView.swift
//  Luzia Universal Typo Correcter
//
//  Created by Alvaro Martinez Higes on 4/23/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "textformat.abc.dottedunderline")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)
            
            Text("Luzia Universal Typo Correcter")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Running in the menu bar")
                .font(.title2)
            
            Spacer().frame(height: 30)
            
            Text("Use ⇧⌘G to correct selected text")
                .font(.title3)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("You can also access the app from the menu bar icon")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

#Preview {
    ContentView()
}
