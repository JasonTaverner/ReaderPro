import SwiftUI

/// Vista de configuración de la aplicación
/// Permite al usuario cambiar el directorio de almacenamiento
struct SettingsView: View {

    // MARK: - Properties

    @StateObject private var presenter: SettingsPresenter

    // MARK: - Initialization

    init(presenter: SettingsPresenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appPrimary.ignoresSafeArea()
            
            Form {
                Section("Storage") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Directory")
                            .font(.headline)
                            .foregroundColor(Color.appTextPrimary)

                        HStack {
                            Text(presenter.viewModel.currentDirectoryPath)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .foregroundColor(Color.appTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Change...") {
                                presenter.selectDirectory()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        if presenter.viewModel.isCustomDirectory {
                            Button("Reset to Default") {
                                presenter.resetToDefault()
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Default TTS Provider") {
                    defaultProviderSection
                }

                Section("Global Shortcuts") {
                    globalShortcutsSection
                }

                if presenter.viewModel.defaultProvider != "native" {
                    Section("Server Configuration") {
                        serverConfigSection
                    }

                    Section("Servers") {
                        serversToggleSection
                    }
                }

                if presenter.viewModel.defaultProvider == "qwen3" {
                    Section("Default Qwen3 Voice") {
                        defaultQwen3VoiceSection
                    }

                    Section("Default Clone Settings") {
                        defaultCloneSection
                    }
                }

                if presenter.viewModel.defaultProvider != "native" {
                    Section("Cloned Voices") {
                        clonedVoicesSection
                    }

                    Section("TTS Memory (Qwen3)") {
                        ttsMemorySection
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: presenter.viewModel.defaultProvider == "qwen3" ? 1020 : presenter.viewModel.defaultProvider == "native" ? 400 : 720)
        .onAppear {
            presenter.onAppear()
        }
        .alert(
            "Restart Required",
            isPresented: restartAlertBinding
        ) {
            Button("OK") {
                presenter.viewModel.showRestartAlert = false
            }
        } message: {
            Text("The storage directory has been changed. Please restart ReaderPro for the change to take effect.")
        }
        .alert(
            "Error",
            isPresented: errorAlertBinding
        ) {
            Button("OK") {
                presenter.viewModel.error = nil
            }
        } message: {
            if let error = presenter.viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Default Provider Section

    private var defaultProviderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Provider", selection: defaultProviderBinding) {
                Text("System (macOS)").tag("native")
                Text("Kokoro").tag("kokoro")
                Text("Qwen3").tag("qwen3")
                Text("VoxCPM2").tag("voxcpm")
                Text("Chatterbox").tag("chatterbox")
                Text("Supertonic").tag("supertonic")
            }
            .pickerStyle(.menu)

            if presenter.viewModel.defaultProvider == "kokoro" {
                Picker("Kokoro Mode", selection: defaultKokoroModeBinding) {
                    Text("Local (ONNX)").tag("localONNX")
                    Text("Server (Python)").tag("remoteServer")
                }
                .pickerStyle(.segmented)

                KokoroModelStatusView()
            }

            if presenter.viewModel.defaultProvider == "native" {
                Text("Uses built-in macOS voices. No server required.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            if presenter.viewModel.defaultProvider == "voxcpm" {
                Text("Maximum quality (48 kHz), ~2x slower than real time. Runs on the same local MLX server as Qwen3.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            if presenter.viewModel.defaultProvider == "supertonic" {
                Text("Fastest engine (~4x real time, ONNX): 10 preset voices, 31 languages, expression tags. No cloning. Same local server as Qwen3.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            if presenter.viewModel.defaultProvider == "chatterbox" {
                Text("Fast multilingual model (~real time). Best with voice cloning — the accent is inherited from your reference. Same local MLX server as Qwen3.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            Text("Applied on next app launch")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Global Shortcuts Section

    /// Atajos seleccionados que colisionan entre comandos activos
    private var duplicatedShortcuts: [String] {
        var combos: [String] = []
        if presenter.viewModel.clipboardReadEnabled { combos.append(presenter.viewModel.clipboardReadHotKey) }
        if presenter.viewModel.clipboardEntryEnabled { combos.append(presenter.viewModel.clipboardEntryHotKey) }
        if presenter.viewModel.dictationClipboardEnabled { combos.append(presenter.viewModel.dictationClipboardHotKey) }
        if presenter.viewModel.dictationEntryEnabled { combos.append(presenter.viewModel.dictationEntryHotKey) }
        var seen = Set<String>()
        var dups = Set<String>()
        for c in combos {
            if !seen.insert(c).inserted { dups.insert(c) }
        }
        return dups.compactMap { GlobalHotKeyCombo(rawValue: $0)?.displayName }
    }

    private var globalShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !duplicatedShortcuts.isEmpty {
                Label("Shortcut conflict: \(duplicatedShortcuts.joined(separator: ", ")) is assigned to more than one command — only the first registered will work. Pick a different shortcut for each.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Toggle("Read clipboard aloud (system-wide shortcut)", isOn: clipboardReadEnabledBinding)

            if presenter.viewModel.clipboardReadEnabled {
                HStack {
                    Text("Shortcut")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: clipboardReadHotKeyBinding) {
                        ForEach(GlobalHotKeyCombo.allCases) { combo in
                            Text(combo.displayName).tag(combo.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }

                HStack {
                    Text("Model")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: clipboardReadProviderBinding) {
                        Text("System (macOS)").tag("native")
                        Text("Kokoro").tag("kokoro")
                        Text("Qwen3").tag("qwen3")
                        Text("VoxCPM2").tag("voxcpm")
                        Text("Chatterbox").tag("chatterbox")
                        Text("Supertonic").tag("supertonic")
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }

                Text("Press the shortcut anywhere in macOS to read the copied text aloud; press again to stop. Cloning-capable models use your default saved voice profile.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            Divider()

            Toggle("Create entry from clipboard (system-wide shortcut)", isOn: clipboardEntryEnabledBinding)

            if presenter.viewModel.clipboardEntryEnabled {
                HStack {
                    Text("Shortcut")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: clipboardEntryHotKeyBinding) {
                        ForEach(GlobalHotKeyCombo.allCases) { combo in
                            Text(combo.displayName).tag(combo.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }

                HStack {
                    Text("Target")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: clipboardEntryTargetBinding) {
                        Text("Clipboard Inbox project").tag("inbox")
                        Text("Last opened project").tag("last")
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }

                Toggle("Generate audio automatically", isOn: clipboardEntryGenerateAudioBinding)

                if presenter.viewModel.clipboardEntryGenerateAudio {
                    HStack {
                        Text("Model")
                            .font(.subheadline)
                            .foregroundColor(Color.appTextPrimary)
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: clipboardEntryProviderBinding) {
                            Text("System (macOS)").tag("native")
                            Text("Kokoro").tag("kokoro")
                            Text("Qwen3").tag("qwen3")
                            Text("VoxCPM2").tag("voxcpm")
                            Text("Chatterbox").tag("chatterbox")
                            Text("Supertonic").tag("supertonic")
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }
                }

                Text("Creates a new entry with the copied text (a 'Pop' sound confirms it; 'Glass' when its audio is ready). Use different shortcuts for each command.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            Divider()

            Toggle("Dictate to clipboard (voice → text)", isOn: dictationClipboardEnabledBinding)

            if presenter.viewModel.dictationClipboardEnabled {
                HStack {
                    Text("Shortcut")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: dictationClipboardHotKeyBinding) {
                        ForEach(GlobalHotKeyCombo.allCases) { combo in
                            Text(combo.displayName).tag(combo.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }
            }

            Toggle("Dictate to new entry (voice → entry)", isOn: dictationEntryEnabledBinding)

            if presenter.viewModel.dictationEntryEnabled {
                HStack {
                    Text("Shortcut")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: dictationEntryHotKeyBinding) {
                        ForEach(GlobalHotKeyCombo.allCases) { combo in
                            Text(combo.displayName).tag(combo.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }
            }

            if presenter.viewModel.dictationClipboardEnabled || presenter.viewModel.dictationEntryEnabled {
                HStack {
                    Text("Language")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: dictationLanguageBinding) {
                        Text("🇪🇸 Español").tag("es")
                        Text("🇬🇧 English").tag("en")
                        Text("🇫🇷 Français").tag("fr")
                        Text("🇩🇪 Deutsch").tag("de")
                        Text("🇮🇹 Italiano").tag("it")
                        Text("🇵🇹 Português").tag("pt")
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }

                Text("Press the shortcut to START recording ('Tink'), speak, and press again to STOP ('Pop'). The text is transcribed locally; 'Glass' confirms it's on the clipboard. New entries go to the same target project as the clipboard command.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var dictationClipboardEnabledBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.dictationClipboardEnabled },
            set: { presenter.setDictationClipboardEnabled($0) }
        )
    }

    private var dictationClipboardHotKeyBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.dictationClipboardHotKey },
            set: { presenter.setDictationClipboardHotKey($0) }
        )
    }

    private var dictationEntryEnabledBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.dictationEntryEnabled },
            set: { presenter.setDictationEntryEnabled($0) }
        )
    }

    private var dictationEntryHotKeyBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.dictationEntryHotKey },
            set: { presenter.setDictationEntryHotKey($0) }
        )
    }

    private var dictationLanguageBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.dictationLanguage },
            set: { presenter.setDictationLanguage($0) }
        )
    }

    private var clipboardEntryEnabledBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.clipboardEntryEnabled },
            set: { presenter.setClipboardEntryEnabled($0) }
        )
    }

    private var clipboardEntryHotKeyBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.clipboardEntryHotKey },
            set: { presenter.setClipboardEntryHotKey($0) }
        )
    }

    private var clipboardEntryProviderBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.clipboardEntryProvider },
            set: { presenter.setClipboardEntryProvider($0) }
        )
    }

    private var clipboardEntryTargetBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.clipboardEntryTarget },
            set: { presenter.setClipboardEntryTarget($0) }
        )
    }

    private var clipboardEntryGenerateAudioBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.clipboardEntryGenerateAudio },
            set: { presenter.setClipboardEntryGenerateAudio($0) }
        )
    }

    private var clipboardReadEnabledBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.clipboardReadEnabled },
            set: { presenter.setClipboardReadEnabled($0) }
        )
    }

    private var clipboardReadHotKeyBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.clipboardReadHotKey },
            set: { presenter.setClipboardReadHotKey($0) }
        )
    }

    private var clipboardReadProviderBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.clipboardReadProvider },
            set: { presenter.setClipboardReadProvider($0) }
        )
    }

    // MARK: - Server Configuration Section

    private var serverConfigSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Kokoro URL")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextPrimary)
                    .frame(width: 80, alignment: .leading)
                TextField("http://127.0.0.1:8880", text: kokoroServerURLBinding)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Qwen3 URL")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextPrimary)
                    .frame(width: 80, alignment: .leading)
                TextField("http://127.0.0.1:8890", text: qwen3ServerURLBinding)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Restart required after changing server URLs")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Servers Toggle Section

    private var serversToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("Kokoro Server", isOn: kokoroServerBinding)
                    .disabled(presenter.viewModel.isServerToggleInProgress)

                Spacer()

                serverStatusBadge(presenter.viewModel.kokoroServerStatus)
            }

            HStack {
                Toggle("Qwen3 Server", isOn: qwen3ServerBinding)
                    .disabled(presenter.viewModel.isServerToggleInProgress)

                Spacer()

                serverStatusBadge(presenter.viewModel.qwen3ServerStatus)
            }

            Text("Turn off servers to free memory when not in use")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func serverStatusBadge(_ status: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status == "Running" ? Color(hex: "4caf50") :
                      status.hasPrefix("Starting") ? Color.appHighlight : .red)
                .frame(width: 6, height: 6)
            Text(status)
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
    }

    // MARK: - Default Qwen3 Voice Section

    private var defaultQwen3VoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Accent", selection: defaultQwen3AccentBinding) {
                Text("None").tag("")
                ForEach(VoiceAccent.allCases, id: \.rawValue) { accent in
                    Text("\(accent.flag) \(accent.displayName)").tag(accent.rawValue)
                }
            }

            Picker("Emotion", selection: defaultQwen3EmotionBinding) {
                ForEach(SpeechEmotion.allCases, id: \.rawValue) { emotion in
                    Text(emotion.displayName).tag(emotion.rawValue)
                }
            }

            Picker("Gender", selection: defaultQwen3GenderBinding) {
                ForEach(VoiceGender.allCases, id: \.rawValue) { gender in
                    Text(gender.displayName).tag(gender.rawValue)
                }
            }

            Text("Applied to new projects as initial voice settings")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Default Clone Section

    private var defaultCloneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable voice cloning by default", isOn: defaultCloneEnabledBinding)

            Picker("Saved Voice", selection: defaultCloneProfileIdBinding) {
                Text("None (manual)").tag("")
                // Tag para el perfil guardado si aún no está cargado o fue borrado:
                // sin él, el Picker recibe una selección UUID sin tag asociado
                if !presenter.viewModel.defaultCloneProfileId.isEmpty,
                   !presenter.viewModel.clonedVoiceProfiles.contains(where: { $0.id == presenter.viewModel.defaultCloneProfileId }) {
                    Text("(Saved profile)").tag(presenter.viewModel.defaultCloneProfileId)
                }
                ForEach(presenter.viewModel.clonedVoiceProfiles) { profile in
                    Text("\(profile.name) (\(profile.formattedDuration))").tag(profile.id)
                }
            }

            Picker("Target Accent", selection: defaultCloneAccentBinding) {
                Text("Automatic").tag("")
                ForEach(CloneTargetAccent.allCases, id: \.rawValue) { accent in
                    Text("\(accent.flag) \(accent.displayName)").tag(accent.rawValue)
                }
            }

            Toggle("Fast cloning (less accurate, 2-3x faster)", isOn: defaultCloneFastModeBinding)

            Toggle("Lightweight model (0.6B, faster but lower quality)", isOn: defaultCloneFastModelBinding)

            Text("Applied to new projects as initial clone settings")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Cloned Voices Section

    private var clonedVoicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Directory")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Text(presenter.viewModel.clonedVoicesDirectoryPath)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(Color.appTextSecondary)
            }

            HStack {
                Text("Saved Profiles")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Text("\(presenter.viewModel.clonedVoicesCount)")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
            }

            Button {
                presenter.openClonedVoicesInFinder()
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.vertical, 4)
    }

    // MARK: - TTS Memory Section

    private var ttsMemorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Server")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                if presenter.viewModel.isServerOnline {
                    Label("Online", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "4caf50"))
                } else {
                    Label("Offline", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Loaded Model")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                if presenter.viewModel.isModelOperationInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else if let model = presenter.viewModel.loadedModelName {
                    Text(model.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .foregroundColor(Color.appTextSecondary)
                } else {
                    Text("None")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            HStack {
                Button {
                    Task { await presenter.refreshModelStatus() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                Button {
                    Task { await presenter.unloadModel() }
                } label: {
                    Label("Free Memory", systemImage: "memorychip")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(
                    presenter.viewModel.loadedModelName == nil ||
                    presenter.viewModel.isModelOperationInProgress ||
                    !presenter.viewModel.isServerOnline
                )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Private Helpers

    private var defaultProviderBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultProvider },
            set: { presenter.setDefaultProvider($0) }
        )
    }

    private var defaultKokoroModeBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultKokoroMode },
            set: { presenter.setDefaultKokoroMode($0) }
        )
    }

    private var kokoroServerURLBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.kokoroServerURL },
            set: { presenter.setKokoroServerURL($0) }
        )
    }

    private var qwen3ServerURLBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.qwen3ServerURL },
            set: { presenter.setQwen3ServerURL($0) }
        )
    }

    private var defaultQwen3AccentBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultQwen3Accent },
            set: { presenter.setDefaultQwen3Accent($0) }
        )
    }

    private var defaultQwen3EmotionBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultQwen3Emotion },
            set: { presenter.setDefaultQwen3Emotion($0) }
        )
    }

    private var defaultQwen3GenderBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultQwen3Gender },
            set: { presenter.setDefaultQwen3Gender($0) }
        )
    }

    private var defaultCloneEnabledBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.defaultCloneEnabled },
            set: { presenter.setDefaultCloneEnabled($0) }
        )
    }

    private var defaultCloneProfileIdBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultCloneProfileId },
            set: { presenter.setDefaultCloneProfileId($0) }
        )
    }

    private var defaultCloneAccentBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.defaultCloneAccent },
            set: { presenter.setDefaultCloneAccent($0) }
        )
    }

    private var defaultCloneFastModeBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.defaultCloneFastMode },
            set: { presenter.setDefaultCloneFastMode($0) }
        )
    }

    private var defaultCloneFastModelBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.defaultCloneFastModel },
            set: { presenter.setDefaultCloneFastModel($0) }
        )
    }

    private var kokoroServerBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.isKokoroServerEnabled },
            set: { presenter.toggleKokoroServer($0) }
        )
    }

    private var qwen3ServerBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.isQwen3ServerEnabled },
            set: { presenter.toggleQwen3Server($0) }
        )
    }

    private var restartAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showRestartAlert },
            set: { presenter.viewModel.showRestartAlert = $0 }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.error != nil },
            set: { if !$0 { presenter.viewModel.error = nil } }
        )
    }
}
