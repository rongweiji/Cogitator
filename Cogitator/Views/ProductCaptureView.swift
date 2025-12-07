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
    @State private var hasTriggeredKeyCheck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            controlPanel
            predictionPanel
        }
        .padding(32)
        .frame(minWidth: 640, maxWidth: 720, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundStyle)
        .navigationTitle("Product Mode")
        .onAppear {
            viewModel.configure(with: modelContext)
            if !hasTriggeredKeyCheck {
                hasTriggeredKeyCheck = true
                Task { await runKeySanityCheck() }
            }
        }
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

    private var labelForRecordingState: some View {
        Group {
            if viewModel.isRecording {
                Image(systemName: "stop.fill")
                    .font(.system(size: 36, weight: .bold))
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 36, weight: .bold))
            }
        }
    }

    private var buttonBackgroundColor: Color {
        viewModel.isRecording ? .red : .accentColor
    }

    private var controlPanel: some View {
        HStack(alignment: .center, spacing: 20) {
            Spacer()

            Button(action: toggleRecording) {
                labelForRecordingState
                    .frame(width: 64, height: 64)
                    .background(buttonBackgroundColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .help(viewModel.isRecording ? "Press to stop Cogitator." : "Press to start Cogitator.")
        }
    }

    private var predictionPanel: some View {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runKeySanityCheck() async {
        let keychain = KeychainService()
        guard keychain.hasKey() else {
            print("[XAI] No API key saved; skipping sanity check.")
            return
        }
        print("[XAI] Validating stored API key…")
        let service = XAIService()
        let result = await service.sanityCheck()
        switch result {
        case .success(let response):
            if response.uppercased().contains("ACK") {
                print("[XAI] API key validated (ACK).")
            } else {
                print("[XAI] Unexpected sanity-check response: \(response)")
            }
        case .failure(let error):
            print("[XAI] Sanity check failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        ProductCaptureView()
            .modelContainer(for: CaptureRecord.self, inMemory: true)
    }
}
