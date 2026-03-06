import SwiftUI

/// Componente reutilizable para seleccionar voz de TTS
struct VoiceSelectorView: View {

    // MARK: - Properties

    let voices: [VoiceDTO]
    let selectedId: String?
    let onSelect: (String) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Voice", systemImage: "person.wave.2")
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

            Picker("Voice", selection: selectionBinding) {
                // Provide a hidden tag for the current selection during
                // provider transitions to avoid "not a valid tag" warnings.
                if let selected = selectedId,
                   !voices.contains(where: { $0.id == selected }) {
                    Text("").tag(Optional(selected))
                }
                ForEach(voices) { voice in
                    Text(voice.displayName)
                        .tag(Optional(voice.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            // Metadata de la voz seleccionada
            if let selectedVoice = voices.first(where: { $0.id == selectedId }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider: \(selectedVoice.provider)")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)

                    Text("Language: \(selectedVoice.language)")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Bindings

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { selectedId },
            set: { if let id = $0 { onSelect(id) } }
        )
    }
}

// MARK: - Preview

#Preview("With Voices") {
    VoiceSelectorView(
        voices: [
            VoiceDTO(id: "v1", name: "American Female", language: "en-US", provider: "Kokoro", isDefault: true),
            VoiceDTO(id: "v2", name: "British Male", language: "en-GB", provider: "Kokoro", isDefault: false),
            VoiceDTO(id: "v3", name: "American Male", language: "en-US", provider: "Native", isDefault: false),
        ],
        selectedId: "v1",
        onSelect: { print("Selected: \($0)") }
    )
    .padding()
    .frame(width: 300)
}

#Preview("Empty") {
    VoiceSelectorView(
        voices: [],
        selectedId: nil,
        onSelect: { print("Selected: \($0)") }
    )
    .padding()
    .frame(width: 300)
}
