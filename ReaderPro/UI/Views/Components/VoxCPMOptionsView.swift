import SwiftUI

/// Opciones de generación para VoxCPM2 (máxima calidad, 48 kHz).
/// VoxCPM2 no tiene voces preset ni tags de emoción: el estilo se controla con
/// instrucciones en texto libre, y la voz con clonación (audio de referencia).
struct VoxCPMOptionsView: View {

    @Binding var styleInstruct: String
    @Binding var cfgValue: Double
    @Binding var qualitySteps: Double
    @Binding var targetAccent: CloneTargetAccent?
    @Binding var continuationMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("VoxCPM2 Options", systemImage: "dial.high")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            // Acento objetivo (presets — se combinan con las instrucciones de estilo)
            VStack(alignment: .leading, spacing: 4) {
                Text("Target accent")
                    .font(.caption)
                    .foregroundColor(.appTextSecondary)

                Picker("Accent", selection: $targetAccent) {
                    Text("Automatic").tag(nil as CloneTargetAccent?)
                    ForEach(CloneTargetAccent.allCases) { accent in
                        Text("\(accent.flag) \(accent.displayName)").tag(accent as CloneTargetAccent?)
                    }
                }
                .labelsHidden()
            }

            // Instrucciones de estilo en texto libre
            VStack(alignment: .leading, spacing: 4) {
                Text("Style instructions (optional)")
                    .font(.caption)
                    .foregroundColor(.appTextSecondary)

                TextField("E.g.: Habla pausadamente, con tono calmado", text: $styleInstruct)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)

                Text("Try \"Habla más despacio\" if the voice sounds rushed.")
                    .font(.caption2)
                    .foregroundColor(.appTextMuted)
            }

            // Estabilidad de la voz (classifier-free guidance)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Voice stability")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Text(String(format: "%.1f", cfgValue))
                        .font(.caption)
                        .foregroundColor(.appTextMuted)
                }
                Slider(value: $cfgValue, in: 1.0...3.0, step: 0.1)
                Text("Lower = more expressive, higher = more stable and faithful")
                    .font(.caption2)
                    .foregroundColor(.appTextMuted)
            }

            // Calidad de difusión
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Audio quality (diffusion steps)")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Text("\(Int(qualitySteps))")
                        .font(.caption)
                        .foregroundColor(.appTextMuted)
                }
                Slider(value: $qualitySteps, in: 5...30, step: 1)
                Text("Higher = better quality, slower generation (default 10)")
                    .font(.caption2)
                    .foregroundColor(.appTextMuted)
            }

            // Modo continuación (opción extra): herencia máxima del acento de la referencia
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Continuation mode (strongest accent fidelity)", isOn: $continuationMode)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Text("The model literally continues your reference audio, inheriting its accent and prosody. Requires voice cloning with a transcribed reference.")
                    .font(.caption2)
                    .foregroundColor(.appTextMuted)
                    .padding(.leading, 20)
            }

            Text("Speed does not affect VoxCPM2 generation — adjust playback speed in the player.")
                .font(.caption2)
                .foregroundColor(.appTextMuted)
        }
    }
}
