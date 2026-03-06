import SwiftUI

/// Selector de acento/VoiceDesign para Qwen3-TTS
/// Permite seleccionar un acento nativo para idiomas sin voz CustomVoice nativa
/// (ej: espa\u{00f1}ol, franc\u{00e9}s, alem\u{00e1}n, etc.)
/// Solo visible cuando el provider es Qwen3.
struct AccentSelectorView: View {

    // MARK: - Properties

    @Binding var selectedAccent: String
    @Binding var selectedGender: String
    @Binding var customDescription: String

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accent / Voice Design", systemImage: "globe")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            // Accent chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // "No accent" chip (CustomVoice mode)
                    AccentChip(
                        label: "No accent",
                        flag: nil,
                        isSelected: selectedAccent.isEmpty,
                        onTap: {
                            selectedAccent = ""
                            customDescription = ""
                        }
                    )

                    ForEach(VoiceAccent.allCases, id: \.rawValue) { accent in
                        AccentChip(
                            label: accent.displayName,
                            flag: accent.flag,
                            isSelected: selectedAccent == accent.rawValue,
                            onTap: {
                                selectedAccent = accent.rawValue
                                customDescription = ""
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            // Gender selector (only when accent is selected)
            if !selectedAccent.isEmpty {
                HStack(spacing: 12) {
                    Text("Gender:")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)

                    ForEach(VoiceGender.allCases, id: \.rawValue) { gender in
                        Button {
                            selectedGender = gender.rawValue
                        } label: {
                            Text(gender.displayName)
                                .font(.caption)
                                .fontWeight(selectedGender == gender.rawValue ? .semibold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedGender == gender.rawValue
                                              ? Color.appAccent
                                              : Color.appSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedGender == gender.rawValue
                                                ? Color.appHighlight
                                                : Color.appTertiary, lineWidth: 1)
                                )
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Custom voice description (overrides preset)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom voice description (overrides preset):")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)

                    TextField(
                        "e.g., A cheerful young female voice with Parisian accent...",
                        text: $customDescription
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                }

                // Mode indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "4caf50"))
                    .frame(width: 8, height: 8)

                Text("Mode: VoiceDesign")
                    .font(.caption2)
                    .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
}

// MARK: - Accent Chip

private struct AccentChip: View {
    let label: String
    let flag: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let flag = flag {
                    Text(flag)
                        .font(.caption)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            }
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

#Preview("Accent Selector") {
    struct PreviewWrapper: View {
        @State var accent = ""
        @State var gender = "female"
        @State var custom = ""

        var body: some View {
            AccentSelectorView(
                selectedAccent: $accent,
                selectedGender: $gender,
                customDescription: $custom
            )
            .padding()
            .frame(width: 500)
        }
    }
    return PreviewWrapper()
}
