import SwiftUI

/// Vista modal para seleccionar opciones de merge/exportación
struct MergeOptionsSheet: View {

    // MARK: - Properties

    @Binding var isPresented: Bool
    let entriesCount: Int
    let hasAudioEntries: Bool
    let hasImageEntries: Bool
    let onMerge: (MergeType) -> Void

    @State private var selectedType: MergeType = .all
    @State private var silenceDuration: Double = 0.5

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Project")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(entriesCount) entries to merge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Merge Options
            VStack(alignment: .leading, spacing: 16) {
                Text("Select what to export:")
                    .font(.headline)

                // Option: Audio
                mergeOptionButton(
                    type: .audio,
                    title: "Merge Audio",
                    subtitle: "Combine all audio files with silence between them",
                    icon: "waveform",
                    enabled: hasAudioEntries
                )

                // Option: Images
                mergeOptionButton(
                    type: .images,
                    title: "Merge Images",
                    subtitle: "Create a PDF with all images (one per page)",
                    icon: "doc.richtext",
                    enabled: hasImageEntries
                )

                // Option: Text
                mergeOptionButton(
                    type: .text,
                    title: "Merge Text",
                    subtitle: "Combine all text entries into one document",
                    icon: "doc.text",
                    enabled: true
                )

                // Option: All
                mergeOptionButton(
                    type: .all,
                    title: "Merge All",
                    subtitle: "Export audio, images (PDF), and text",
                    icon: "square.and.arrow.up.on.square",
                    enabled: true
                )
            }

            // Silence Duration (only if audio selected)
            if selectedType == .audio || selectedType == .all {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Silence between audio files:")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f sec", silenceDuration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $silenceDuration, in: 0...2.0, step: 0.1)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onMerge(selectedType)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canExport)
            }
        }
        .padding(24)
        .frame(width: 450, height: 550)
    }

    // MARK: - Private Views

    @ViewBuilder
    private func mergeOptionButton(
        type: MergeType,
        title: String,
        subtitle: String,
        icon: String,
        enabled: Bool
    ) -> some View {
        Button {
            if enabled {
                selectedType = type
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundColor(enabled ? (selectedType == type ? .white : .accentColor) : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(enabled ? (selectedType == type ? .white : .primary) : .gray)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(enabled ? (selectedType == type ? .white.opacity(0.8) : .secondary) : .gray)
                }

                Spacer()

                if selectedType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }

                if !enabled {
                    Text("No entries")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedType == type && enabled ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedType == type && enabled ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Computed Properties

    private var canExport: Bool {
        switch selectedType {
        case .audio:
            return hasAudioEntries
        case .images:
            return hasImageEntries
        case .text, .all:
            return true
        }
    }
}

// MARK: - Preview

#Preview {
    MergeOptionsSheet(
        isPresented: .constant(true),
        entriesCount: 5,
        hasAudioEntries: true,
        hasImageEntries: true,
        onMerge: { type in
            print("Selected merge type: \(type)")
        }
    )
}
