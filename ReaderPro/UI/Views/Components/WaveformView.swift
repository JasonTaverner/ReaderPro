import SwiftUI

/// Componente para visualizar waveform de audio
/// Usa dos capas: barras estáticas (solo se redibujan si cambian los samples)
/// y una capa de progreso ligera que se actualiza con el timer.
struct WaveformView: View {

    // MARK: - Properties

    let samples: [Float]
    let progress: Double
    let onSeek: (Double) -> Void

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Layer 1: Static waveform bars (only redraws when samples change)
                Canvas { context, size in
                    drawBars(context: context, size: size)
                }

                // Layer 2: Colored overlay clipped to progress (lightweight)
                Canvas { context, size in
                    drawPlayedOverlay(context: context, size: size)
                }

                // Layer 3: Progress line
                Rectangle()
                    .fill(Color.appHighlight)
                    .frame(width: 2)
                    .offset(x: geometry.size.width * progress)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = value.location.x / geometry.size.width
                        onSeek(min(max(progress, 0), 1))
                    }
            )
            .drawingGroup()
        }
        .frame(height: 80)
    }

    // MARK: - Drawing

    private func drawBars(context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty else { return }

        let width = size.width
        let height = size.height
        let midY = height / 2
        let barWidth = width / CGFloat(samples.count)

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * height * 0.8

            let rect = CGRect(
                x: x,
                y: midY - barHeight / 2,
                width: max(barWidth - 1, 1),
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: 1)
            context.fill(path, with: .color(Color.appTertiary.opacity(0.4)))
        }
    }

    private func drawPlayedOverlay(context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty, progress > 0 else { return }

        let width = size.width
        let height = size.height
        let midY = height / 2
        let barWidth = width / CGFloat(samples.count)
        let playedBars = Int(Double(samples.count) * progress)

        for index in 0..<playedBars {
            let sample = samples[index]
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * height * 0.8

            let rect = CGRect(
                x: x,
                y: midY - barHeight / 2,
                width: max(barWidth - 1, 1),
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: 1)
            context.fill(path, with: .color(Color.appHighlight))
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    WaveformView(
        samples: [],
        progress: 0,
        onSeek: { _ in }
    )
    .padding()
}

#Preview("With Progress") {
    WaveformView(
        samples: generateRandomSamples(count: 100),
        progress: 0.4,
        onSeek: { _ in }
    )
    .padding()
}

#Preview("At End") {
    WaveformView(
        samples: generateRandomSamples(count: 100),
        progress: 1.0,
        onSeek: { _ in }
    )
    .padding()
}

// MARK: - Preview Helpers

private func generateRandomSamples(count: Int) -> [Float] {
    (0..<count).map { _ in Float.random(in: 0.1...1.0) }
}
