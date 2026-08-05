//
//  ContentView.swift
//  Resale Assistant
//

import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var captionViewModel = CaptionViewModel()
    @State private var showOptions = false
    @State private var appSettings = AppSettings()
    @State private var showCameraUnavailableAlert = false

    private var storeContext: CaptionGenerator.StoreContext {
        CaptionGenerator.StoreContext(
            sellerCode: appSettings.sellerCode,
            storeName: appSettings.storeName
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image = capturedImage {
                    PhotoReviewView(
                        image: image,
                        captionViewModel: captionViewModel,
                        onRetake: {
                            capturedImage = nil
                            captionViewModel.reset()
                            openPreferredCapture()
                        },
                        onGenerateCaption: {
                            captionViewModel.generateCaption(for: image, store: storeContext)
                        },
                        onCancel: {
                            capturedImage = nil
                            captionViewModel.reset()
                        }
                    )
                } else {
                    EmptyCaptureView(
                        onTakePhoto: openPreferredCapture,
                        onChoosePhoto: { showPhotoLibrary = true },
                        cameraAvailable: ImageSource.isCameraAvailable,
                        photoLibraryAvailable: ImageSource.isPhotoLibraryAvailable
                    )
                }
            }
            .navigationTitle("Resale Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Options", systemImage: "gearshape") {
                        showOptions = true
                    }
                    .accessibilityLabel("Options")
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $capturedImage, isShown: $showCamera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryImagePicker(image: $capturedImage, isShown: $showPhotoLibrary)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showOptions) {
            OptionsView(appSettings: appSettings)
        }
        .alert(
            "Camera Unavailable",
            isPresented: $showCameraUnavailableAlert
        ) {
            if ImageSource.isPhotoLibraryAvailable {
                Button("Choose Photo") {
                    showPhotoLibrary = true
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not have a camera available. You can choose a photo from your library instead.")
        }
        .alert(
            "Caption Error",
            isPresented: Binding(
                get: { captionViewModel.errorMessage != nil },
                set: { if !$0 { captionViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                captionViewModel.errorMessage = nil
            }
        } message: {
            Text(captionViewModel.errorMessage ?? "")
        }
    }

    private func openPreferredCapture() {
        if ImageSource.isCameraAvailable {
            showCamera = true
        } else if ImageSource.isPhotoLibraryAvailable {
            showPhotoLibrary = true
        } else {
            showCameraUnavailableAlert = true
        }
    }
}

// MARK: - Subviews

private struct EmptyCaptureView: View {
    let onTakePhoto: () -> Void
    let onChoosePhoto: () -> Void
    let cameraAvailable: Bool
    let photoLibraryAvailable: Bool

    var body: some View {
        ContentUnavailableView {
            Label("Resale Assistant", systemImage: "camera.viewfinder")
        } description: {
            Text("Take or choose a photo of an item to generate a listing caption. Set your store details in Options.")
        } actions: {
            if cameraAvailable {
                Button("Take Photo", systemImage: "camera") {
                    onTakePhoto()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens the camera to photograph an item")
            }

            if photoLibraryAvailable {
                Button("Choose Photo", systemImage: "photo.on.rectangle") {
                    onChoosePhoto()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens your photo library")
            }
        }
    }
}

private struct PhotoReviewView: View {
    let image: UIImage
    @Bindable var captionViewModel: CaptionViewModel
    let onRetake: () -> Void
    let onGenerateCaption: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.vertical) { length, _ in
                        length * 0.4
                    }
                    .accessibilityLabel("Captured item photo")
                    .clipShape(.rect(cornerRadius: 12))
                    .padding()

                if captionViewModel.isLoading {
                    ProgressView("Generating caption...")
                        .accessibilityLabel("Generating caption")
                } else if !captionViewModel.captionText.isEmpty {
                    Text("Caption")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    TextEditor(text: $captionViewModel.captionText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.secondary.opacity(0.4))
                        }
                        .padding(.horizontal)
                        .accessibilityLabel("Editable caption")

                    ShareLink(item: captionViewModel.captionText) {
                        Label("Share Caption", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button("Copy Caption", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = captionViewModel.captionText
                    }
                    .buttonStyle(.bordered)
                }

                VStack {
                    Button("Generate Caption") {
                        onGenerateCaption()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(captionViewModel.isLoading)
                    .accessibilityHint("Analyzes the photo and writes a listing caption")

                    Button("Retake") {
                        onRetake()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(captionViewModel.isLoading)

                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .disabled(captionViewModel.isLoading)
                }
                .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}
