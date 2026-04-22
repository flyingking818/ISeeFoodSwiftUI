# ISeeFoodApp — CoreML Image Recognition Demo
## Flagler College CIS 331 - Mobile App Demo.

---

## What This App Does

ISeeFoodApp is a Silicon Valley-inspired food classifier. Users take a photo or
pick one from their library, tap Analyze, and the app runs an on-device CoreML
model to identify what's in the image.

This demo teaches:
- CoreML + Vision framework integration
- MVVM architecture in SwiftUI
- Async/await for background ML inference
- UIKit bridging (camera via UIViewControllerRepresentable)
- State-driven UI with @Published and ObservableObject

---

## Project Structure

    ISeeFoodApp/
    ├── App/
    │   └── ISeeFoodApp.swift           # @main entry point → launches MainView
    ├── Models/
    │   └── FoodClassificationModel.swift  # All model layer in one file:
    │                                      #   FoodClassification (data)
    │                                      #   ClassificationState (enum)
    │                                      #   FoodClassifierService (CoreML + Vision)
    │                                      #   ClassifierError (error types)
    │                                      #   UIImage orientation extension
    ├── ViewModels/
    │   └── FoodViewModel.swift         # @Published state + business logic
    └── Views/
        ├── MainView.swift              # Root view — owns @StateObject, NavigationStack
        ├── ResultsView.swift           # Prediction card + confidence bars
        └── ImagePickerView.swift       # UIKit camera bridge (UIViewControllerRepresentable)

---

## MVVM at a Glance

    VIEW (MainView / ResultsView / ImagePickerView)
      Reads @Published state. Calls ViewModel methods. Zero logic.
         |
         | @StateObject / @EnvironmentObject
         v
    VIEW MODEL (FoodViewModel)
      Owns state. Runs classification on a background thread.
      @Published properties trigger View re-renders automatically.
         |
         |
         v
    MODEL (FoodClassificationModel.swift)
      FoodClassification — plain data struct, no UI
      ClassificationState — enum tracking idle/analyzing/results/error
      FoodClassifierService — loads CoreML model, runs Vision request
      No SwiftUI imports. No UI knowledge.

---

## Getting Started

### Step 1 — Add the CoreML Model

1. Download MobileNetV2.mlmodel from:
   https://developer.apple.com/machine-learning/models/

2. Drag MobileNetV2.mlmodel into your Xcode project navigator.
   Check: "Add to target: ISeeFoodApp"

3. Build and run. The model loads automatically via FoodClassifierService.

### Step 2 — Info.plist Privacy Keys

Add these two keys to your Info.plist (Xcode target > Info tab):

   NSCameraUsageDescription
   "ISeefood needs the camera to analyze your food."

   NSPhotoLibraryUsageDescription
   "ISeefood needs photo access to analyze images."

Without these the app will crash when accessing camera or photos.

###To this , open up your Xcode, then click on your project name (the blue icon) in the left sidebar
1. Select your target (ISeeFoodSwiftUI)
2. Click the Info tab at the top
3. Under Custom iOS Target Properties, hover over any existing row and click the + button
4. Type Privacy - Camera Usage Description and press Enter
5. In the Value column, type: ISeefood needs the camera to analyze your food.
6. Click + again
6. Type Privacy - Photo Library Usage Description and press Enter
7. In the Value column, type: ISeefood needs photo access to analyze images.
---

## Key Concepts in this Demo

CoreML
  Apple's on-device ML framework. MobileNetV2.mlmodel runs entirely on the
  device — no network call, no privacy concern. The Neural Engine on modern
  iPhones processes billions of operations per second.

Vision Framework
  Sits on top of CoreML. Handles image resizing, pixel format conversion, and
  orientation correction before feeding the image to the model. We hand Vision
  a UIImage; it takes care of converting it to the 224x224 CVPixelBuffer that
  MobileNetV2 expects.

CoreML + Vision relationship
  VNCoreMLModel wraps the raw MLModel — this is the handoff point.
  Vision owns everything before and after the model.
  CoreML is only the model itself. Swap MobileNetV2 for any other classifier
  and the Vision code doesn't change at all.

ImageNet Label Cleaning
  MobileNetV2 returns raw ImageNet identifiers: "n07871810 meat loaf, meatloaf"
  FoodClassifierService.cleanLabel() strips the synset ID and takes the first
  synonym so the user sees "Meat Loaf" instead.

@MainActor
  Pins FoodViewModel to the main thread. SwiftUI requires @Published updates on
  the main thread — @MainActor enforces this automatically at compile time.

Task.detached + await MainActor.run
  CoreML inference is expensive. Task.detached moves it off the main thread so
  the UI stays responsive. await MainActor.run {} jumps back to update state.

DispatchSemaphore
  Vision's completion handler fires asynchronously. The semaphore blocks the
  background thread until results are ready before classify() returns.
  value: 0 = gate starts closed. signal() opens it. wait() blocks until open.

UIViewControllerRepresentable
  SwiftUI has no native camera view. ImagePickerView wraps UIImagePickerController
  using this protocol. The Coordinator class bridges UIKit delegate callbacks back
  to SwiftUI bindings.

---

## Discussion Questions

1. What CoreML and how is it used along Vision in this AI app?
2. What is image recognition and what are some of the popular image recognition models?
3. How is the MobileNetV2 (or Inceptionv3 used in the Udemy demo) model implemented in the iSeeFood app. What are the major steps?
3. What extra AI features would you like to implement in the iSeeFood app? How would you go about doing that?

---

## Extension Ideas

- Firestore Logging — Save each result to Cloud Firestore with a timestamp
- Share Sheet — Use ShareLink to share the image and top prediction
- Custom Model — Train your own food classifier with Create ML
- Confidence Threshold — Only show the result if confidence is above 70%
- Camera Live Preview — Use AVFoundation for real-time classification


