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

                if presenter.viewModel.defaultProvider != "native" {
                    Section("Server Configuration") {
                        serverConfigSection
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
        .frame(width: 500, height: presenter.viewModel.defaultProvider == "qwen3" ? 920 : presenter.viewModel.defaultProvider == "native" ? 400 : 620)
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
            }
            .pickerStyle(.segmented)

            if presenter.viewModel.defaultProvider == "kokoro" {
                Picker("Kokoro Mode", selection: defaultKokoroModeBinding) {
                    Text("Local (ONNX)").tag("localONNX")
                    Text("Server (Python)").tag("remoteServer")
                }
                .pickerStyle(.segmented)
            }

            if presenter.viewModel.defaultProvider == "native" {
                Text("Uses built-in macOS voices. No server required.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            Text("Applied on next app launch")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
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
