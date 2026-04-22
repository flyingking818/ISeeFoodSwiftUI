# ISeeFoodApp — CoreML Image Recognition Demo
## Flagler College iOS Development

---

## What This App Does

**ISeeFoodApp** is a Silicon Valley-inspired "Is it food?" classifier. Users take
a photo or pick one from their library, tap Analyze, and the app runs an on-device
CoreML model to identify what's in the image — then dramatically declares whether
it's food or not.

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
    │   └── ISeeFoodApp.swift           # @main entry point
    ├── Models/
    │   ├── FoodClassification.swift    # Data models & ClassificationState enum
    │   ├── FoodClassifierService.swift # CoreML + Vision integration
    │   └── MockFoodClassifier.swift    # Fake classifier for demos (no model needed)
    ├── ViewModels/
    │   └── FoodViewModel.swift         # @Published state, business logic
    ├── Views/
    │   ├── ContentView.swift           # Root view, owns @StateObject ViewModel
    │   ├── MainView.swift              # Primary screen, state-switched layout
    │   ├── ResultsView.swift           # Prediction cards + confidence bars
    │   └── ImagePickerView.swift       # UIKit camera bridge
    └── README.md                       # This file

---

## MVVM at a Glance

    VIEW (ContentView / MainView / ResultsView)
      Reads @Published state. Calls ViewModel methods. Zero logic.
         |
         | @EnvironmentObject / @StateObject
         v
    VIEW MODEL (FoodViewModel)
      Owns state. Orchestrates async classification.
      @Published properties trigger View re-renders.
         |
         | Protocol (Classifiable)
         v
    MODEL (FoodClassification + FoodClassifierService + MockFoodClassifier)
      Plain data and CoreML integration. No UI knowledge.

---

## Getting Started

### Step 1 — Run the Demo (No Model Required)
The app ships with MockFoodClassifier as the default. Run it immediately
to see the full UI with simulated predictions.

### Step 2 — Add the Real CoreML Model
1. Download MobileNetV2.mlmodel from:
   https://developer.apple.com/machine-learning/models/

2. Drag MobileNetV2.mlmodel into your Xcode project navigator.
   Check: "Add to target: ISeeFoodApp"

3. In FoodViewModel.swift, change the initializer default:

   BEFORE (mock):
   init(classifier: Classifiable = MockFoodClassifier())

   AFTER (real CoreML):
   init(classifier: Classifiable = FoodClassifierService())

4. Build and run. Real predictions from your device's Neural Engine!

### Step 3 — Info.plist Privacy Keys
Add these keys to your Info.plist (or via Xcode target > Info tab):

   NSCameraUsageDescription
   "ISeefood needs the camera to analyze your food."

   NSPhotoLibraryUsageDescription
   "ISeefood needs photo access to analyze images."

Without these, the app will crash when accessing camera/photos.

---

## Key Concepts Taught

CoreML
  Apple's on-device ML framework. Models run entirely on the device — no network
  call, no privacy concern. The Neural Engine on modern iPhones runs billions of
  operations per second.

Vision Framework
  High-level computer vision built on CoreML. Handles image resizing, pixel format
  conversion, and orientation correction automatically. Always use Vision to feed
  images to CoreML rather than calling CoreML directly.

@MainActor
  A Swift concurrency annotation that pins a class to the main thread.
  SwiftUI requires @Published updates on the main thread — @MainActor makes
  this automatic and enforced by the compiler.

Async/Await + Task
  Swift's structured concurrency model. Task.detached moves expensive CoreML
  work off the main thread to keep the UI responsive. await MainActor.run {}
  jumps back to the main thread to update UI.

Protocol + Dependency Injection
  FoodClassifierService and MockFoodClassifier both conform to Classifiable.
  The ViewModel depends on Classifiable, not a concrete type. This lets you
  swap implementations (real vs. mock) with a single line change.

---

## Discussion Questions

1. Why do we run CoreML inference on a background thread?
2. What would happen if we called classify() directly on the main thread?
3. Why does ClassificationState use an enum instead of multiple Bool properties?
4. What is the Coordinator in ImagePickerView.swift responsible for?
5. How would you add a History feature to store past predictions using Firestore?

---

## Extension Ideas

- Firestore Logging — Save each classification result to Cloud Firestore with timestamp
- Share Sheet — Use ShareLink to share the image + result
- Custom Model — Train your own food classifier with Create ML
- Batch Classification — Classify multiple photos from the library at once
- Confidence Threshold — Only show results above 70% confidence

---

ISeefood — "See food? I see food."
Built for Flagler College iOS Development
