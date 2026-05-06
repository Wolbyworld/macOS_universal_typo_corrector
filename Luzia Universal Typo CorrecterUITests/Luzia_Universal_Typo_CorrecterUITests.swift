//
//  Luzia_Universal_Typo_CorrecterUITests.swift
//  Luzia Universal Typo CorrecterUITests
//
//  Created by Alvaro Martinez Higes on 4/23/25.
//

import XCTest
import AppKit
import ApplicationServices

final class Luzia_Universal_Typo_CorrecterUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCmdShiftGOpensGoToFolderInFinderWithLuziaRunning() throws {
        try requireSystemUAT()

        let app = XCUIApplication()
        app.launch()

        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertTrue(waitForFrontmostBundleIdentifier("com.apple.finder", timeout: 5))

        dismissGoToFolderIfPresent(in: finder)
        pressCmdShiftG()

        XCTAssertTrue(
            goToFolderPrompt(in: finder).waitForExistence(timeout: 3),
            "Cmd+Shift+G should open Go to Folder in Finder while Luzia is running."
        )

        dismissGoToFolderIfPresent(in: finder)
    }

    @MainActor
    func testCmdShiftGOpensGoToFolderInOpenDialogWithLuziaRunning() throws {
        try requireSystemUAT()

        let app = XCUIApplication()
        app.launch()

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.launch()
        textEdit.activate()
        XCTAssertTrue(textEdit.wait(for: .runningForeground, timeout: 5))

        textEdit.typeKey("o", modifierFlags: [.command])
        XCTAssertTrue(
            textEdit.buttons["Open"].firstMatch.waitForExistence(timeout: 5),
            "TextEdit should show its Open dialog before testing Cmd+Shift+G passthrough."
        )

        pressCmdShiftG()
        XCTAssertTrue(
            goToFolderPrompt(in: textEdit).waitForExistence(timeout: 3),
            "Cmd+Shift+G should open Go to Folder in an app Open dialog while Luzia is running."
        )

        dismissGoToFolderIfPresent(in: textEdit)
        pressEscape()
        textEdit.terminate()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func requireSystemUAT() throws {
        let markerPath = "/tmp/luzia-run-system-uat"
        let enabledByEnvironment = ProcessInfo.processInfo.environment["RUN_LUZIA_SYSTEM_UAT"] == "1"
        let enabledByMarker = FileManager.default.fileExists(atPath: markerPath)

        guard enabledByEnvironment || enabledByMarker else {
            throw XCTSkip("Set RUN_LUZIA_SYSTEM_UAT=1 or create \(markerPath) to run the interactive Finder/Open dialog shortcut UAT.")
        }
    }

    @MainActor
    private func goToFolderPrompt(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR label CONTAINS[c] %@", "Go to:", "Go to the folder"))
            .firstMatch
    }

    @MainActor
    private func dismissGoToFolderIfPresent(in app: XCUIApplication) {
        if goToFolderPrompt(in: app).exists {
            pressEscape()
        }
    }

    private func waitForFrontmostBundleIdentifier(_ bundleIdentifier: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return false
    }

    private func pressCmdShiftG() {
        postKey(0x05, flags: [.maskCommand, .maskShift])
    }

    private func pressEscape() {
        postKey(0x35, flags: [])
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        usleep(50_000)
        keyUp?.post(tap: .cghidEventTap)
    }
}
