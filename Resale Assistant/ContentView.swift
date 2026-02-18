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

#if targetEnvironment(simulator)
import MockImagePicker
typealias UIImagePickerController = MockImagePicker
typealias UIImagePickerControllerDelegate = MockImagePickerDelegate
#endif

class AppSettings: ObservableObject {
    private let sellerCodeKey = "sellerCode"
    private let storeNameKey = "storeName"
    private var isInitializing = true
    
    @Published var sellerCode: String = "" {
        didSet {
            if !isInitializing {
                UserDefaults.standard.set(sellerCode, forKey: sellerCodeKey)
            }
        }
    }
    
    @Published var storeName: String = "" {
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

struct ContentView: View {
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showPhotoReview = false
    @State private var description: String = ""
    @State private var isLoading: Bool = false
    @State private var showOptions = false
    @StateObject private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding()
                
                if isLoading {
                    ProgressView("Generating caption...")
                } else if !description.isEmpty {
                    Text("Caption:")
                        .font(.headline)
                    TextEditor(text: $description)
                        .frame(height: 100)
                        .border(Color.gray, width: 1)
                        .padding()
                }
                
                HStack {
                    Button("Retake") {
                        capturedImage = nil
                        description = ""
                        isLoading = false
                        showCamera = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Generate Caption") {
                        generateCaption(for: image)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Cancel") {
                        capturedImage = nil
                        description = ""
                        isLoading = false
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
                // Ensure values are saved when app goes to background
                appSettings.saveSettings()
            }
        }
    }
    
    private func generateCaption(for image: UIImage) {
        isLoading = true
        description = ""
        
        guard let cgImage = image.cgImage else {
            description = "Error: Could not process image"
            
            isLoading = false
            return
        }
        
        // Try Vision framework first
        analyzeWithVision(cgImage: cgImage)
    }
    
    private func analyzeWithVision(cgImage: CGImage) {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let classificationRequest = VNClassifyImageRequest { request, error in
            DispatchQueue.main.async {
                if let error = error {
                    // If Vision fails, try alternative approach
                    if error.localizedDescription.contains("espresso") {
                        self.fallbackAnalysis(cgImage: cgImage)
                    } else {
                        self.description = "Error analyzing image: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    self.description = "No content detected in the image"
                    self.isLoading = false
                    return
                }
                
                let topClassifications = results.prefix(3).compactMap { observation in
                    observation.identifier
                }
                
                if !topClassifications.isEmpty {
                    // Generate a more descriptive caption
                    let mainObject = topClassifications.first ?? "object"
                    let confidence = results.first?.confidence ?? 0.0
                    
                    if confidence > 0.7 {
                        self.description = "This image shows a \(mainObject). "
                        
                        // Add additional context if multiple objects detected
                        if topClassifications.count > 1 {
                            let additionalObjects = Array(topClassifications.dropFirst()).joined(separator: ", ")
                            self.description += "Also visible: \(additionalObjects)."
                        }
                        
                        // Add descriptive context based on confidence
                        if confidence > 0.9 {
                            self.description += " The object is clearly visible and easily identifiable."
                        } else if confidence > 0.8 {
                            self.description += " The object is well-defined in the image."
                        }
                    } else {
                        self.description = "The image appears to contain: " + topClassifications.joined(separator: ", ")
                    }
                } else {
                    self.description = "No specific objects could be clearly identified in the image."
                }
                self.isLoading = false
            }
        }
        
        do {
            try requestHandler.perform([classificationRequest])
        } catch {
            DispatchQueue.main.async {
                if error.localizedDescription.contains("espresso") {
                    self.fallbackAnalysis(cgImage: cgImage)
                } else {
                    self.description = "Error performing analysis: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fallbackAnalysis(cgImage: CGImage) {
        // Fallback: Provide basic image information
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = cgImage.colorSpace?.name as String? ?? "Unknown"
        
        let imageInfo = """
        Image Analysis:
        - Dimensions: \(width) x \(height) pixels
        - Color space: \(colorSpace)
        - File size: \(estimateFileSize(width: width, height: height)) KB
        
        Note: Advanced AI analysis is not available on this device.
        Please try on a physical device for better results.
        """
        
        self.description = imageInfo
        self.isLoading = false
    }
    
    private func estimateFileSize(width: Int, height: Int) -> Int {
        // Rough estimate: 4 bytes per pixel (RGBA)
        let bytes = width * height * 4
        return bytes / 1024
    }
}

struct OptionsView: View {
    @ObservedObject var appSettings: AppSettings
    @State private var sellerCode: String = ""
    @State private var storeName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        _sellerCode = State(initialValue: appSettings.sellerCode)
        _storeName = State(initialValue: appSettings.storeName)
    }
    
    var body: some View {
        NavigationView {
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
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
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
