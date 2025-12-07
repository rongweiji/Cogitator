//
//  EntryView.swift
//  Cogitator
//

import SwiftUI
import SwiftData

struct EntryView: View {
    private enum Route: Hashable {
        case product
        case dev
    }

    @State private var path: [Route] = []
    @State private var apiKey: String = ""
    @State private var hasKey: Bool = KeychainService().hasKey()
    @State private var keychainError: String?
    @State private var keyCheckStatus: String?
    @State private var isCheckingKey = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.person.crop")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Cogitator")
                        .font(.largeTitle.bold())
                    Text("Choose a mode to control the OCR ingestion pipeline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    modeButton(
                        title: "Product Experience",
                        subtitle: "Minimal interface for operators. Single start/stop control.",
                        icon: "sparkles",
                        action: { path.append(.product) }
                    )

                    modeButton(
                        title: "Dev / Test Console",
                        subtitle: "Full controls with FPS tuning, dumps, and clearing utilities.",
                        icon: "hammer",
                        action: { path.append(.dev) }
                    )
                }
                .frame(maxWidth: 460)

                keySection

                Spacer()
            }
            .padding()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .product:
                    ProductCaptureView()
                case .dev:
                    DevCaptureView()
                }
            }
        }
        .onAppear {
            hasKey = KeychainService().hasKey()
            if hasKey {
                runKeyCheck()
            }
        }
    }

    private func modeButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(hasKey ? "XAI Key Stored" : "No XAI Key", systemImage: hasKey ? "checkmark.seal.fill" : "key.slash")
                    .foregroundStyle(hasKey ? Color.green : Color.orange)
                    .font(.subheadline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter XAI API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .font(.body.monospaced())

                if let keychainError {
                    Text(keychainError)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                } else if let keyCheckStatus {
                    Text(keyCheckStatus)
                        .font(.caption)
                        .foregroundStyle(hasKeyStatusColor)
                }
            }

            HStack(spacing: 16) {
                Button(isCheckingKey ? "Checking..." : "Save Key") {
                    saveKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingKey)

                Button("Clear Key", role: .destructive) {
                    clearKey()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
        }
    }

    private func saveKey() {
        keychainError = nil
        let service = KeychainService()
        do {
            try service.save(key: apiKey)
            hasKey = true
            apiKey = ""
            runKeyCheck()
        } catch {
            keychainError = error.localizedDescription
            keyCheckStatus = nil
        }
    }

    private func clearKey() {
        keychainError = nil
        let service = KeychainService()
        do {
            try service.deleteKey()
            hasKey = false
            keyCheckStatus = "Key removed."
        } catch {
            keychainError = error.localizedDescription
        }
    }

    private var hasKeyStatusColor: Color {
        if let keychainError {
            return Color.red
        }
        return hasKey ? Color.green : Color.orange
    }

    private func runKeyCheck() {
        keyCheckStatus = "Validating key…"
        isCheckingKey = true
        Task {
            let service = XAIService()
            let result = await service.sanityCheck()
            await MainActor.run {
                isCheckingKey = false
                switch result {
                case .success(let response):
                    if response.uppercased().contains("ACK") {
                        keyCheckStatus = "Key validated (ACK received)."
                    } else {
                        keyCheckStatus = "Unexpected response: \(response.prefix(80))"
                    }
                case .failure(let error):
                    keyCheckStatus = "Validation failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    EntryView()
        .modelContainer(for: CaptureRecord.self, inMemory: true)
}
