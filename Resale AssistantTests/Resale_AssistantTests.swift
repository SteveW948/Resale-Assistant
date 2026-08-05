//
//  Resale_AssistantTests.swift
//  Resale AssistantTests
//

import Testing
import Foundation
import Vision
@testable import Resale_Assistant

struct CaptionGeneratorTests {

    @Test func captionIncludesMainObjectAtHighConfidence() {
        let store = CaptionGenerator.StoreContext(sellerCode: "", storeName: "")
        let text = CaptionGenerator.caption(
            from: [("vintage lamp", 0.95)],
            store: store
        )
        #expect(text.localizedStandardContains("vintage lamp"))
        #expect(text.localizedStandardContains("clearly visible"))
    }

    @Test func captionAppendsStoreAndSeller() {
        let store = CaptionGenerator.StoreContext(sellerCode: "ABC123", storeName: "Downtown Thrift")
        let text = CaptionGenerator.caption(
            from: [("chair", 0.85)],
            store: store
        )
        #expect(text.localizedStandardContains("Downtown Thrift"))
        #expect(text.localizedStandardContains("ABC123"))
    }

    @Test func captionHandlesLowConfidence() {
        let store = CaptionGenerator.StoreContext(sellerCode: "", storeName: "")
        let text = CaptionGenerator.caption(
            from: [("widget", 0.4), ("gadget", 0.3)],
            store: store
        )
        #expect(text.localizedStandardContains("Possible item categories"))
        #expect(text.localizedStandardContains("widget"))
    }

    @Test func captionEmptyClassifications() {
        let store = CaptionGenerator.StoreContext(sellerCode: "", storeName: "")
        let text = CaptionGenerator.caption(from: [], store: store)
        #expect(text.localizedStandardContains("No specific objects"))
    }

    @Test func fallbackCaptionIncludesDimensions() {
        let store = CaptionGenerator.StoreContext(sellerCode: "S1", storeName: "Shop")
        let text = CaptionGenerator.fallbackCaption(
            width: 100,
            height: 200,
            colorSpaceName: "sRGB",
            store: store
        )
        #expect(text.localizedStandardContains("100 x 200"))
        #expect(text.localizedStandardContains("sRGB"))
        #expect(text.localizedStandardContains("Shop"))
        #expect(text.localizedStandardContains("S1"))
    }

    @Test func shouldUseFallbackForVisionDomainErrors() {
        let error = NSError(domain: VNErrorDomain, code: 9, userInfo: nil)
        #expect(CaptionGenerator.shouldUseFallback(for: error))
    }

    @Test func shouldUseFallbackForEspressoDescription() {
        let error = NSError(
            domain: "Test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "espresso model missing"]
        )
        #expect(CaptionGenerator.shouldUseFallback(for: error))
    }

    @Test func appendStoreContextOmitsBlankFields() {
        let store = CaptionGenerator.StoreContext(sellerCode: "  ", storeName: "")
        let text = CaptionGenerator.appendStoreContext("Hello", store: store)
        #expect(text == "Hello")
    }
}

struct AppSettingsTests {

    @Test @MainActor func persistsSellerCodeAndStoreName() {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(userDefaults: defaults)
        settings.sellerCode = "CODE1"
        settings.storeName = "Store One"

        #expect(defaults.string(forKey: "sellerCode") == "CODE1")
        #expect(defaults.string(forKey: "storeName") == "Store One")

        settings.sellerCode = "CODE2"
        settings.storeName = "Store Two"
        #expect(defaults.string(forKey: "sellerCode") == "CODE2")
        #expect(defaults.string(forKey: "storeName") == "Store Two")
    }

    @Test @MainActor func reloadRestoresSavedValues() {
        let suiteName = "AppSettingsReload.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(userDefaults: defaults)
        settings.sellerCode = "temp"
        settings.storeName = "temp"

        // Simulate external persistence changes, then reload into the settings object.
        defaults.set("ReloadCode", forKey: "sellerCode")
        defaults.set("ReloadStore", forKey: "storeName")
        settings.reload()

        #expect(settings.sellerCode == "ReloadCode")
        #expect(settings.storeName == "ReloadStore")
    }

    @Test @MainActor func initLoadsExistingValues() {
        let suiteName = "AppSettingsInit.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("LoadedCode", forKey: "sellerCode")
        defaults.set("LoadedStore", forKey: "storeName")

        let settings = AppSettings(userDefaults: defaults)
        #expect(settings.sellerCode == "LoadedCode")
        #expect(settings.storeName == "LoadedStore")
    }
}
