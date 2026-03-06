import SwiftUI

/// Componente para controles de reproducción
/// Play/Pause, Skip Backward/Forward
struct PlaybackControlsView: View {

    // MARK: - Properties

    let isPlaying: Bool
    let currentTime: String
    let duration: String
    let onPlayPause: () -> Void
    let onBackward: () -> Void
    let onForward: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 20) {
            // Tiempo actual
            Text(currentTime)
                .monospacedDigit()
                .foregroundColor(Color.appTextSecondary)
                .frame(width: 50, alignment: .trailing)

            // Controles
            HStack(spacing: 24) {
                // Skip Backward
                Button(action: onBackward) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 20))
                        .foregroundColor(Color.appTextPrimary)
                }
                .buttonStyle(.plain)
                .help("Skip backward 10 seconds")

                // Play/Pause
                Button(action: onPlayPause) {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 48))
                        .foregroundColor(Color.appHighlight)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "Pause" : "Play")

                // Skip Forward
                Button(action: onForward) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 20))
                        .foregroundColor(Color.appTextPrimary)
                }
                .buttonStyle(.plain)
                .help("Skip forward 10 seconds")
            }

            // Duración total
            Text(duration)
                .monospacedDigit()
                .foregroundColor(Color.appTextSecondary)
                .frame(width: 50, alignment: .leading)
        }
    }

    // MARK: - Computed Properties

    private var playPauseIcon: String {
        isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }
}

// MARK: - Preview

#Preview("Playing") {
    PlaybackControlsView(
        isPlaying: true,
        currentTime: "1:23",
        duration: "3:45",
        onPlayPause: {},
        onBackward: {},
        onForward: {}
    )
    .padding()
}

#Preview("Paused") {
    PlaybackControlsView(
        isPlaying: false,
        currentTime: "0:30",
        duration: "2:15",
        onPlayPause: {},
        onBackward: {},
        onForward: {}
    )
    .padding()
}

#Preview("At Start") {
    PlaybackControlsView(
        isPlaying: false,
        currentTime: "0:00",
        duration: "5:00",
        onPlayPause: {},
        onBackward: {},
        onForward: {}
    )
    .padding()
}
