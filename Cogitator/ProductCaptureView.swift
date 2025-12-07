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
