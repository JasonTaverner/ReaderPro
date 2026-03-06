import SwiftUI
import UniformTypeIdentifiers

/// Modal for importing and splitting text into multiple entries
struct ImportTextSheet: View {

    // MARK: - Properties

    @Binding var isPresented: Bool
    let onImport: (String, TextSplitMode, Bool) -> Void

    @State private var inputText: String = ""
    @State private var selectedMode: TextSplitMode = .paragraph
    @State private var wordCount: Int = 50
    @State private var generateAudio: Bool = false
    @State private var previewFragments: [String] = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            Divider()

            // Input section
            inputSection

            // Split mode selector
            splitModeSection

            // Audio generation toggle
            generateAudioSection

            // Preview section
            previewSection

            Spacer()

            // Actions
            actionsSection
        }
        .padding(24)
        .frame(width: 600, height: 750)
        .onChange(of: inputText) { _, _ in updatePreview() }
        .onChange(of: selectedMode) { _, _ in updatePreview() }
        .onChange(of: wordCount) { _, _ in updatePreview() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Text")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Paste text or import from a file to create multiple entries")
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
    }

    private var generateAudioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $generateAudio) {
                HStack {
                    Label("Generate Audio Automatically", systemImage: "waveform")
                        .font(.headline)
                    Spacer()
                }
            }
            .toggleStyle(.switch)

            if generateAudio {
                Text("Audio will be generated for each fragment using current voice settings. This may take longer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Text Content", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                Button {
                    importFromFile()
                } label: {
                    Label("Import .txt", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            TextEditor(text: $inputText)
                .font(.body)
                .frame(height: 180)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Text("\(inputText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(wordCount(inputText)) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var splitModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Split Mode", systemImage: "scissors")
                .font(.headline)

            HStack(spacing: 12) {
                splitModeButton(.paragraph, title: "By Paragraphs", icon: "text.alignleft")
                splitModeButton(.sentence, title: "By Sentences", icon: "text.quote")
                splitModeButton(.words(count: wordCount), title: "By Words", icon: "textformat.123")
            }

            // Word count slider (only visible when words mode is selected)
            if case .words = selectedMode {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Words per fragment:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(wordCount) words")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: Binding(
                        get: { Double(wordCount) },
                        set: { wordCount = Int($0) }
                    ), in: 10...200, step: 10)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Preview", systemImage: "eye")
                    .font(.headline)

                Spacer()

                Text("\(previewFragments.count) fragments")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if previewFragments.isEmpty {
                        Text("Enter text to see preview")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(Array(previewFragments.enumerated()), id: \.offset) { index, fragment in
                            previewFragmentRow(index: index, text: fragment)
                        }
                    }
                }
            }
            .frame(height: 120)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var actionsSection: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Text("\(previewFragments.count) entries will be created")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                onImport(inputText, selectedMode, generateAudio)
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(previewFragments.isEmpty)
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func splitModeButton(_ mode: TextSplitMode, title: String, icon: String) -> some View {
        let isSelected = isModeSelected(mode)

        Button {
            selectedMode = mode
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func previewFragmentRow(index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .cornerRadius(12)

            Text(text.prefix(150) + (text.count > 150 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
    }

    // MARK: - Private Methods

    private func isModeSelected(_ mode: TextSplitMode) -> Bool {
        switch (selectedMode, mode) {
        case (.paragraph, .paragraph):
            return true
        case (.sentence, .sentence):
            return true
        case (.words, .words):
            return true
        default:
            return false
        }
    }

    private func updatePreview() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            previewFragments = []
            return
        }

        previewFragments = ProcessTextBatchUseCase.previewSplit(text: trimmed, mode: selectedMode)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(separator: " ", omittingEmptySubsequences: true).count
    }

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.plainText, UTType.text]
        panel.message = "Select a text file to import"
        panel.prompt = "Import"

        let result = panel.runModal()
        guard result == .OK, let url = panel.url else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            inputText = content
        } catch {
            print("[ImportTextSheet] Failed to read file: \(error)")
        }
    }

    private func pasteFromClipboard() {
        if let content = NSPasteboard.general.string(forType: .string) {
            inputText = content
        }
    }
}

// MARK: - Preview

#Preview {
    ImportTextSheet(
        isPresented: .constant(true),
        onImport: { text, mode, generateAudio in
            print("Importing \(text.prefix(50))... with mode \(mode), generateAudio: \(generateAudio)")
        }
    )
}
