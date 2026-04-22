// ImagePickerView.swift
// ISeeFoodApp
//
// MARK: - UIKit Bridge for Camera Access
//
// SwiftUI does not have a native camera view (as of iOS 17). To use the camera,
// we bridge to UIKit's UIImagePickerController using the UIViewControllerRepresentable
// protocol.
//
// UIViewControllerRepresentable is SwiftUI's adapter protocol for embedding
// UIKit view controllers inside SwiftUI views. It requires two things:
//
//   1. makeUIViewController — Creates and configures the UIKit controller
//   2. updateUIViewController — Updates it when SwiftUI state changes (often a no-op)
//
// The Coordinator pattern:
//   UIKit controllers communicate via delegate callbacks (e.g., "the user picked a photo").
//   SwiftUI doesn't understand delegates, so we use a Coordinator class that:
//     - Acts as the UIKit delegate
//     - Holds a reference back to our SwiftUI struct
//     - Bridges the callback into a @Binding update
//
// This is a standard, reusable pattern — you'll copy this whenever you need
// the camera in a SwiftUI app until Apple ships a native API.

import SwiftUI
import UIKit

/// A SwiftUI-compatible wrapper around UIImagePickerController.
///
/// Usage:
/// ```
/// ImagePickerView(image: $viewModel.selectedImage, sourceType: .camera)
/// ```
struct ImagePickerView: UIViewControllerRepresentable {

    // MARK: - Properties

    /// Binding to the image selected by the user.
    /// When the user picks a photo, we write the UIImage into this binding,
    /// which automatically updates the ViewModel's `selectedImage`.
    @Binding var image: UIImage?

    /// .camera for the live camera, .photoLibrary for the photo roll.
    var sourceType: UIImagePickerController.SourceType = .camera

    /// Dismisses this sheet when the user cancels or picks a photo.
    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    /// Creates the UIKit view controller SwiftUI will manage.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        // The Coordinator acts as the picker's delegate
        picker.delegate = context.coordinator
        return picker
    }

    /// Called when SwiftUI needs to update the UIKit controller.
    /// UIImagePickerController doesn't need dynamic updates, so this is empty.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Creates the Coordinator that bridges UIKit delegate callbacks to SwiftUI.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    /// Bridges UIImagePickerControllerDelegate to our SwiftUI binding.
    ///
    /// The Coordinator is a class (not struct) because UIKit delegates are
    /// always reference types — they're stored weakly by UIKit.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        /// Reference back to the parent SwiftUI struct.
        /// `var` (not `let`) because the binding can change.
        var parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        /// Called when the user picks or takes a photo.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // The info dictionary contains the image under .originalImage.
            // We cast it to UIImage and write it into the binding.
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        /// Called when the user taps Cancel.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
