import SwiftUI

/// Selector visual de emociones para Qwen3-TTS
/// Muestra chips horizontales de emociones predefinidas + campo de texto libre para instrucciones custom.
/// Solo visible cuando el provider es Qwen3.
struct EmotionSelectorView: View {

    // MARK: - Properties

    @Binding var selectedEmotion: String
    @Binding var customInstruct: String

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Emotion / Style", systemImage: "face.smiling")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            // Emotion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SpeechEmotion.allCases, id: \.rawValue) { emotion in
                        EmotionChip(
                            emotion: emotion,
                            isSelected: selectedEmotion == emotion.rawValue,
                            onTap: {
                                selectedEmotion = emotion.rawValue
                                // Clear custom instruct when selecting a preset
                                if emotion != .neutral {
                                    customInstruct = ""
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            // Custom instruct field
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom instruction (overrides preset):")
                    .font(.caption)
                    .foregroundColor(.appTextSecondary)

                TextField(
                    "e.g., Speak softly and slowly...",
                    text: $customInstruct
                )
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .onChange(of: customInstruct) { _, newValue in
                    if !newValue.isEmpty {
                        selectedEmotion = "neutral"
                    }
                }
            }
        }
    }
}

// MARK: - Emotion Chip

private struct EmotionChip: View {
    let emotion: SpeechEmotion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(emotion.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.appAccent : Color.appSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.appHighlight : Color.appTertiary, lineWidth: 1)
                )
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Emotion Selector") {
    struct PreviewWrapper: View {
        @State var emotion = "neutral"
        @State var instruct = ""

        var body: some View {
            EmotionSelectorView(
                selectedEmotion: $emotion,
                customInstruct: $instruct
            )
            .padding()
            .frame(width: 400)
        }
    }
    return PreviewWrapper()
}
