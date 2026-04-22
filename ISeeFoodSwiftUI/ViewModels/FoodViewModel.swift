// FoodViewModel.swift
// ISeeFoodApp
//
// MARK: - ViewModel Layer (The "VM" in MVVM)
//
// The ViewModel is the brain of the MVVM pattern. Its responsibilities are:
//
//   1. HOLD STATE — What image is selected? Are we loading? What are the results?
//   2. BUSINESS LOGIC — Calling the classifier, handling errors, formatting data
//   3. PUBLISH CHANGES — Notify the View whenever state changes so SwiftUI
//                        can automatically re-render the affected parts
//
// The View should be as "dumb" as possible — it only reads from the ViewModel
// and calls its functions. No logic lives in the View itself.
//
// Key SwiftUI concepts used here:
//
//   @MainActor
//     Ensures all UI-touching code runs on the main thread. SwiftUI requires
//     that @Published properties are updated on the main thread; @MainActor
//     enforces this automatically.
//
//   ObservableObject
//     A protocol that lets SwiftUI Views subscribe to changes in this class.
//     Any View that uses @StateObject or @ObservedObject with this class
//     will automatically re-render when a @Published property changes.
//
//   @Published
//     A property wrapper that broadcasts changes. When `state` changes,
//     SwiftUI sees the change and redraws every View that depends on it.

import SwiftUI
import PhotosUI
import Combine

@MainActor
final class FoodViewModel: ObservableObject {

    // MARK: - Published State

    /// The current phase of the recognition workflow.
    /// The View switches its layout based on this value.
    @Published var state: ClassificationState = .idle

    /// The image selected by the user (from camera or photo library).
    @Published var selectedImage: UIImage?

    /// Controls whether the camera sheet is presented.
    @Published var showCamera = false

    /// The selected PhotosPickerItem from the SwiftUI PhotosPicker.
    /// Setting this triggers loadTransferable to convert it to a UIImage.
    @Published var photoPickerItem: PhotosPickerItem? {
        didSet {
            if let item = photoPickerItem {
                loadTransferable(from: item)
            }
        }
    }

    // MARK: - Dependencies

    /// The CoreML + Vision classifier. Created once and reused for the
    /// lifetime of the ViewModel. Model loading happens inside init().
    private let classifier = FoodClassifierService()

    // MARK: - Image Loading

    /// Loads a UIImage from a PhotosPickerItem selected via SwiftUI's PhotosPicker.
    ///
    /// PhotosPickerItem uses the Transferable protocol — a modern Swift concurrency
    /// approach to moving data between processes. We request a Data representation,
    /// then convert it to a UIImage.
    private func loadTransferable(from item: PhotosPickerItem) {
        Task {
            do {
                // loadTransferable is async — it asks the Photos framework to
                // provide the image data. The await pauses this Task until ready.
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    state = .idle
                }
            } catch {
                state = .error("Could not load the selected photo: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Classification

    /// Runs the CoreML model on selectedImage and updates state with results.
    ///
    /// Thread safety:
    ///   CoreML does heavy CPU/GPU work. Task.detached moves that work off the
    ///   main thread so the UI stays responsive during inference. After inference
    ///   completes, await MainActor.run {} brings us back to the main thread to
    ///   safely update @Published properties.
    func analyzeImage() {
        guard let image = selectedImage else { return }

        state = .analyzing

        Task.detached { [weak self] in
            guard let self else { return }

            do {
                let results = try self.classifier.classify(image: image)

                await MainActor.run {
                    if results.isEmpty {
                        self.state = .error("The model returned no predictions. Try a clearer image.")
                    } else {
                        self.state = .results(results)
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    /// Resets the app back to the initial idle state.
    func reset() {
        selectedImage = nil
        photoPickerItem = nil
        state = .idle
    }

    // MARK: - Computed Helpers

    /// The top prediction's label, capitalized for display.
    /// Example: "hot dog" → "Hot Dog"
    var topLabel: String? {
        guard case .results(let classifications) = state else { return nil }
        return classifications.first?.label.capitalized
    }

    /// The top prediction's confidence as a percentage string.
    /// Example: 0.923 → "92%"
    var topConfidence: String? {
        guard case .results(let classifications) = state else { return nil }
        return classifications.first?.confidencePercent
    }
}
