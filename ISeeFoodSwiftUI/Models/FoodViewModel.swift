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
//     Any View that uses `@StateObject` or `@ObservedObject` with this class
//     will automatically re-render when a @Published property changes.
//
//   @Published
//     A property wrapper that broadcasts changes. When `state` changes,
//     SwiftUI sees the change and redraws every View that depends on it.

import SwiftUI
import Combine
import PhotosUI

@MainActor
final class FoodViewModel: ObservableObject {

    // MARK: - Published State
    //
    // These are the properties the View observes. When any of them change,
    // every View subscribed to this ViewModel will re-evaluate its body.

    /// The current phase of the recognition workflow.
    /// The View switches its layout based on this value.
    @Published var state: ClassificationState = .idle

    /// The image selected by the user (from camera or photo library).
    @Published var selectedImage: UIImage?

    /// Controls whether the image source picker sheet is presented.
    @Published var showImagePicker = false

    /// Controls whether the camera is presented.
    @Published var showCamera = false

    /// The selected PhotosPickerItem from the SwiftUI PhotosPicker.
    /// Setting this triggers the `onChange` handler in the View to load the image.
    @Published var photoPickerItem: PhotosPickerItem? {
        didSet {
            if let item = photoPickerItem {
                loadTransferable(from: item)
            }
        }
    }

    // MARK: - Dependencies

    /// The object that performs actual image classification.
    /// Using the `Classifiable` protocol here (not `FoodClassifierService` directly)
    /// means we can swap in MockFoodClassifier without changing any other code.
    ///
    /// For classroom use: swap to MockFoodClassifier() if you don't have the .mlmodel
    private let classifier: Classifiable

    // MARK: - Initialization

    init(classifier: Classifiable = MockFoodClassifier()) {
        self.classifier = classifier
        // 💡 STUDENTS: Once you've added MobileNetV2.mlmodel to your project,
        // change the default above to: FoodClassifierService()
    }

    // MARK: - Image Loading

    /// Loads a UIImage from a PhotosPickerItem selected via SwiftUI's PhotosPicker.
    ///
    /// PhotosPickerItem uses the Transferable protocol — a modern Swift concurrency
    /// approach to moving data between processes. We request a `Data` representation,
    /// then convert it to UIImage.
    private func loadTransferable(from item: PhotosPickerItem) {
        Task {
            do {
                // `loadTransferable` is async — it asks the Photos framework to
                // give us the image data. The `await` pauses this Task until ready.
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    state = .idle  // Reset so user sees the image with Analyze button
                }
            } catch {
                state = .error("Could not load the selected photo: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Classification

    /// Runs the CoreML model on `selectedImage` and updates state with results.
    ///
    /// This is an `async` function called from an `async` Task.
    ///
    /// Thread safety:
    ///   The classifier does heavy computation on a background thread
    ///   (`Task.detached` or background executor). We update `@Published`
    ///   properties here, which is safe because `FoodViewModel` is `@MainActor`.
    func analyzeImage() {
        guard let image = selectedImage else { return }

        state = .analyzing

        // Task { } creates a new unit of async work.
        // Because FoodViewModel is @MainActor, this Task runs on the main thread.
        // We use Task.detached to move the expensive classify() call off main.
        Task.detached { [weak self] in
            guard let self else { return }

            do {
                // `classify` does CPU/GPU work. Running it on a detached Task
                // keeps the UI responsive while the model is processing.
                let results = try self.classifier.classify(image: image)

                // Jump back to the main actor to update published state.
                // @MainActor properties must be mutated on the main thread.
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

    // MARK: - Computed Helpers (used by the View)

    /// Returns true if we have a result and the top prediction is food.
    var topResultIsFood: Bool {
        guard case .results(let classifications) = state,
              let top = classifications.first else {
            return false
        }
        return top.isFoodConfident
    }

    /// The top prediction's label, formatted for display ("pizza" → "Pizza").
    var topLabel: String? {
        guard case .results(let classifications) = state else { return nil }
        return classifications.first?.label.capitalized
    }

    /// The top prediction's confidence percentage string.
    var topConfidence: String? {
        guard case .results(let classifications) = state else { return nil }
        return classifications.first?.confidencePercent
    }
}
