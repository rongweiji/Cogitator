//
//  ProductCaptureView.swift
//  Cogitator
//

import SwiftUI
import SwiftData

struct ProductCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = CaptureViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Live OCR Ingestion")
                    .font(.title.bold())
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Button(action: toggleRecording) {
                Text(viewModel.isRecording ? "Stop Ingestion" : "Start Ingestion")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isRecording ? Color.red : Color.accentColor)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Next Input Prediction")
                    .font(.headline)
                if viewModel.isGeneratingPrediction {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Predicting next input…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let prediction = viewModel.llmPrediction {
                    Text(prediction)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Stop the capture to let the assistant guess what you plan to type next.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.llmError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let duration = viewModel.lastPredictionDuration {
                    Text("Last prediction generated in \(String(format: "%.2fs", duration)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }

            VStack(spacing: 4) {
                Text("Capture Frequency")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.fps, specifier: "%.1f") fps")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .opacity(0.7)
            .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: 420)
        .frame(maxHeight: .infinity)
        .background(backgroundStyle)
        .navigationTitle("Product Mode")
        .onAppear {
            viewModel.configure(with: modelContext)
        }
    }

    private var statusDescription: String {
        viewModel.isRecording ? "Capturing the main display and persisting OCR results." : "Ready to capture the main display when you are."
    }

    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .ignoresSafeArea()
    }

    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stop()
        } else {
            viewModel.start()
        }
    }
}

#Preview {
    NavigationStack {
        ProductCaptureView()
            .modelContainer(for: CaptureRecord.self, inMemory: true)
    }
}
