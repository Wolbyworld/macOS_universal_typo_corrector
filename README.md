# Luzia Universal Typo Correcter

A lightweight macOS utility that corrects typos and grammatical errors in any text field across your system.

## Features

- 🔤 Universal text correction across any app
- ⌨️ Global keyboard shortcut (⇧⌘G by default)
- 🖋️ Preserves text formatting when possible
- 🔒 Uses your own OpenAI API key OR company proxy
- 🏢 Enterprise distribution support with pre-configured proxy
- 🔐 Keychain integration for secure credential storage
- ⚙️ Customizable system prompt
- 🚫 Exclude apps where you don't want correction

## Requirements

- macOS 11.0 or later
- An OpenAI API key (personal use) OR access to company proxy (enterprise deployment)

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

### Standard Build (Personal Use)

```bash
./quick-deploy.sh
```

Builds and installs to `/Applications` for local testing.

### Enterprise Distribution

For company-wide deployment with pre-configured proxy:

1. **Set up backend proxy** (optional):
   - See `../universal_typo_backend/` for Flask backend
   - Deploy to Heroku with rate limiting and analytics
   - Get your proxy URL and shared secret

2. **Create enterprise build**:
   ```bash
   # Copy template and add your secrets
   cp build-enterprise.sh.template build-enterprise.sh
   # Edit build-enterprise.sh with your proxy URL and secret
   vim build-enterprise.sh

   # Build enterprise DMG
   ./build-enterprise.sh
   ```

3. **Distribute**:
   - Upload `Luzia-Enterprise.dmg` to shared drive
   - Employees drag app to Applications folder
   - No API key configuration needed!

**Security:**
- Secrets stored in macOS Keychain (encrypted at rest)
- Enterprise proxy secret XOR-obfuscated in app bundle
- Backend enforces rate limiting (1000 req/hour default)

### Build Scripts

- `quick-deploy.sh` - Build and install standard version locally
- `build-enterprise.sh` - Build enterprise DMG with pre-configured proxy
- `create-dmg.sh` - Create DMG with drag-to-Applications UI

## Enterprise Backend

The app supports a Flask-based proxy backend for company-wide deployments:

**Features:**
- Centralized API key management (no individual keys needed)
- Global rate limiting (prevents abuse)
- Usage analytics and cost tracking
- Postgres logging for all requests

**Setup:**
See the backend repository at `../universal_typo_backend/` or deploy your own Flask proxy.

## Privacy

- Your text is sent to OpenAI for correction using your own API key or company proxy
- No data is stored by the app beyond your preferences
- The app does not collect any analytics
- Local logs stored in `~/Library/Application Support/Luzia/Evals/`

## License

MIT License 