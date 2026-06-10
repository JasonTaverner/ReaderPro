import SwiftUI

/// Opciones de generación para Chatterbox Multilingual (500M, MIT, ~tiempo real).
/// La voz por defecto del modelo es floja: el flujo recomendado es la clonación
/// con un perfil guardado (el acento se hereda de la referencia).
struct ChatterboxOptionsView: View {

    @Binding var language: String
    @Binding var exaggeration: Double
    @Binding var cfgWeight: Double

    private static let languages: [(code: String, name: String)] = [
        ("es", "🇪🇸 Español"),
        ("en", "🇬🇧 English"),
        ("fr", "🇫🇷 Français"),
        ("de", "🇩🇪 Deutsch"),
        ("it", "🇮🇹 Italiano"),
        ("pt", "🇵🇹 Português"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Chatterbox Options", systemImage: "hare")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            // Idioma de síntesis
            VStack(alignment: .leading, spacing: 4) {
                Text("Language")
                    .font(.caption)
                    .foregroundColor(.appTextSecondary)

                Picker("Language", selection: $language) {
                    ForEach(Self.languages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .labelsHidden()
            }

            // Expresividad
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Expressiveness")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Text(String(format: "%.2f", exaggeration))
                        .font(.caption)
                        .foregroundColor(.appTextMuted)
                }
                Slider(value: $exaggeration, in: 0.0...1.0, step: 0.05)
                Text("Higher = more dramatic delivery (default 0.10)")
                    .font(.caption2)
                    .foregroundColor(.appTextMuted)
            }

            // Fidelidad al texto (cfg)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Pacing (CFG weight)")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Text(String(format: "%.2f", cfgWeight))
                        .font(.caption)
                        .foregroundColor(.appTextMuted)
                }
                Slider(value: $cfgWeight, in: 0.0...1.0, step: 0.05)
                Text("Lower = slower, more deliberate speech (default 0.50)")
                    .font(.caption2)
                    .foregroundColor(.appTextMuted)
            }

            Text("Tip: enable Voice Cloning with one of your saved profiles — the default voice is weak, and the accent is inherited from your reference.")
                .font(.caption2)
                .foregroundColor(.appTextMuted)
        }
    }
}
