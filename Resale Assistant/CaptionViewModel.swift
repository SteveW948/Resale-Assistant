//
//  CaptionViewModel.swift
//  Resale Assistant
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CaptionViewModel {
    var captionText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    private var analysisTask: Task<Void, Never>?

    func generateCaption(for image: UIImage, store: CaptionGenerator.StoreContext) {
        analysisTask?.cancel()
        isLoading = true
        captionText = ""
        errorMessage = nil

        guard let cgImage = image.cgImage else {
            errorMessage = "Could not process this image."
            isLoading = false
            return
        }

        analysisTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try await CaptionGenerator.analyze(cgImage: cgImage, store: store)
                }.value

                guard !Task.isCancelled else { return }
                captionText = result
                isLoading = false
            } catch is CancellationError {
                isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                // Prefer a usable fallback over surfacing raw Vision failures (common on simulator).
                captionText = CaptionGenerator.fallbackCaption(cgImage: cgImage, store: store)
                errorMessage = nil
                isLoading = false
            }
        }
    }

    func reset() {
        analysisTask?.cancel()
        analysisTask = nil
        captionText = ""
        isLoading = false
        errorMessage = nil
    }
}
