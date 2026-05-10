//
//  Luzia_Universal_Typo_CorrecterTests.swift
//  Luzia Universal Typo CorrecterTests
//
//  Created by Alvaro Martinez Higes on 4/23/25.
//

import Testing
@testable import Luzia_Universal_Typo_Correcter

struct Luzia_Universal_Typo_CorrecterTests {

    @Test func cmdShiftGPassesThroughInFinder() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.finder",
            localizedName: "Finder",
            elements: []
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGPassesThroughInFinderEvenWhenAnElementLooksEditable() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.finder",
            localizedName: "Finder",
            elements: [
                .init(role: "AXTextField", subrole: nil, title: nil, roleDescription: "text field", identifier: nil)
            ]
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGPassesThroughInNativeOpenPanel() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            elements: [
                .init(role: "AXWindow", subrole: "AXDialog", title: "Open", roleDescription: "dialog", identifier: nil)
            ]
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGPassesThroughInNativeSavePanel() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            elements: [
                .init(role: "AXSheet", subrole: "AXSheet", title: "Save", roleDescription: "sheet", identifier: nil)
            ]
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGPassesThroughInBrowserUploadDialog() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.google.Chrome",
            localizedName: "Chrome",
            elements: [
                .init(role: "AXWindow", subrole: "AXSystemDialog", title: "File Upload", roleDescription: "dialog", identifier: nil)
            ]
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGPassesThroughInOpenAndSavePanelService() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.appkit.xpc.openAndSavePanelService",
            localizedName: "Open and Save Panel Service",
            elements: []
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGPassesThroughInTitlelessOpenPanelByIdentifier() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            elements: [
                .init(role: "AXWindow", subrole: "AXDialog", title: nil, roleDescription: "dialog", identifier: "NSOpenPanel")
            ]
        )

        #expect(HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGDoesNotPassThroughInRegularTextWindow() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            elements: [
                .init(role: "AXWindow", subrole: "AXStandardWindow", title: "Untitled", roleDescription: "window", identifier: nil)
            ]
        )

        #expect(!HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

    @Test func cmdShiftGDoesNotPassThroughInUnrelatedDialog() {
        let context = HotKeyFocusContext(
            bundleIdentifier: "com.example.editor",
            localizedName: "Editor",
            elements: [
                .init(role: "AXWindow", subrole: "AXDialog", title: "Find", roleDescription: "dialog", identifier: nil)
            ]
        )

        #expect(!HotKeyPassThroughPolicy.shouldPassThroughCmdShiftG(in: context))
    }

}
