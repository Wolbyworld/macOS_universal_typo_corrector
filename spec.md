Tech stack & distribution

Language/framework: Swift + SwiftUI (with a small AppKit shim where needed).

Packaging: Signed .app bundle, direct-download ZIP. Use Sparkle for auto-updates.

Global shortcut

Use a lightweight HotKey library (e.g. HotKey).

Let the user customize in Preferences (default ⇧⌘G).

Capturing & replacing selection

On hotkey:

Save current clipboard contents.

Programmatically send ⇧⌘C (Copy) via a CGEvent tap (requires Accessibility permission).

Read both plain-text and RTF/HTML from NSPasteboard.

Send the plain text to OpenAI with your system prompt.

Receive corrected text.

Create an NSAttributedString by taking the corrected string and applying the original’s RTF attributes uniformly (best effort).

Write that back into the pasteboard (both plain and RTF).

Trigger ⇧⌘V (Paste).

Restore the user’s original clipboard.

Because we’re issuing a normal “Paste” event, the host app’s UndoManager picks it up—so ⇧⌘Z will undo.

Rich-text handling & exclusions

By default attempt RTF/HTML preservation; if unsupported in a given app, fall back to plain text.

In Preferences: let users add or remove excluded apps (e.g. Arc), so the shortcut is ignored when those are frontmost.

Feedback & errors

Spinner: animate your menubar icon to show “busy.”

Errors: present a lightweight macOS notification (toast style) explaining—e.g. “No API key set,” “Network error,” or “Rate limit reached.”

Preferences window

Fields for:

OpenAI API key

System prompt (editable)

Model selector (gpt-4.1 / gpt-4.5-preview)

Global shortcut

Excluded-apps list