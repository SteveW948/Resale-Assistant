//
//  CaptionGenerator.swift
//  Resale Assistant
//

import Foundation
import Vision
import CoreGraphics

/// Pure caption-building helpers and Vision orchestration (testable, nonisolated).
enum CaptionGenerator {
    struct StoreContext: Sendable {
        var sellerCode: String
        var storeName: String
    }

    /// Builds a listing-style caption from Vision classification results.
    static func caption(
        from classifications: [(identifier: String, confidence: Float)],
        store: StoreContext
    ) -> String {
        let top = Array(classifications.prefix(3))
        guard !top.isEmpty else {
            return appendStoreContext(
                "No specific objects could be clearly identified in the image.",
                store: store
            )
        }

        let mainObject = top[0].identifier
        let confidence = top[0].confidence
        var body: String

        if confidence > 0.7 {
            body = "This item appears to be a \(mainObject)."
            if top.count > 1 {
                let additional = top.dropFirst().map(\.identifier).joined(separator: ", ")
                body += " Also visible: \(additional)."
            }
            if confidence > 0.9 {
                body += " The item is clearly visible and easily identifiable."
            } else if confidence > 0.8 {
                body += " The item is well-defined in the image."
            }
        } else {
            body = "Possible item categories: " + top.map(\.identifier).joined(separator: ", ") + "."
        }

        return appendStoreContext(body, store: store)
    }

    /// Fallback when Vision classification is unavailable.
    static func fallbackCaption(width: Int, height: Int, colorSpaceName: String, store: StoreContext) -> String {
        let sizeKb = (width * height * 4) / 1024
        let body = """
        Image Analysis:
        - Dimensions: \(width) x \(height) pixels
        - Color space: \(colorSpaceName)
        - File size: \(sizeKb) KB

        Note: Advanced AI analysis is not available on this device. Please try on a physical device for better results.
        """
        return appendStoreContext(body, store: store)
    }

    static func fallbackCaption(cgImage: CGImage, store: StoreContext) -> String {
        let colorSpace = cgImage.colorSpace?.name as String? ?? "Unknown"
        return fallbackCaption(
            width: cgImage.width,
            height: cgImage.height,
            colorSpaceName: colorSpace,
            store: store
        )
    }

    /// Appends seller/store lines when present.
    static func appendStoreContext(_ body: String, store: StoreContext) -> String {
        var parts = [body.trimmingCharacters(in: .whitespacesAndNewlines)]
        if !store.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Store: \(store.storeName)")
        }
        if !store.sellerCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Seller code: \(store.sellerCode)")
        }
        return parts.joined(separator: "\n\n")
    }

    /// Returns true when the error indicates Vision classification is unavailable (e.g. simulator).
    static func shouldUseFallback(for error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == VNErrorDomain {
            // Model / request failures often surface as VNErrorInvalidModel or similar.
            return true
        }
        let description = error.localizedDescription.lowercased()
        return description.contains("espresso")
            || description.contains("model")
            || description.contains("not available")
    }

    /// Runs Vision classification and returns a caption string, or throws.
    nonisolated static func analyze(cgImage: CGImage, store: StoreContext) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didResume = false

            func resumeOnce(_ result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let classificationRequest = VNClassifyImageRequest { request, error in
                if let error {
                    // Vision often reports model/simulator failures here; prefer a usable fallback.
                    if shouldUseFallback(for: error) {
                        resumeOnce(.success(fallbackCaption(cgImage: cgImage, store: store)))
                    } else {
                        resumeOnce(.failure(error))
                    }
                    return
                }

                guard let results = request.results as? [VNClassificationObservation] else {
                    resumeOnce(
                        .success(appendStoreContext("No content detected in the image.", store: store))
                    )
                    return
                }

                let pairs = results.map { (identifier: $0.identifier, confidence: $0.confidence) }
                resumeOnce(.success(caption(from: pairs, store: store)))
            }

            do {
                try requestHandler.perform([classificationRequest])
            } catch {
                // `perform` can throw after the completion handler already resumed — resume at most once.
                if shouldUseFallback(for: error) {
                    resumeOnce(.success(fallbackCaption(cgImage: cgImage, store: store)))
                } else {
                    resumeOnce(.failure(error))
                }
            }
        }
    }
}
