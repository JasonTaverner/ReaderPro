import SwiftUI
import UniformTypeIdentifiers

/// Panel para clonación de voz en Qwen3-TTS
/// Permite seleccionar un archivo de audio de referencia (3+ segundos)
/// para clonar la voz del hablante.
/// Solo visible cuando el provider es Qwen3.
struct VoiceCloneView: View {

    // MARK: - Properties

    @Binding var isCloneMode: Bool
    @Binding var referenceAudioURL: URL?
    @Binding var referenceText: String
    @Binding var cloneFastMode: Bool
    @Binding var cloneFastModel: Bool
    @Binding var cloneTargetAccent: CloneTargetAccent?
    var onTranscribe: (() -> Void)? = nil
    var isTranscribing: Bool = false

    // Saved profiles
    var savedProfiles: [ClonedVoiceProfileDTO] = []
    var selectedProfileId: String? = nil
    var onSelectProfile: ((String?) -> Void)? = nil
    var onSaveProfile: (() -> Void)? = nil
    var onDeleteProfile: ((String) -> Void)? = nil

    @State private var audioDuration: TimeInterval?
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Voice Cloning", systemImage: "waveform.badge.plus")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            Toggle("Enable voice cloning", isOn: $isCloneMode)
                .toggleStyle(.checkbox)

            if isCloneMode {
                VStack(alignment: .leading, spacing: 6) {

                    // Saved voices picker
                    if !savedProfiles.isEmpty, let onSelectProfile = onSelectProfile {
                        HStack {
                            Text("Saved Voice:")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)

                            Picker("", selection: Binding(
                                get: { selectedProfileId ?? "__new__" },
                                set: { onSelectProfile($0 == "__new__" ? nil : $0) }
                            )) {
                                Text("New (manual)").tag("__new__")
                                ForEach(savedProfiles) { profile in
                                    Text("\(profile.name) (\(profile.formattedDuration))")
                                        .tag(profile.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 220)

                            if let profileId = selectedProfileId, let onDeleteProfile = onDeleteProfile {
                                Button {
                                    onDeleteProfile(profileId)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Delete this saved voice profile")
                            }
                        }
                    }

                    HStack {
                        Button("Select Audio File...") {
                            selectAudioFile()
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Text("3+ seconds WAV/MP3/M4A")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                    }

                    if let url = referenceAudioURL {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "4caf50"))
                                .font(.caption)

                            Text(url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(.appTextPrimary)

                            if let duration = audioDuration {
                                Text("(\(String(format: "%.1f", duration))s)")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }

                            Spacer()

                            Button {
                                referenceAudioURL = nil
                                audioDuration = nil
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.appHighlight)
                    }

                    // Reference text transcript
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("What is said in the audio? (Highly recommended):")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)

                            Spacer()

                            if let onTranscribe = onTranscribe {
                                Button {
                                    onTranscribe()
                                } label: {
                                    HStack(spacing: 4) {
                                        if isTranscribing {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "waveform.and.mic")
                                        }
                                        Text(isTranscribing ? "Transcribing..." : "Transcribe")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(referenceAudioURL == nil || isTranscribing)
                            }
                        }

                        TextEditor(text: $referenceText)
                            .font(.system(.callout, design: .monospaced))
                            .frame(height: 60)
                            .padding(4)
                            .background(Color.appSecondary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.appTertiary.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .padding(.top, 4)

                    // Save as profile button (only when in manual mode with valid data)
                    if selectedProfileId == nil,
                       referenceAudioURL != nil,
                       !referenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let onSaveProfile = onSaveProfile {
                        Button {
                            onSaveProfile()
                        } label: {
                            Label("Save as Voice Profile", systemImage: "square.and.arrow.down")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }

                    // Target accent selector
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Accent")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)

                        Picker("Accent", selection: $cloneTargetAccent) {
                            Text("Automatic (from audio)").tag(nil as CloneTargetAccent?)
                            ForEach(CloneTargetAccent.allCases) { accent in
                                Text("\(accent.flag) \(accent.displayName)").tag(accent as CloneTargetAccent?)
                            }
                        }
                        .labelsHidden()

                        Text("Steers pronunciation without changing the cloned voice timbre.")
                            .font(.caption2)
                            .foregroundColor(.appTextMuted)
                    }

                    // Performance optimizations
                    Divider()
                    Text("Performance")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)

                    Toggle("Fast cloning (less accurate, 2-3x faster)", isOn: $cloneFastMode)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    Toggle("Lightweight model (0.6B, faster but lower quality)", isOn: $cloneFastModel)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                .padding(.leading, 20)
            }
        }
    }

    // MARK: - Private

    private func selectAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.wav,
            UTType.mp3,
            UTType.mpeg4Audio,
            UTType.audio,
        ]
        panel.message = "Select a reference audio file (3+ seconds)"
        panel.prompt = "Select"

        let result = panel.runModal()
        guard result == .OK, let url = panel.url else { return }

        // Clear saved profile selection when manually picking a file
        onSelectProfile?(nil)

        // Validate duration
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            if duration < 3.0 {
                errorMessage = "Audio too short (\(String(format: "%.1f", duration))s). Minimum 3 seconds required."
                referenceAudioURL = nil
                audioDuration = nil
                return
            }
            referenceAudioURL = url
            audioDuration = duration
            errorMessage = nil
        } catch {
            errorMessage = "Could not read audio file: \(error.localizedDescription)"
            referenceAudioURL = nil
            audioDuration = nil
        }
    }
}

import AVFoundation

// MARK: - Preview

#Preview("Voice Clone - Off") {
    struct PreviewWrapper: View {
        @State var isCloneMode = false
        @State var referenceURL: URL? = nil
        @State var referenceText = ""
        @State var fastMode = false
        @State var fastModel = false
        @State var accent: CloneTargetAccent? = nil

        var body: some View {
            VoiceCloneView(
                isCloneMode: $isCloneMode,
                referenceAudioURL: $referenceURL,
                referenceText: $referenceText,
                cloneFastMode: $fastMode,
                cloneFastModel: $fastModel,
                cloneTargetAccent: $accent
            )
            .padding()
            .frame(width: 400)
        }
    }
    return PreviewWrapper()
}

#Preview("Voice Clone - On") {
    struct PreviewWrapper: View {
        @State var isCloneMode = true
        @State var referenceURL: URL? = URL(fileURLWithPath: "/tmp/reference_voice.wav")
        @State var referenceText = "This is a sample reference text."
        @State var fastMode = false
        @State var fastModel = false
        @State var accent: CloneTargetAccent? = .spain

        var body: some View {
            VoiceCloneView(
                isCloneMode: $isCloneMode,
                referenceAudioURL: $referenceURL,
                referenceText: $referenceText,
                cloneFastMode: $fastMode,
                cloneFastModel: $fastModel,
                cloneTargetAccent: $accent,
                onTranscribe: { print("Transcribe tapped") },
                isTranscribing: false
            )
            .padding()
            .frame(width: 400)
        }
    }
    return PreviewWrapper()
}
