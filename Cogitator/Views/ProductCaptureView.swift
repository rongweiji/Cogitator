//
//  ProductCaptureView.swift
//  Cogitator
//

import SwiftUI
import SwiftData
import AppKit

struct ProductCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = CaptureViewModel(autoClearsRecords: false)
    @State private var hasTriggeredKeyCheck = false

    var body: some View {
        let hasPrediction = viewModel.llmPrediction != nil

        VStack(alignment: .leading, spacing: 32) {
            controlPanel
            predictionPanel
                .onTapGesture(count: 2) {
                    viewModel.requestPredictionFromRecentContext()
                }
        }
        .padding(16)
        .frame(
            minWidth: 520,
            maxWidth: 600,
            minHeight: hasPrediction ? 420 : 220,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 0)
        .navigationTitle("Product Mode")
        .onAppear {
            viewModel.configure(with: modelContext)
            if !hasTriggeredKeyCheck {
                hasTriggeredKeyCheck = true
                Task { await runKeySanityCheck() }
            }
            GlobalDoubleClickMonitor.shared.start { [weak viewModel] in
                guard let viewModel else { return }
                print("[Predictor] Global double-click detected.")
                viewModel.requestPredictionFromRecentContext()
            }
        }
        .onDisappear {
            GlobalDoubleClickMonitor.shared.stop()
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

    private var controlPanel: some View {
        HStack(alignment: .center, spacing: 20) {
            Spacer()

            RecordingButton(isRecording: viewModel.isRecording, action: toggleRecording)
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
                ZStack(alignment: .topTrailing) {
                    ScrollView {
                        Text(prediction)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)

                    Button {
                        copyPrediction(prediction)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .symbolVariant(.fill)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy prediction to clipboard")
                    .padding(8)
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

private func copyPrediction(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

private final class GlobalDoubleClickMonitor {
    static let shared = GlobalDoubleClickMonitor()
    private var monitor: Any?
    private var handler: (() -> Void)?

    func start(handler: @escaping () -> Void) {
        stop()
        self.handler = handler
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard event.clickCount == 2 else { return }
            self?.handler?()
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        handler = nil
    }
}
}

private struct RecordingButton: View {
    let isRecording: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(isRecording ? Color.red : Color.accentColor)
                .padding(12)
                .background(
                    Circle()
                        .fill((isRecording ? Color.red : Color.accentColor).opacity(hovering ? 0.25 : 0.10))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var label: some View {
        Image(systemName: isRecording ? "stop" : "play")
    }
}

#Preview {
    NavigationStack {
        ProductCaptureView()
            .modelContainer(for: CaptureRecord.self, inMemory: true)
    }
}
