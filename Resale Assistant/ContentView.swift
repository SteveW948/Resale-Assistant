//
//  ContentView.swift
//  Resale Assistant
//
//  Created by Steven Walker on 4/19/25.
//

import SwiftUI
import PhotosUI
import MockImagePicker
import Vision
import VisionKit
import Observation

#if targetEnvironment(simulator)
import MockImagePicker
typealias UIImagePickerController = MockImagePicker
typealias UIImagePickerControllerDelegate = MockImagePickerDelegate
#endif

@MainActor
@Observable
class AppSettings {
    private let sellerCodeKey = "sellerCode"
    private let storeNameKey = "storeName"
    private var isInitializing = true
    
    var sellerCode: String = "" {
        didSet {
            if !isInitializing {
                UserDefaults.standard.set(sellerCode, forKey: sellerCodeKey)
            }
        }
    }
    
    var storeName: String = "" {
        didSet {
            if !isInitializing {
                UserDefaults.standard.set(storeName, forKey: storeNameKey)
            }
        }
    }
    
    init() {
        // Load saved values from UserDefaults on initialization
        sellerCode = UserDefaults.standard.string(forKey: sellerCodeKey) ?? ""
        storeName = UserDefaults.standard.string(forKey: storeNameKey) ?? ""
        
        // Mark initialization as complete so future changes will be saved
        isInitializing = false
    }
    
    // Explicit save method to ensure persistence (called on app lifecycle changes)
    func saveSettings() {
        UserDefaults.standard.set(sellerCode, forKey: sellerCodeKey)
        UserDefaults.standard.set(storeName, forKey: storeNameKey)
        UserDefaults.standard.synchronize() // Force immediate write to disk
    }
}

/// View model for caption generation. Vision work runs off the main thread to avoid dispatch queue assertions.
@MainActor
@Observable
class CaptionViewModel {
    var captionText: String = ""
    var isLoading: Bool = false

    func generateCaption(for image: UIImage) {
        isLoading = true
        captionText = ""

        guard let cgImage = image.cgImage else {
            captionText = "Error: Could not process image"
            isLoading = false
            return
        }

        let viewModel = self
        Task.detached(priority: .userInitiated) {
            Self.runVisionAnalysis(cgImage: cgImage) { result in
                Task { @MainActor in
                    viewModel.captionText = result
                    viewModel.isLoading = false
                }
            }
        }
    }

    func reset() {
        captionText = ""
        isLoading = false
    }

    /// Runs Vision on a background context and invokes the callback with the result string (callback can be called on any queue).
    private nonisolated static func runVisionAnalysis(cgImage: CGImage, completion: @escaping (String) -> Void) {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let classificationRequest = VNClassifyImageRequest { request, error in
            if let error = error {
                if error.localizedDescription.contains("espresso") {
                    completion(Self.fallbackCaption(cgImage: cgImage))
                } else {
                    completion("Error analyzing image: \(error.localizedDescription)")
                }
                return
            }

            guard let results = request.results as? [VNClassificationObservation] else {
                completion("No content detected in the image")
                return
            }

            let topClassifications = results.prefix(3).compactMap { observation in
                observation.identifier
            }

            if !topClassifications.isEmpty {
                let mainObject = topClassifications.first ?? "object"
                let confidence = results.first?.confidence ?? 0.0

                if confidence > 0.7 {
                    var text = "This image shows a \(mainObject). "
                    if topClassifications.count > 1 {
                        let additionalObjects = Array(topClassifications.dropFirst()).joined(separator: ", ")
                        text += "Also visible: \(additionalObjects)."
                    }
                    if confidence > 0.9 {
                        text += " The object is clearly visible and easily identifiable."
                    } else if confidence > 0.8 {
                        text += " The object is well-defined in the image."
                    }
                    completion(text)
                } else {
                    completion("The image appears to contain: " + topClassifications.joined(separator: ", "))
                }
            } else {
                completion("No specific objects could be clearly identified in the image.")
            }
        }

        do {
            try requestHandler.perform([classificationRequest])
        } catch {
            if error.localizedDescription.contains("espresso") {
                completion(Self.fallbackCaption(cgImage: cgImage))
            } else {
                completion("Error performing analysis: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fallbackCaption(cgImage: CGImage) -> String {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = cgImage.colorSpace?.name as String? ?? "Unknown"
        let sizeKb = (width * height * 4) / 1024
        return """
        Image Analysis:
        - Dimensions: \(width) x \(height) pixels
        - Color space: \(colorSpace)
        - File size: \(sizeKb) KB

        Note: Advanced AI analysis is not available on this device.
        Please try on a physical device for better results.
        """
    }
}

struct ContentView: View {
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showPhotoReview = false
    @State private var captionViewModel = CaptionViewModel()
    @State private var showOptions = false
    @State private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack {
                if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding()

                if captionViewModel.isLoading {
                    ProgressView("Generating caption...")
                } else if !captionViewModel.captionText.isEmpty {
                    Text("Caption:")
                        .font(.headline)
                    TextEditor(text: Binding(
                        get: { captionViewModel.captionText },
                        set: { captionViewModel.captionText = $0 }
                    ))
                        .frame(height: 100)
                        .border(Color.gray, width: 1)
                        .padding()
                }

                HStack {
                    Button("Retake") {
                        capturedImage = nil
                        captionViewModel.reset()
                        showCamera = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Generate Caption") {
                        captionViewModel.generateCaption(for: image)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        capturedImage = nil
                        captionViewModel.reset()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Take Photo") {
                    showCamera = true
                }
                .buttonStyle(.borderedProminent)
            }
            }
            .navigationTitle("Resale Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Options") {
                        showOptions = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $capturedImage, isShown: $showCamera)
        }
        .sheet(isPresented: $showOptions) {
            OptionsView(appSettings: appSettings)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background || newPhase == .inactive {
                appSettings.saveSettings()
            }
        }
    }
}

struct OptionsView: View {
    var appSettings: AppSettings
    @State private var sellerCode: String = ""
    @State private var storeName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        _sellerCode = State(initialValue: appSettings.sellerCode)
        _storeName = State(initialValue: appSettings.storeName)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Store Information")) {
                    TextField("Seller Code", text: $sellerCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Store Name", text: $storeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Store the values when Done is pressed
                        appSettings.sellerCode = sellerCode
                        appSettings.storeName = storeName
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isShown: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, @MainActor UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.isShown = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isShown = false
        }
    }
}

#Preview {
    ContentView()
}
