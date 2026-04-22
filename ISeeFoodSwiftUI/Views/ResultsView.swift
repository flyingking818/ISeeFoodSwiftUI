// ResultsView.swift
// ISeeFoodApp
//
// MARK: - Results View
//
// Displays the model's predictions after classification is complete.
// This is where the "ISeefood" joke lands — Silicon Valley fans will recognize it.
//
// Key SwiftUI concepts:
//
//   ForEach
//     Iterates over a collection and produces a View for each item.
//     Requires items to be Identifiable (our FoodClassification has an `id`).
//
//   GeometryReader
//     Reads the size of the parent container at layout time. We use it to
//     draw the confidence bars at the correct proportional width.
//
//   Animation with .onAppear
//     Confidence bars animate in when the view appears. We use @State to
//     drive the animation from 0% to the actual confidence value.

import SwiftUI

struct ResultsView: View {

    let classifications: [FoodClassification]

    // We use @EnvironmentObject to grab the ViewModel's computed helpers.
    @EnvironmentObject private var viewModel: FoodViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: Hero Result Card — The "ISeefood" reveal
            HeroResultCard(isFood: viewModel.topResultIsFood,
                           label: viewModel.topLabel ?? "Unknown",
                           confidence: viewModel.topConfidence ?? "")

            // MARK: Top Predictions List
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Predictions")
                    .font(.headline)
                    .padding(.horizontal)

                // ForEach iterates our array of classifications.
                // Because FoodClassification is Identifiable, we don't need
                // to use \.self or a key path — SwiftUI uses `id` automatically.
                ForEach(classifications) { classification in
                    PredictionRow(classification: classification)
                }
            }
            .padding(.vertical)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - HeroResultCard

/// The big "IS IT FOOD?" reveal card at the top of results.
private struct HeroResultCard: View {

    let isFood: Bool
    let label: String
    let confidence: String

    // Drives the entrance animation
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            // Emoji reacts to the prediction
            Text(isFood ? "🍕" : "🙅")
                .font(.system(size: 64))
                .scaleEffect(appeared ? 1.0 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appeared)

            // The ISeefood catchphrase
            Group {
                if isFood {
                    Text("I see **\(label)**!")
                        .font(.title)
                } else {
                    Text("That's not food!")
                        .font(.title)
                }
            }

            Text("\(confidence) confidence")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            // Green for food, gray for not-food
            isFood ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - PredictionRow

/// A single row showing one prediction with an animated confidence bar.
private struct PredictionRow: View {

    let classification: FoodClassification

    // @State drives the bar's animated width (starts at 0, animates to confidence)
    @State private var barProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Label + confidence percentage
            HStack {
                Text(classification.label.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(classification.confidencePercent)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()  // Keeps numbers from jumping as they change
            }

            // Confidence bar
            // GeometryReader gives us the available width at runtime.
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 8)

                    // Filled portion — width = (containerWidth × confidence)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * barProgress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        // Animate the bar when the row appears
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                barProgress = classification.confidence
            }
        }
    }

    /// Bar color reflects confidence level (green → yellow → red)
    private var barColor: Color {
        switch classification.confidence {
        case 0.7...:   return .green
        case 0.4..<0.7: return .yellow
        default:        return .red
        }
    }
}

#Preview {
    let mockResults = [
        FoodClassification(label: "pizza", confidence: 0.923),
        FoodClassification(label: "flatbread", confidence: 0.041),
        FoodClassification(label: "focaccia", confidence: 0.021),
        FoodClassification(label: "calzone", confidence: 0.010),
        FoodClassification(label: "pasta", confidence: 0.005)
    ]

    return ResultsView(classifications: mockResults)
        .environmentObject(FoodViewModel())
        .padding()
}
