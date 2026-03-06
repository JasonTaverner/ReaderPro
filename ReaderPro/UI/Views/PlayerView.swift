import SwiftUI

/// Vista para reproducir audio de un proyecto
/// Observa el ViewModel y delega acciones al Presenter
struct PlayerView: View {

    // MARK: - Properties

    @StateObject private var presenter: PlayerPresenter
    @Environment(\.dismiss) private var dismiss

    private let projectId: Identifier<Project>

    // MARK: - Initialization

    init(presenter: PlayerPresenter, projectId: Identifier<Project>) {
        _presenter = StateObject(wrappedValue: presenter)
        self.projectId = projectId
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appPrimary.ignoresSafeArea()
            
            contentView
        }
        .navigationTitle(presenter.viewModel.projectName)
        .task {
            await presenter.onAppear(projectId: projectId)
        }
        .onDisappear {
            Task {
                await presenter.onDisappear()
            }
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") {
                presenter.viewModel.error = nil
                dismiss()
            }
        } message: {
            if let error = presenter.viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if presenter.viewModel.isLoading {
            loadingView
        } else if presenter.viewModel.hasAudio {
            playerContentView
        } else {
            emptyStateView
        }
    }

    // MARK: - Subviews

    private var playerContentView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Waveform
            waveformSection

            // Playback controls
            controlsSection

            // Speed control
            speedSection

            Spacer()
        }
        .padding()
    }

    private var waveformSection: some View {
        VStack(spacing: 12) {
            WaveformView(
                samples: presenter.viewModel.waveformSamples,
                progress: presenter.viewModel.progress,
                onSeek: { progress in
                    Task {
                        await presenter.seek(to: progress)
                    }
                }
            )
            .frame(height: 80)
            .background(Color.appSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var controlsSection: some View {
        PlaybackControlsView(
            isPlaying: presenter.viewModel.isPlaying,
            currentTime: presenter.viewModel.currentTimeFormatted,
            duration: presenter.viewModel.durationFormatted,
            onPlayPause: {
                Task {
                    await presenter.togglePlayPause()
                }
            },
            onBackward: {
                Task {
                    await presenter.skipBackward()
                }
            },
            onForward: {
                Task {
                    await presenter.skipForward()
                }
            }
        )
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Playback Speed", systemImage: "speedometer")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                Spacer()

                Text(String(format: "%.1fx", presenter.viewModel.playbackSpeed))
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
                    .monospacedDigit()
            }

            HStack {
                Text("0.5x")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)

                Slider(
                    value: speedBinding,
                    in: 0.5...2.0,
                    step: 0.1
                )

                Text("2.0x")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            // Quick speed buttons
            HStack(spacing: 8) {
                speedButton(0.75, label: "0.75×")
                speedButton(1.0, label: "1×")
                speedButton(1.25, label: "1.25×")
                speedButton(1.5, label: "1.5×")
                speedButton(2.0, label: "2×")
            }
        }
        .padding()
        .background(Color.appSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    private func speedButton(_ speed: Float, label: String) -> some View {
        let isSelected = presenter.viewModel.playbackSpeed == speed
        return Button {
            Task {
                await presenter.setSpeed(speed)
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appAccent : Color.appTertiary.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading audio...")
                .font(.headline)
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 64))
                .foregroundColor(Color.appTextMuted)

            Text("No Audio")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.appTextPrimary)

            Text("This project doesn't have audio yet")
                .foregroundColor(Color.appTextSecondary)

            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bindings

    private var speedBinding: Binding<Double> {
        Binding(
            get: { Double(presenter.viewModel.playbackSpeed) },
            set: { newValue in
                Task {
                    await presenter.setSpeed(Float(newValue))
                }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.error != nil },
            set: { if !$0 { presenter.viewModel.error = nil } }
        )
    }
}

// MARK: - Preview

#Preview("With Audio") {
    PlayerView(
        presenter: DependencyContainer.shared.makePlayerPresenter(),
        projectId: Identifier<Project>()
    )
}
