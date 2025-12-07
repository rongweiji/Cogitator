//
//  DevCaptureView.swift
//  Cogitator
//

import SwiftUI
import SwiftData

struct DevCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CaptureViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Screen OCR Ingestion (Dev)")
                    .font(.title2.bold())
                Text("Capture the built-in display, OCR each frame, and persist the text via SwiftData.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(viewModel.isRecording ? "Recording" : "Idle", systemImage: viewModel.isRecording ? "record.circle.fill" : "pause.circle")
                        .foregroundStyle(viewModel.isRecording ? Color.red : Color.secondary)
                    Spacer()
                    Text("FPS: \(viewModel.fps, specifier: "%.1f") Hz")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $viewModel.fps, in: 0.5...5, step: 0.5) {
                    Text("Capture Frequency")
                }
                .disabled(viewModel.isRecording)
            }

            HStack(spacing: 16) {
                Button {
                    viewModel.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRecording)

                Button {
                    viewModel.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isRecording)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    viewModel.dumpRecords()
                } label: {
                    Label("Dump Stored Records", systemImage: "doc.text.magnifyingglass")
                }

                Button(role: .destructive) {
                    viewModel.clearRecords()
                } label: {
                    Label("Clear Storage", systemImage: "trash")
                }
            }

            Spacer()
        }
        .padding(32)
        .navigationTitle("Dev/Test Console")
        .onAppear {
            viewModel.configure(with: modelContext)
        }
    }
}

#Preview {
    DevCaptureView()
        .modelContainer(for: CaptureRecord.self, inMemory: true)
}
