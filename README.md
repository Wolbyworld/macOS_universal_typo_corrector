# Luzia Universal Typo Correcter

A lightweight macOS utility that corrects typos and grammatical errors in any text field across your system.

## Features

- 🔤 Universal text correction across any app
- ⌨️ Global keyboard shortcut (⇧⌘G by default)
- 🖋️ Preserves text formatting when possible
- 🔒 Uses your own OpenAI API key
- ⚙️ Customizable system prompt
- 🚫 Exclude apps where you don't want correction

## Requirements

- macOS 11.0 or later
- An OpenAI API key

## Installation

1. Download the latest release from the [Releases](https://github.com/yourusername/luzia-typo-correcter/releases) page
2. Unzip and move Luzia Universal Typo Correcter to your Applications folder
3. Launch the app and follow the setup instructions to add your OpenAI API key

## Usage

1. Select text in any application
2. Press ⇧⌘G (Shift+Command+G)
3. Wait for the correction (the menu bar icon will animate)
4. The selected text will be replaced with the corrected version

## Permissions

The app will request the following permissions:
- Accessibility permissions (to simulate keyboard shortcuts)
- Notifications (for error messages)

## Development

This app is built with Swift and SwiftUI. To build from source:

1. Clone the repository
2. Open the project in Xcode
3. Build and run

## Privacy

- Your text is sent to OpenAI for correction using your own API key
- No data is stored by the app beyond your preferences
- The app does not collect any analytics

## License

MIT License 