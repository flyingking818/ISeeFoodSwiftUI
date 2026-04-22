// MainView.swift
// ISeeFoodApp
//
// MARK: - Main View (Root of the app)
//
// MainView owns the ViewModel and is the single root view of the app.
// It wraps everything in a NavigationStack and injects the ViewModel
// into the SwiftUI environment so all child views can access it.
//
// Key SwiftUI concepts:
//
//   @StateObject
//     Creates and owns the ViewModel for the lifetime of this view.
//     SwiftUI will NOT recreate it on re-renders — only when the view
//     itself is removed from the hierarchy.
//
//   .environmentObject()
//     Injects the ViewModel into the environment so any descendant view
//     can access it with @EnvironmentObject — no need to pass it through
//     every intermediate view manually.
//
//   switch on an enum with associated values
//     We use `switch viewModel.state` to show different UI for each state.
//     This is a core Swift pattern — the compiler ensures we handle every case.
//     Dynamic display of screen conttent is great feature! So, think about how to use this for your app! :)

import SwiftUI
import PhotosUI

struct MainView: View {

    // @StateObject creates the ViewModel exactly once and retains it.
    // If MainView re-renders, SwiftUI does NOT recreate the ViewModel.
    @StateObject private var viewModel = FoodViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Image Display Area
                    ImageDisplayView()

                    // MARK: Action Buttons
                    ActionButtonsView()

                    // MARK: Results / Status
                    // Switch on the ViewModel's state to show the right UI.
                    // This pattern keeps MainView clean — each state gets its own view.
                    switch viewModel.state {
                    case .idle:
                        IdlePromptView()

                    case .analyzing:
                        AnalyzingView()

                    case .results(let classifications):
                        ResultsView(classifications: classifications)

                    case .error(let message):
                        ErrorView(message: message)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ISeefood 🍕")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.selectedImage != nil {
                        Button("Reset") {
                            viewModel.reset()
                        }
                    }
                }
            }
        }
        // Inject the ViewModel into the environment for all child views
        .environmentObject(viewModel)
    }
}

// MARK: - ImageDisplayView

/// Shows the selected image, or a placeholder when none is selected.
private struct ImageDisplayView: View {

    @EnvironmentObject private var viewModel: FoodViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 300)

            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                PlaceholderImageView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedImage != nil)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

/// Placeholder shown before any image is selected.
private struct PlaceholderImageView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No image selected")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Take a photo or choose one from your library")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - ActionButtonsView

/// The row of buttons: Camera, Library picker, and Analyze.
private struct ActionButtonsView: View {

    @EnvironmentObject private var viewModel: FoodViewModel

    var body: some View {
        HStack(spacing: 12) {

            Button {
                viewModel.showCamera = true
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .sheet(isPresented: $viewModel.showCamera) {
                ImagePickerView(image: $viewModel.selectedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }

            // PhotosPicker — native SwiftUI (iOS 16+), no permissions prompt needed
            PhotosPicker(
                selection: $viewModel.photoPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }

        Button {
            viewModel.analyzeImage()
        } label: {
            Label("Analyze Image", systemImage: "wand.and.stars")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(viewModel.selectedImage == nil || {
            if case .analyzing = viewModel.state { return true }
            return false
        }())
    }
}

// MARK: - IdlePromptView

private struct IdlePromptView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Ready to identify food?")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Select an image above, then tap **Analyze Image**.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - AnalyzingView

private struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)

            Text("Analyzing image...")
                .font(.headline)

            Text("Running CoreML model on-device")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - ErrorView

private struct ErrorView: View {

    let message: String
    @EnvironmentObject private var viewModel: FoodViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.state = .idle
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    MainView()
}
