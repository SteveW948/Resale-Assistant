//
//  AppSettings.swift
//  Resale Assistant
//

import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private let sellerCodeKey = "sellerCode"
    private let storeNameKey = "storeName"
    private let userDefaults: UserDefaults
    private var isInitializing = true

    var sellerCode: String = "" {
        didSet {
            if !isInitializing {
                userDefaults.set(sellerCode, forKey: sellerCodeKey)
            }
        }
    }

    var storeName: String = "" {
        didSet {
            if !isInitializing {
                userDefaults.set(storeName, forKey: storeNameKey)
            }
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        sellerCode = userDefaults.string(forKey: sellerCodeKey) ?? ""
        storeName = userDefaults.string(forKey: storeNameKey) ?? ""
        isInitializing = false
    }

    func reload() {
        isInitializing = true
        sellerCode = userDefaults.string(forKey: sellerCodeKey) ?? ""
        storeName = userDefaults.string(forKey: storeNameKey) ?? ""
        isInitializing = false
    }
}
