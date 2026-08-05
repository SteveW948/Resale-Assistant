//
//  OptionsView.swift
//  Resale Assistant
//

import SwiftUI

struct OptionsView: View {
    @Bindable var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var draftSellerCode: String = ""
    @State private var draftStoreName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Store Information") {
                    TextField("Seller Code", text: $draftSellerCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .accessibilityLabel("Seller Code")

                    TextField("Store Name", text: $draftStoreName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Store Name")
                }

                Section {
                    Button("Quit App", role: .destructive) {
                        quitApplication()
                    }
                    .accessibilityHint("Closes the application")
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        appSettings.sellerCode = draftSellerCode
                        appSettings.storeName = draftStoreName
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftSellerCode = appSettings.sellerCode
                draftStoreName = appSettings.storeName
            }
        }
    }

    private func quitApplication() {
        #if os(macOS)
        NSApplication.shared.terminate(nil)
        #else
        // iOS apps are lifecycle-managed; exit is used when an explicit Quit is required.
        exit(0)
        #endif
    }
}
