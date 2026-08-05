//
//  ImagePicker.swift
//  Resale Assistant
//

import SwiftUI
import UIKit

#if targetEnvironment(simulator)
@preconcurrency import MockImagePicker
#endif

enum ImageSource {
    case camera
    case photoLibrary

    @MainActor
    static var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    @MainActor
    static var isPhotoLibraryAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }
}

/// Camera capture. Uses MockImagePicker on the simulator.
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isShown: Bool

    #if targetEnvironment(simulator)
    func makeUIViewController(context: Context) -> MockImagePicker {
        let picker = MockImagePicker()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: MockImagePicker, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, isShown: $isShown)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, MockImagePickerDelegate {
        var image: Binding<UIImage?>
        var isShown: Binding<Bool>

        init(image: Binding<UIImage?>, isShown: Binding<Bool>) {
            self.image = image
            self.isShown = isShown
        }

        nonisolated func imagePickerController(
            _ picker: MockImagePicker,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let captured = info[.originalImage] as? UIImage
            Task { @MainActor in
                image.wrappedValue = captured
                isShown.wrappedValue = false
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: MockImagePicker) {
            Task { @MainActor in
                isShown.wrappedValue = false
            }
        }
    }
    #else
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, isShown: $isShown)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var image: Binding<UIImage?>
        var isShown: Binding<Bool>

        init(image: Binding<UIImage?>, isShown: Binding<Bool>) {
            self.image = image
            self.isShown = isShown
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            image.wrappedValue = info[.originalImage] as? UIImage
            isShown.wrappedValue = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isShown.wrappedValue = false
        }
    }
    #endif
}

/// Photo library picker (real UIImagePickerController on device and simulator).
struct PhotoLibraryImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isShown: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, isShown: $isShown)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var image: Binding<UIImage?>
        var isShown: Binding<Bool>

        init(image: Binding<UIImage?>, isShown: Binding<Bool>) {
            self.image = image
            self.isShown = isShown
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            image.wrappedValue = info[.originalImage] as? UIImage
            isShown.wrappedValue = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isShown.wrappedValue = false
        }
    }
}
