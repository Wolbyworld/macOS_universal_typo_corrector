# 🛠️ Development Scripts Guide

Quick reference for all development and deployment scripts.

---

## 🚀 Deployment Scripts

### `quick-deploy.sh` - Full Build & Install
**What it does:** Builds the app from source and installs to /Applications

```bash
./quick-deploy.sh
```

**Use when:**
- You made code changes and want to test
- First time setup
- Want a clean build from scratch

**Output:**
- Builds to `build/Build/Products/Release/`
- Installs to `/Applications/`
- Launches the app

**Note:** This will prompt for Accessibility permissions to be reset.

---

### `install-dev.sh` - Quick Install (NEW!)
**What it does:** Installs already-built app to /Applications without rebuilding

```bash
./install-dev.sh
```

**Use when:**
- You already ran `quick-deploy.sh` once
- Want to reinstall without rebuilding
- Want to backup current version before installing

**Features:**
- ✅ Backs up current version to `~/Desktop/Luzia Backups/`
- ✅ Shows build timestamp and size
- ✅ Tracks number of backups
- ✅ Faster than full rebuild

**Example output:**
```
🚀 Installing Dev Build to /Applications

💾 Backing up current version...
   ✓ Backed up to: ~/Desktop/Luzia Backups/Luzia...app.20260111_070000

🛑 Stopping running app...
   ✓ Stopped

📦 Installing new version...
   ✓ Installed to /Applications/

🚀 Launching app...

✅ Done! App is running in menu bar.

📊 Version Info:
   Built: 2026-01-11 07:00:00
   Size: 8.2M

💾 Backups: 3 versions saved in:
   ~/Desktop/Luzia Backups
```

---

### `restore-backup.sh` - Rollback to Previous Version (NEW!)
**What it does:** Restores a backup version from `~/Desktop/Luzia Backups/`

```bash
./restore-backup.sh
```

**Use when:**
- New version has bugs
- Want to go back to working version
- Testing different builds

**Interactive selection:**
```
🔄 Restore Luzia from Backup

📦 Available backups:

   [1] 2026-01-11 07:00:00
   [2] 2026-01-11 06:30:00
   [3] 2026-01-10 22:00:00

Which backup to restore? (1-3, or 0 to cancel):
```

---

## 🔧 Utility Scripts

### `watch-logs.sh` - Real-time Log Monitoring
**What it does:** Watches both success and error logs in real-time

```bash
./watch-logs.sh
```

**Shows:**
- Successful corrections
- API errors
- Paste failures
- Token usage

**Great for:** Debugging, seeing corrections happen live

---

### `reset-permissions.sh` - Fix Accessibility Permissions
**What it does:** Opens System Settings to Accessibility preferences

```bash
./reset-permissions.sh
```

**Use when:**
- Shortcut (⇧⌘G) not working
- After rebuilding the app
- Permissions seem stuck

**Steps it shows:**
1. Find 'Luzia Universal Typo Correcter' in list
2. Toggle it off then on (or remove and re-add)
3. Try ⇧⌘G again

---

### `check-setup.sh` - Verify Development Environment
**What it does:** Checks if Xcode and dependencies are set up correctly

```bash
./check-setup.sh
```

**Checks:**
- Xcode installation
- Command line tools
- Project structure
- Build configuration

---

### `install-xcode.sh` - Setup Xcode Command Line Tools
**What it does:** Installs Xcode CLI tools if missing

```bash
./install-xcode.sh
```

**Use when:**
- First time setup on new Mac
- `xcodebuild` command not found
- Build scripts failing

---

## 📋 Common Workflows

### Standard Development Loop
```bash
# 1. Make code changes in Xcode
# 2. Build and install
./quick-deploy.sh

# 3. Test the app
# 4. If bugs, restore previous version
./restore-backup.sh

# 5. Watch logs while testing
./watch-logs.sh
```

### Quick Update (No Code Changes)
```bash
# Just reinstall current build
./install-dev.sh
```

### Fixing Permissions Issues
```bash
# 1. Reset permissions
./reset-permissions.sh

# 2. Follow on-screen instructions
# 3. Test with ⇧⌘G
```

### Debugging a Problem
```bash
# Terminal 1: Watch logs
./watch-logs.sh

# Terminal 2: Test the app
# (Select text and press ⇧⌘G)

# Logs will show what's happening in real-time
```

---

## 🗂️ File Locations Reference

### Build Output
```
build/Build/Products/Release/Luzia Universal Typo Correcter.app
```

### Production App
```
/Applications/Luzia Universal Typo Correcter.app
```

### Backups
```
~/Desktop/Luzia Backups/
├── Luzia Universal Typo Correcter.app.20260111_070000
├── Luzia Universal Typo Correcter.app.20260111_063000
└── Luzia Universal Typo Correcter.app.20260110_220000
```

### Logs
```
~/Library/Application Support/Luzia/Evals/
├── evals_log.tsv        # Successful corrections
└── evals_errors.tsv     # Errors and failures
```

---

## 💡 Pro Tips

### 1. Keep Backups Clean
Backups accumulate over time. Clean old ones manually:
```bash
ls -lt ~/Desktop/Luzia\ Backups/
# Delete old backups you don't need
rm -rf ~/Desktop/Luzia\ Backups/Luzia*.app.20260101*
```

### 2. Quick Iteration
For fastest iteration while coding:
```bash
# Build once
./quick-deploy.sh

# Then for quick reinstalls (no rebuild):
./install-dev.sh
```

### 3. Diff Logs Between Versions
```bash
# Before update
cp ~/Library/Application\ Support/Luzia/Evals/evals_errors.tsv /tmp/errors_old.tsv

# After update, compare
diff /tmp/errors_old.tsv ~/Library/Application\ Support/Luzia/Evals/evals_errors.tsv
```

### 4. Clean Build
If builds are acting weird:
```bash
# Remove all build artifacts
rm -rf build/
rm -rf ~/Library/Developer/Xcode/DerivedData/Luzia*

# Fresh build
./quick-deploy.sh
```

---

## 🐛 Troubleshooting

### "App won't launch"
```bash
# Check if it's crashing on launch
log show --predicate 'process == "Luzia Universal Typo Correcter"' --last 5m

# Or restore last working backup
./restore-backup.sh
```

### "Shortcut not working"
```bash
# Reset permissions
./reset-permissions.sh

# Check if app is running
ps aux | grep "Luzia Universal Typo Correcter"

# Check logs
tail -20 ~/Library/Application\ Support/Luzia/Evals/evals_errors.tsv
```

### "Build fails"
```bash
# Verify setup
./check-setup.sh

# Clean and rebuild
rm -rf build/
./quick-deploy.sh
```

### "No backups available"
```bash
# Install dev creates backups automatically
./install-dev.sh

# Now you'll have at least one backup
ls ~/Desktop/Luzia\ Backups/
```

---

## 📚 Script Summary Table

| Script | Purpose | Speed | Backs Up? |
|--------|---------|-------|-----------|
| `quick-deploy.sh` | Build + Install | Slow (~30s) | No |
| `install-dev.sh` | Install only | Fast (~2s) | ✅ Yes |
| `restore-backup.sh` | Restore backup | Fast (~2s) | No |
| `watch-logs.sh` | Monitor logs | Instant | N/A |
| `reset-permissions.sh` | Fix permissions | Instant | N/A |
| `check-setup.sh` | Verify setup | Fast (~5s) | N/A |

---

**Need more help?** Check the main README or TODO.md for project details.
