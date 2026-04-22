// FoodClassificationModel.swift
// ISeeFoodApp
// Last updated by Jeremy Wang on 4/13/2026

// MARK: - Model Layer (The "M" in MVVM)
//
// This file contains everything related to food classification:
//   1. FoodClassification  — a single prediction result from CoreML
//   2. ClassificationState — tracks the current state of the workflow
//   3. FoodClassifierService — loads the CoreML model and runs inference
//   4. ClassifierError     — strongly-typed errors from the classifier
//
// CoreML and Vision work together here:
//   CoreML  — loads MobileNetV2.mlmodel and runs inference on-device.
//             No network call is ever made; your data stays private.
//   Vision  — handles image resizing, format conversion, and orientation
//             correction before feeding the image to CoreML. Without Vision
//             you'd have to supply a CVPixelBuffer at exactly 224x224 yourself.
//
// Why use Vision instead of CoreML directly?
//   CoreML expects images in a very specific format (CVPixelBuffer at a fixed
//   size). Vision wraps that complexity for us. We just hand it a UIImage and
//   it takes care of the rest.
//
// IMPORTANT — Adding the Model:
//   1. Download MobileNetV2.mlmodel from developer.apple.com/machine-learning/models
//   2. Drag it into your Xcode project navigator
//   3. Make sure "Add to target: ISeeFoodApp" is checked
//   4. Xcode auto-generates a Swift class named MobileNetV2 — use it like this:
//        let coreMLModel = try MobileNetV2(configuration: config).model

import CoreML
import Vision
import UIKit

// MARK: - FoodClassification

// Represents a single prediction returned by the CoreML model.
//
// CoreML's VNClassificationObservation gives us an identifier (label) and
// a confidence (0.0 – 1.0). We wrap these in our own type so the rest of
// the app doesn't need to import Vision everywhere.
struct FoodClassification: Identifiable {

    // Identifiable requires an `id` so SwiftUI can track items in lists.
    let id = UUID()

    // The human-readable label, e.g. "pizza", "hot dog", "sushi".
    let label: String

    // Model confidence from 0.0 (no confidence) to 1.0 (certain).
    let confidence: Double

    // Formats confidence as a percentage string. Example: 0.923 → "92%"
    var confidencePercent: String {
        "\(Int((confidence * 100).rounded()))%"
    }
}

// MARK: - ClassificationState

// Tracks which phase of the classification workflow we are in.
//
// Using an enum for state (rather than multiple Bool flags) is a Swift best
// practice. It guarantees you can never be in two contradictory states at once,
// e.g., `isLoading = true` AND `hasError = true` simultaneously.
//
// Each case carries exactly the data it needs via associated values.
enum ClassificationState {
    case idle
    case analyzing
    case results([FoodClassification])
    case error(String)
}

// MARK: - FoodClassifierService

// Loads the CoreML model and runs image classification via the Vision framework.
//
// Marked as a `class` (not a struct) because:
//   - We hold onto a VNCoreMLModel, which is a reference type
//   - We want to initialize it once and reuse it (model loading is expensive)
//   - The ViewModel owns a single shared instance
final class FoodClassifierService {

    // The Vision-wrapped CoreML model, ready to receive image requests.
    // Optional because model loading can fail (missing file, corrupt data, etc.)
    private var visionModel: VNCoreMLModel?

    init() {
        loadModel()
    }

    // MARK: - Model Loading

    // Loads MobileNetV2 from the app bundle and wraps it for Vision.
    //
    // Called once at init. If it fails, visionModel stays nil and
    // classify() will throw ClassifierError.modelNotLoaded gracefully.
    private func loadModel() {
        do {
            // MLModelConfiguration controls which hardware runs the model.
            // .all lets CoreML pick the fastest option automatically:
            // Neural Engine > GPU > CPU
            let config = MLModelConfiguration()
            config.computeUnits = .all

            // IMPORTANT: Once you've added MobileNetV2.mlmodel to your project,
            // replace the guard block below with the auto-generated class:
            //   let coreMLModel = try MobileNetV2(configuration: config).model
            //
            // You can also try the older Inceptionv3 model from the Udemy course.
            guard let modelURL = Bundle.main.url(forResource: "MobileNetV2",
                                                  withExtension: "mlmodelc") else {
                print("MobileNetV2.mlmodelc not found. Add MobileNetV2.mlmodel to your Xcode project.")
                return
            }

            let coreMLModel = try MLModel(contentsOf: modelURL, configuration: config)

            // VNCoreMLModel wraps the raw MLModel so Vision can drive it.
            // This is the handoff point between CoreML and Vision:
            // Vision handles everything before and after the model.
            // CoreML is only the model itself. You could swap MobileNetV2 for
            // any other image classifier and the Vision code wouldn't change at all.
            visionModel = try VNCoreMLModel(for: coreMLModel)

            print("CoreML model loaded successfully.")

        } catch {
            print("Failed to load CoreML model: \(error.localizedDescription)")
        }
    }

    // MARK: - Classification

    // Runs image classification on the provided UIImage.
    //
    // This function is synchronous and does CPU/GPU work, so the ViewModel
    // calls it on a background thread (Task.detached) to avoid freezing the UI.
    func classify(image: UIImage) throws -> [FoodClassification] {

        guard let visionModel else {
            throw ClassifierError.modelNotLoaded
        }

        // Vision works with CGImage (raw pixel bitmap), not UIImage (UIKit wrapper).
        // UIImage.cgImage is optional — if the image was created from a CIImage
        // instead, it returns nil and we throw rather than crash.
        guard let cgImage = image.cgImage else {
            throw ClassifierError.invalidImage
        }

        var results: [FoodClassification] = []

        // Semaphore blocks this background thread until Vision's completion handler
        // fires. Without it, classify() would return before results are populated.
        // value: 0 means the gate starts closed.
        //
        // The semaphore is one of the oldest concepts in computer science —
        // invented by Edsger Dijkstra in 1965 as a way for threads to coordinate
        // without constantly checking "are you done yet?" in a loop.
        // The wait and signal names come from his original Dutch terms P and V.
        let semaphore = DispatchSemaphore(value: 0)

        // VNCoreMLRequest feeds the image through our model and calls the
        // completion handler with an array of VNClassificationObservation objects.
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            defer { semaphore.signal() }  // Always open the gate, even on error

            if let error {
                print("Vision request error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNClassificationObservation] else {
                return
            }

            // MobileNetV2 labels come back as raw ImageNet identifiers:
            //   "n07871810 meat loaf, meatloaf"
            
            //    Synset ID  Comma-separated synonyms
            //
            // cleanLabel() strips the synset ID and takes the first synonym
            // so the user sees "meat loaf" instead of the raw identifier.
            results = observations
                .prefix(5)
                .map { obs in
                    FoodClassification(
                        label: Self.cleanLabel(obs.identifier),
                        confidence: Double(obs.confidence)
                    )
                }
        }

        // .scaleFill stretches the full image to 224x224 (MobileNetV2's input size).
        // Better than .centerCrop, which can cut out the subject if it's off-center.
        request.imageCropAndScaleOption = .scaleFill

        // VNImageRequestHandler takes the CGImage plus an orientation hint so
        // Vision knows which way is "up" before feeding it to the model.
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: image.cgImageOrientation,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            throw ClassifierError.requestFailed(error.localizedDescription)
        }

        semaphore.wait()
        return results
    }

    // MARK: - Label Cleaning

    // Strips the ImageNet synset ID and returns just the first human-readable name.
    //
    // "n07871810 meat loaf, meatloaf"  →  "meat loaf"
    // "n07697313 cheeseburger"          →  "cheeseburger"
    // "pizza, pizza pie"                →  "pizza"
    static func cleanLabel(_ raw: String) -> String {
        var label = raw

        // Remove the WordNet synset prefix (e.g. "n07871810 ")
        if label.hasPrefix("n"),
           let spaceIndex = label.firstIndex(of: " "),
           label.distance(from: label.startIndex, to: spaceIndex) <= 12 {
            label = String(label[label.index(after: spaceIndex)...])
        }

        // Take only the first synonym before any comma
        if let commaIndex = label.firstIndex(of: ",") {
            label = String(label[..<commaIndex])
        }

        return label.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ClassifierError

// Strongly-typed errors thrown by FoodClassifierService.
enum ClassifierError: LocalizedError {

    case modelNotLoaded
    case invalidImage
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The ML model could not be loaded. Make sure MobileNetV2.mlmodel is added to your Xcode project."
        case .invalidImage:
            return "The selected image could not be read."
        case .requestFailed(let message):
            return "Classification failed: \(message)"
        }
    }
}

// MARK: - UIImage Orientation Extension

// Bridges UIImage.Orientation to CGImagePropertyOrientation.
//
// UIKit and Core Graphics define orientation as two separate enums that don't
// know about each other. VNImageRequestHandler needs CGImagePropertyOrientation,
// so this extension translates the UIKit value across.
extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
