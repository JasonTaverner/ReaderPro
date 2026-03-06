import SwiftUI

/// Vista para crear y editar proyectos
/// Observa el ViewModel y delega acciones al Presenter
struct EditorView: View {

    // MARK: - Properties

    @StateObject private var presenter: EditorPresenter
    @Environment(\.dismiss) private var dismiss

    private let projectId: Identifier<Project>?

    /// Callback para abrir el reproductor (opcional)
    var onPlayAudio: ((Identifier<Project>) -> Void)?

    // MARK: - Initialization

    init(
        presenter: EditorPresenter,
        projectId: Identifier<Project>? = nil,
        onPlayAudio: ((Identifier<Project>) -> Void)? = nil
    ) {
        _presenter = StateObject(wrappedValue: presenter)
        self.projectId = projectId
        self.onPlayAudio = onPlayAudio
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Nombre del proyecto
                        nameSection

                        // Editor de texto
                        textSection

                        // Configuración de voz
                        voiceSection

                        // Controles de velocidad
                        controlsSection

                        // Duración estimada
                        durationSection

                        // Botones de acción
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(presenter.viewModel.viewTitle)
            .toolbar {
                toolbarContent
            }
            .task {
                await presenter.onAppear(projectId: projectId)
            }
            .disabled(presenter.viewModel.isLoading)
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK") {
                    presenter.viewModel.error = nil
                }
            } message: {
                if let error = presenter.viewModel.error {
                    Text(error)
                }
            }
            .alert("Audio Generated!", isPresented: successAlertBinding) {
                Button("Play Now") {
                    presenter.viewModel.showAudioGeneratedSuccess = false
                    playGeneratedAudio()
                }
                .keyboardShortcut(.defaultAction)

                Button("Continue Editing", role: .cancel) {
                    presenter.viewModel.showAudioGeneratedSuccess = false
                }
            } message: {
                if let duration = presenter.viewModel.generatedAudioDuration {
                    Text("Your audio (\(duration)) is ready to play.")
                }
            }
            .alert("Project Saved!", isPresented: saveSuccessBinding) {
                Button("OK") {
                    presenter.viewModel.showSaveSuccess = false
                }
            } message: {
                Text("Your project has been saved successfully.")
            }
            .sheet(isPresented: saveCloneProfileSheetBinding) {
                SaveCloneProfileSheet(
                    profileName: cloneProfileNameBinding,
                    isSaving: presenter.viewModel.isSavingCloneProfile,
                    onSave: {
                        Task {
                            await presenter.saveClonedVoiceProfile(name: presenter.viewModel.cloneProfileName)
                            presenter.viewModel.showSaveCloneProfileSheet = false
                        }
                    },
                    onCancel: {
                        presenter.viewModel.showSaveCloneProfileSheet = false
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func playGeneratedAudio() {
        guard let projectIdString = presenter.viewModel.projectId,
              let uuid = UUID(uuidString: projectIdString) else {
            return
        }
        let projectId = Identifier<Project>(uuid)

        if let onPlayAudio = onPlayAudio {
            dismiss()
            onPlayAudio(projectId)
        } else {
            // Si no hay callback, solo cerrar
            dismiss()
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Project Name", systemImage: "pencil")
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

            TextField("Enter project name", text: nameBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Text Content", systemImage: "doc.text")
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

            TextEditor(text: textBinding)
                .font(.body)
                .frame(minHeight: 200)
                .background(Color.appSecondary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.appTertiary.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // TTS Provider picker
            VStack(alignment: .leading, spacing: 8) {
                Label("TTS Provider", systemImage: "cpu")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
                Picker("Provider", selection: providerBinding) {
                    Text("Kokoro").tag("kokoro")
                    Text("Qwen3").tag("qwen3")
                }
                .pickerStyle(.segmented)
            }

            VoiceSelectorView(
                voices: presenter.viewModel.availableVoices,
                selectedId: presenter.viewModel.selectedVoiceId,
                onSelect: { presenter.selectVoice($0) }
            )

            // Qwen3-specific: Accent, Emotion, and Voice cloning
            if isQwen3Selected {
                Divider()

                AccentSelectorView(
                    selectedAccent: accentBinding,
                    selectedGender: genderBinding,
                    customDescription: voiceDesignCustomBinding
                )

                EmotionSelectorView(
                    selectedEmotion: emotionBinding,
                    customInstruct: instructBinding
                )

                VoiceCloneView(
                    isCloneMode: cloneModeBinding,
                    referenceAudioURL: referenceAudioBinding,
                    referenceText: referenceTextBinding,
                    cloneFastMode: cloneFastModeBinding,
                    cloneFastModel: cloneFastModelBinding,
                    cloneTargetAccent: cloneTargetAccentBinding,
                    onTranscribe: {
                        Task { await presenter.transcribeReferenceAudio() }
                    },
                    isTranscribing: presenter.viewModel.isTranscribing,
                    savedProfiles: presenter.viewModel.savedClonedVoices,
                    selectedProfileId: presenter.viewModel.selectedClonedVoiceId,
                    onSelectProfile: { id in
                        presenter.selectClonedVoiceProfile(id: id)
                    },
                    onSaveProfile: {
                        presenter.viewModel.cloneProfileName = ""
                        presenter.viewModel.showSaveCloneProfileSheet = true
                    },
                    onDeleteProfile: { id in
                        Task { await presenter.deleteClonedVoiceProfile(id: id) }
                    }
                )
            }
        }
    }

    /// Whether the currently selected voice belongs to the Qwen3 provider
    private var isQwen3Selected: Bool {
        guard let selectedId = presenter.viewModel.selectedVoiceId,
              let voice = presenter.viewModel.availableVoices.first(where: { $0.id == selectedId })
        else { return false }
        return voice.provider == Voice.TTSProvider.qwen3.rawValue
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Speed Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Speed", systemImage: "speedometer")
                        .font(.headline)
                        .foregroundColor(Color.appTextPrimary)

                    Spacer()

                    Text(String(format: "%.1fx", presenter.viewModel.speed))
                        .font(.subheadline)
                        .foregroundColor(Color.appTextSecondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("0.5x")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)

                    Slider(value: speedBinding, in: 0.5...2.0, step: 0.1)

                    Text("2.0x")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
            }

        }
    }

    private var durationSection: some View {
        HStack {
            Label("Estimated Duration", systemImage: "clock")
                .font(.subheadline)
                .foregroundColor(Color.appTextSecondary)

            Spacer()

            Text(presenter.viewModel.estimatedDuration)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.appTextPrimary)
                .monospacedDigit()
        }
        .padding()
        .background(Color.appSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    private var actionsSection: some View {
        // Solo botón Guardar - generar audio se hace desde la lista de proyectos
        Button {
            Task {
                await presenter.save()
            }
        } label: {
            Label("Save Project", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!presenter.viewModel.canSave)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    await presenter.save()
                    if presenter.viewModel.error == nil {
                        dismiss()
                    }
                }
            } label: {
                Text("Done")
            }
            .disabled(!presenter.viewModel.canSave)
        }
    }

    // MARK: - Bindings

    private var nameBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.name },
            set: { presenter.updateName($0) }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.text },
            set: { presenter.updateText($0) }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { presenter.viewModel.speed },
            set: { presenter.updateSpeed($0) }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.error != nil },
            set: { if !$0 { presenter.viewModel.error = nil } }
        )
    }

    private var successAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showAudioGeneratedSuccess },
            set: { presenter.viewModel.showAudioGeneratedSuccess = $0 }
        )
    }

    private var saveSuccessBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showSaveSuccess },
            set: { presenter.viewModel.showSaveSuccess = $0 }
        )
    }

    private var providerBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.activeProvider },
            set: { presenter.switchProvider(to: $0) }
        )
    }

    // MARK: - Qwen3 Bindings

    private var emotionBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.selectedEmotion },
            set: { presenter.viewModel.selectedEmotion = $0 }
        )
    }

    private var instructBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.customInstruct },
            set: { presenter.viewModel.customInstruct = $0 }
        )
    }

    private var cloneModeBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.isCloneMode },
            set: { presenter.viewModel.isCloneMode = $0 }
        )
    }

    private var referenceAudioBinding: Binding<URL?> {
        Binding(
            get: { presenter.viewModel.referenceAudioURL },
            set: { presenter.viewModel.referenceAudioURL = $0 }
        )
    }

    private var referenceTextBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.referenceText },
            set: { presenter.viewModel.referenceText = $0 }
        )
    }

    private var cloneFastModeBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.cloneFastMode },
            set: { presenter.viewModel.cloneFastMode = $0 }
        )
    }

    private var cloneFastModelBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.cloneFastModel },
            set: { presenter.viewModel.cloneFastModel = $0 }
        )
    }

    private var cloneTargetAccentBinding: Binding<CloneTargetAccent?> {
        Binding(
            get: { presenter.viewModel.cloneTargetAccent },
            set: { presenter.viewModel.cloneTargetAccent = $0 }
        )
    }

    private var saveCloneProfileSheetBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showSaveCloneProfileSheet },
            set: { presenter.viewModel.showSaveCloneProfileSheet = $0 }
        )
    }

    private var cloneProfileNameBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.cloneProfileName },
            set: { presenter.viewModel.cloneProfileName = $0 }
        )
    }

    // MARK: - Accent / VoiceDesign Bindings

    private var accentBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.selectedAccent },
            set: { presenter.viewModel.selectedAccent = $0 }
        )
    }

    private var genderBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.voiceDesignGender },
            set: { presenter.viewModel.voiceDesignGender = $0 }
        )
    }

    private var voiceDesignCustomBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.voiceDesignCustom },
            set: { presenter.viewModel.voiceDesignCustom = $0 }
        )
    }
}

// MARK: - Preview

#Preview("New Project") {
    EditorView(
        presenter: DependencyContainer.shared.makeEditorPresenter(),
        projectId: nil
    )
}
