import SwiftUI

/// Componente de toolbar que muestra el estado del servidor TTS activo
/// y permite cambiar entre proveedores (Kokoro, Qwen3)
struct ServerStatusView: View {

    @ObservedObject var coordinator: TTSServerCoordinator

    var body: some View {
        Menu {
            // Provider selection
            Section("TTS Provider") {
                ForEach([Voice.TTSProvider.native, .kokoro, .qwen3], id: \.self) { provider in
                    Button {
                        Task {
                            await coordinator.switchProvider(to: provider)
                        }
                    } label: {
                        HStack {
                            Text(provider.displayName)
                            if coordinator.activeProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // Kokoro mode selection (local ONNX vs remote server)
            if coordinator.activeProvider == .kokoro && coordinator.isLocalONNXAvailable {
                Divider()

                Section("Kokoro Mode") {
                    ForEach(TTSServerCoordinator.KokoroMode.allCases, id: \.self) { mode in
                        Button {
                            Task {
                                await coordinator.switchKokoroMode(to: mode)
                            }
                        } label: {
                            HStack {
                                Text(mode.displayName)
                                if coordinator.kokoroMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Actions
            if coordinator.activeStatus.isRetryable {
                Button {
                    Task {
                        await coordinator.retryConnection()
                    }
                } label: {
                    Label("Retry Connection", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            HStack(spacing: 6) {
                statusCircle
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(tooltipText)
    }

    // MARK: - Status Circle

    @ViewBuilder
    private var statusCircle: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay {
                if coordinator.activeStatus == .starting {
                    Circle()
                        .fill(statusColor.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.8 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                        .onAppear { pulseAnimation = true }
                        .onDisappear { pulseAnimation = false }
                }
            }
    }

    @State private var pulseAnimation = false

    // MARK: - Computed Properties

    private var providerName: String {
        coordinator.activeProvider.displayName
    }

    private var statusColor: Color {
        switch coordinator.activeStatus {
        case .unknown:
            return Color.appTextMuted
        case .starting:
            return Color.appHighlight
        case .connected:
            return Color(hex: "4caf50")
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch coordinator.activeStatus {
        case .unknown:
            return "\(providerName): Unknown"
        case .starting:
            return "\(providerName): Starting..."
        case .connected:
            return "\(providerName): Connected"
        case .disconnected:
            return "\(providerName): Disconnected"
        case .error:
            return "\(providerName): Error"
        }
    }

    private var tooltipText: String {
        switch coordinator.activeStatus {
        case .unknown:
            return "Checking \(providerName) server status..."
        case .starting:
            return "Starting \(providerName) server..."
        case .connected:
            if coordinator.activeProvider == .native {
                return "Using macOS system voices. No server required."
            } else if coordinator.activeProvider == .kokoro {
                return "\(providerName) server is running on localhost:8880"
            } else {
                return "\(providerName) MLX server on localhost:8890"
            }
        case .disconnected:
            return "\(providerName) server is not responding. Click to change provider or retry."
        case .error(let message):
            return "Error: \(message). Click to change provider or retry."
        }
    }
}
