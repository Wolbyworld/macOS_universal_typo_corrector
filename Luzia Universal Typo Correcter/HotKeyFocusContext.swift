import AppKit
import ApplicationServices

struct HotKeyFocusContext: Equatable {
    struct Element: Equatable {
        var role: String?
        var subrole: String?
        var title: String?
        var roleDescription: String?
        var identifier: String?
    }

    var bundleIdentifier: String?
    var localizedName: String?
    var elements: [Element]
}

enum HotKeyRegistrationPolicy {
    static func shouldRegisterCmdShiftG(accessibilityTrusted: Bool) -> Bool {
        accessibilityTrusted
    }
}

enum HotKeyFocusContextReader {
    static func current() -> HotKeyFocusContext {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return HotKeyFocusContext(bundleIdentifier: nil, localizedName: nil, elements: [])
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        var elements: [HotKeyFocusContext.Element] = []

        if let focusedWindow = elementAttribute(kAXFocusedWindowAttribute, from: appElement) {
            appendSummary(for: focusedWindow, to: &elements)
        }

        if let focusedElement = elementAttribute(kAXFocusedUIElementAttribute, from: appElement) {
            appendSummary(for: focusedElement, to: &elements)
            appendAncestors(from: focusedElement, to: &elements)
        }

        return HotKeyFocusContext(
            bundleIdentifier: frontmostApp.bundleIdentifier,
            localizedName: frontmostApp.localizedName,
            elements: elements
        )
    }

    private static func appendAncestors(from element: AXUIElement, to elements: inout [HotKeyFocusContext.Element]) {
        var currentElement = element

        for _ in 0..<8 {
            guard let parent = elementAttribute(kAXParentAttribute, from: currentElement) else {
                return
            }

            appendSummary(for: parent, to: &elements)
            currentElement = parent
        }
    }

    private static func appendSummary(for element: AXUIElement, to elements: inout [HotKeyFocusContext.Element]) {
        let summary = HotKeyFocusContext.Element(
            role: stringAttribute(kAXRoleAttribute, from: element),
            subrole: stringAttribute(kAXSubroleAttribute, from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            roleDescription: stringAttribute(kAXRoleDescriptionAttribute, from: element),
            identifier: stringAttribute(kAXIdentifierAttribute, from: element)
        )

        if !elements.contains(summary) {
            elements.append(summary)
        }
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        guard let string = value as? String, !string.isEmpty else {
            return nil
        }

        return string
    }

    private static func elementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        guard let value = value else {
            return nil
        }

        let cfValue = value as CFTypeRef
        guard CFGetTypeID(cfValue) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }
}

enum HotKeyPassThroughPolicy {
    private static let finderBundleIdentifier = "com.apple.finder"
    private static let openAndSavePanelBundlePrefix = "com.apple.appkit.xpc.openAndSavePanelService"

    private static let fileDialogTitleMatches: Set<String> = [
        "open",
        "save",
        "save as",
        "upload"
    ]

    private static let fileDialogTitleFragments = [
        "attach",
        "browse",
        "choose file",
        "choose files",
        "export",
        "file upload",
        "import",
        "open file",
        "open files",
        "save file",
        "select file",
        "select files",
        "upload file",
        "upload files"
    ]

    private static let fileDialogIdentifierFragments = [
        "nsopenpanel",
        "nssavepanel",
        "openpanel",
        "savepanel"
    ]

    static func shouldPassThroughCmdShiftG(in context: HotKeyFocusContext) -> Bool {
        guard let bundleIdentifier = context.bundleIdentifier else {
            return false
        }

        if bundleIdentifier == finderBundleIdentifier ||
            bundleIdentifier.hasPrefix(openAndSavePanelBundlePrefix) {
            return true
        }

        return context.elements.contains { element in
            isFinderLikeFileDialog(element)
        }
    }

    private static func isFinderLikeFileDialog(_ element: HotKeyFocusContext.Element) -> Bool {
        guard isDialogOrSheet(element) else {
            return false
        }

        let title = normalized(element.title)
        let roleDescription = normalized(element.roleDescription)
        let identifier = normalized(element.identifier)

        if fileDialogTitleMatches.contains(title) {
            return true
        }

        if fileDialogTitleFragments.contains(where: { title.contains($0) || roleDescription.contains($0) }) {
            return true
        }

        return fileDialogIdentifierFragments.contains { identifier.contains($0) }
    }

    private static func isDialogOrSheet(_ element: HotKeyFocusContext.Element) -> Bool {
        let role = normalized(element.role)
        let subrole = normalized(element.subrole)

        return role == "axsheet" ||
            subrole == "axdialog" ||
            subrole == "axsheet" ||
            subrole == "axsystemdialog"
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }
}
