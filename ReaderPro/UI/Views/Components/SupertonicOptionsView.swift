import SwiftUI

/// Opciones para Supertonic v3 (ONNX, ~4x tiempo real, 10 voces preset).
/// Sin clonación: la voz se elige en el selector de voces (M1-M5, F1-F5).
struct SupertonicOptionsView: View {

    @Binding var language: String

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
            Label("Supertonic Options", systemImage: "bolt")
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

            Text("Fastest engine (~4x real time). Pick the voice above (M1-M5, F1-F5). Expression tags like <laugh>, <breath> or <sigh> can be written inside the text. Playback speed IS applied at generation.")
                .font(.caption2)
                .foregroundColor(.appTextMuted)
        }
    }
}
