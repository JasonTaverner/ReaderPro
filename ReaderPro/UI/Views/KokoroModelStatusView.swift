import SwiftUI

/// Estado de la descarga automática de los modelos de voz de Kokoro.
/// Se muestra en Ajustes mientras los modelos se descargan al primer arranque.
struct KokoroModelStatusView: View {
    @ObservedObject private var store = KokoroModelStore.shared

    var body: some View {
        switch store.state {
        case .checking:
            EmptyView()

        case .installed:
            Label("Kokoro voice model installed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)

        case .downloading(let progress):
            ProgressView(value: progress) {
                Text("Downloading Kokoro voice model… \(Int(progress * 100))% (~350 MB, one time only)")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Voice model download failed: \(message)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Button("Retry download") {
                    store.retry()
                }
                .font(.caption)
            }
        }
    }
}
