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

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.eye")
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
}

#Preview {
    EntryView()
        .modelContainer(for: CaptureRecord.self, inMemory: true)
}
