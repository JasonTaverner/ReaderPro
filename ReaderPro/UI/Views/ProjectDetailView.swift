import SwiftUI

/// Vista de detalle/edición de un proyecto existente
/// Es una vista de navegación completa (no modal)
struct ProjectDetailView: View {

    // MARK: - Properties

    @StateObject private var presenter: EditorPresenter
    @Environment(\.dismiss) private var dismiss

    /// ID del proyecto a editar (requerido)
    private let projectId: Identifier<Project>

    /// Estado para mostrar el modal de merge/export
    @State private var showingMergeOptions = false

    /// Estado para mostrar el modal de import text
    @State private var showingImportText = false

    /// Estado para mostrar la guia de ayuda
    @State private var showingHelp = false

    // MARK: - Initialization

    init(
        presenter: EditorPresenter,
        projectId: Identifier<Project>
    ) {
        _presenter = StateObject(wrappedValue: presenter)
        self.projectId = projectId
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // LEFT: Content area (text editor, entries, audio player)
            ScrollView {
                VStack(spacing: 24) {
                    textSection

                    if presenter.viewModel.hasEntries {
                        entriesSection
                    }

                    if presenter.viewModel.playingEntryId != nil || presenter.viewModel.hasAudio {
                        audioSection
                    }
                }
                .padding()
            }
            .background(Color.appPrimary)

            Divider()

            // RIGHT: Config + Actions sidebar
            ScrollView {
                VStack(spacing: 20) {
                    nameSection
                    voiceSection
                    controlsSection
                    durationSection
                    actionsSection
                }
                .padding()
            }
            .frame(width: 280)
            .background(Color.appSecondary)
        }
        .navigationTitle(presenter.viewModel.name.isEmpty ? "Edit Project" : presenter.viewModel.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    autoSaveIndicator

                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .help("Guia de uso")
                }
            }
        }
        .task {
            print("[ProjectDetailView] Loading project: \(projectId.value)")
            await presenter.onAppear(projectId: projectId)
        }
        .onDisappear {
            Task {
                await presenter.onDisappear()
            }
        }
        .disabled(presenter.viewModel.isLoading)
        .overlay {
            if presenter.viewModel.isLoading {
                loadingOverlay
            }
            if presenter.viewModel.isCapturing {
                capturingOverlay
            }
            if presenter.viewModel.isImportingImages {
                importingOverlay
            }
            if presenter.viewModel.isMerging {
                mergingOverlay
            }
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") {
                presenter.viewModel.error = nil
            }
        } message: {
            if let error = presenter.viewModel.error {
                Text(error)
            }
        }
        .alert("Saved!", isPresented: saveSuccessBinding) {
            Button("OK") {
                presenter.viewModel.showSaveSuccess = false
            }
        } message: {
            Text("Your changes have been saved.")
        }
        .alert("Import Complete", isPresented: importResultBinding) {
            Button("OK") {
                presenter.viewModel.showImportResult = false
                presenter.viewModel.importResult = nil
            }
        } message: {
            if let result = presenter.viewModel.importResult {
                Text(result)
            }
        }
        .sheet(isPresented: $showingMergeOptions) {
            MergeOptionsSheet(
                isPresented: $showingMergeOptions,
                entriesCount: presenter.viewModel.entries.count,
                hasAudioEntries: presenter.viewModel.entries.contains { $0.hasAudio },
                hasImageEntries: presenter.viewModel.entries.contains { $0.hasImage },
                onMerge: { mergeType in
                    showingMergeOptions = false
                    Task {
                        await presenter.mergeProject(type: mergeType)
                    }
                }
            )
        }
        .sheet(isPresented: $showingImportText) {
            ImportTextSheet(
                isPresented: $showingImportText,
                onImport: { text, splitMode, generateAudio in
                    showingImportText = false
                    Task {
                        await presenter.processTextBatch(text: text, splitMode: splitMode, generateAudio: generateAudio)
                    }
                }
            )
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
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .alert("Export Complete", isPresented: mergeResultBinding) {
            Button("Open in Finder") {
                if let path = presenter.viewModel.mergeResult?.exportsDirectory {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }
                presenter.viewModel.showMergeResult = false
                presenter.viewModel.mergeResult = nil
            }
            Button("OK") {
                presenter.viewModel.showMergeResult = false
                presenter.viewModel.mergeResult = nil
            }
        } message: {
            if let result = presenter.viewModel.mergeResult {
                Text(mergeResultMessage(result))
            }
        }
    }

    // MARK: - Merge Result Helper

    private func mergeResultMessage(_ result: MergeProjectResponse) -> String {
        var message = "Exported \(result.entriesProcessed) entries"
        if result.mergedAudioPath != nil {
            message += "\n- Audio: audio_completo.wav"
        }
        if result.mergedPDFPath != nil {
            message += "\n- PDF: documento.pdf (\(result.pdfPageCount ?? 0) pages)"
        }
        if result.mergedTextPath != nil {
            message += "\n- Text: documento_completo.txt"
        }
        return message
    }

    private var mergeResultBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showMergeResult },
            set: { presenter.viewModel.showMergeResult = $0 }
        )
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Project Name", systemImage: "pencil")
                .font(.headline)

            TextField("Enter project name", text: nameBinding)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar (only show if there are entries or always to allow adding)
            if presenter.viewModel.hasEntries {
                entryTabBar
            }

            // Header with char count
            HStack {
                let isProjectTab = presenter.viewModel.selectedEntryTab == nil
                Label(
                    isProjectTab ? "Project Text" : "Entry Text",
                    systemImage: isProjectTab ? "doc.text" : "text.alignleft"
                )
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

                Spacer()

                if isQwen3Selected {
                    Button {
                        showingHelp = true
                    } label: {
                        Label("Ver tags", systemImage: "tag")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.appHighlight)
                }

                let currentText = currentTabText
                if !currentText.isEmpty {
                    Text("\(currentText.count) chars")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
            }
            .padding(.top, presenter.viewModel.hasEntries ? 8 : 0)

            // Text editor for selected tab
            TextEditor(text: currentTabTextBinding)
                .font(.body)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color.appSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appTertiary.opacity(0.5), lineWidth: 1)
                )
                .padding(.top, 8)

            // Emotion tag hint (only when Qwen3 is selected)
            if isQwen3Selected {
                Text("Usa [alegre], [triste], [susurrando]... para cambiar la emocion en el texto.")
                    .font(.caption)
                    .foregroundColor(Color.appTextMuted)
                    .padding(.top, 4)
            }

            // Entry image thumbnail (if selected entry has image)
            if let selectedId = presenter.viewModel.selectedEntryTab,
               let entry = presenter.viewModel.entries.first(where: { $0.id == selectedId }),
               let imagePath = entry.imageFullPath {
                entryImageThumbnail(imagePath: imagePath, entry: entry)
                    .padding(.top, 8)
            }

            if presenter.viewModel.selectedEntryTab == nil && presenter.viewModel.text.isEmpty {
                Text("Add text to enable audio generation")
                    .font(.caption)
                    .foregroundColor(Color.appHighlight)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Entry Tab Bar

    private var entryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Project tab (always first)
                entryTab(label: "Project", id: nil, systemImage: "doc.text")

                // Divider
                Rectangle()
                    .fill(Color.appTertiary.opacity(0.5))
                    .frame(width: 1, height: 24)

                // Entry tabs
                ForEach(presenter.viewModel.entries) { entry in
                    entryTab(
                        label: entry.formattedNumber,
                        id: entry.id,
                        systemImage: entry.isRead ? "checkmark.circle" : (entry.hasImage ? "photo" : (entry.hasAudio ? "waveform" : "text.alignleft"))
                    )
                    .opacity(entry.isRead ? 0.6 : 1.0)
                    .contextMenu {
                        Button {
                            Task { await presenter.toggleEntryRead(id: entry.id) }
                        } label: {
                            Label(entry.isRead ? "Mark as Unread" : "Mark as Read", systemImage: entry.isRead ? "book.closed" : "checkmark.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            Task { await presenter.deleteEntry(id: entry.id) }
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    }
                }

                // Add new entry button
                Button {
                    Task { await presenter.addNewEntry() }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.appTertiary.opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .background(Color.appSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func entryTab(label: String, id: String?, systemImage: String) -> some View {
        let isSelected = presenter.viewModel.selectedEntryTab == id

        Button {
            presenter.selectEntryTab(id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.appAccent : Color.appTertiary.opacity(0.3))
            .foregroundColor(isSelected ? .white : Color.appTextPrimary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func entryImageThumbnail(imagePath: String, entry: AudioEntryDTO) -> some View {
        AsyncEntryImage(imagePath: imagePath)
            .frame(maxHeight: 300)
            .frame(maxWidth: .infinity, alignment: .center)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .onTapGesture {
                NSWorkspace.shared.open(URL(fileURLWithPath: imagePath))
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .padding(8)
            }
    }

    // MARK: - Current Tab Text

    /// The text content for the currently selected tab
    private var currentTabText: String {
        if let entryId = presenter.viewModel.selectedEntryTab {
            return presenter.viewModel.entryTexts[entryId] ?? ""
        }
        return presenter.viewModel.text
    }

    /// Binding for the text of the currently selected tab
    private var currentTabTextBinding: Binding<String> {
        if let entryId = presenter.viewModel.selectedEntryTab {
            return Binding(
                get: { presenter.viewModel.entryTexts[entryId] ?? "" },
                set: { presenter.updateEntryText(entryId: entryId, text: $0) }
            )
        }
        return textBinding
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // TTS Provider picker
            VStack(alignment: .leading, spacing: 8) {
                Label("TTS Provider", systemImage: "cpu")
                    .font(.headline)
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
                    Spacer()
                    Text(String(format: "%.1fx", presenter.viewModel.speed))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("0.5x").font(.caption).foregroundColor(.secondary)
                    Slider(value: speedBinding, in: 0.5...2.0, step: 0.1)
                    Text("2.0x").font(.caption).foregroundColor(.secondary)
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
        .background(Color.appPrimary.opacity(0.4))
        .cornerRadius(8)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Guardar cambios
            Button {
                Task {
                    print("[ProjectDetailView] Saving project...")
                    await presenter.save()
                    print("[ProjectDetailView] Save completed")
                }
            } label: {
                Label("Save Changes", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!presenter.viewModel.canSave)

            // Captura de pantalla + OCR
            Button {
                Task {
                    await presenter.captureScreen()
                }
            } label: {
                Label("Capture Screen", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(presenter.viewModel.isCapturing || presenter.viewModel.isImportingImages)

            // Import Images (batch OCR)
            Button {
                Task {
                    await presenter.importImages()
                }
            } label: {
                Label("Import Images", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(presenter.viewModel.isImportingImages || presenter.viewModel.isCapturing)

            // Import Document (PDF/EPUB)
            Button {
                Task {
                    await presenter.importDocument()
                }
            } label: {
                Label("Import Document", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(presenter.viewModel.isImportingImages || presenter.viewModel.isCapturing)

            // Import Text (batch)
            Button {
                showingImportText = true
            } label: {
                Label("Import Text", systemImage: "text.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(presenter.viewModel.isImportingImages || presenter.viewModel.isCapturing)

            // Generar audio (solo si hay texto)
            if !presenter.viewModel.text.isEmpty {
                Button {
                    print("[ProjectDetailView] Generating audio...")
                    presenter.startGeneration()
                } label: {
                    Label("Generate Audio", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(GenerationManager.shared.isActive)
            }

            // Generar audios faltantes (solo si hay entries sin audio)
            if presenter.viewModel.hasEntries,
               presenter.viewModel.entries.contains(where: { !$0.hasAudio }) {
                let missingCount = presenter.viewModel.entries.filter { !$0.hasAudio }.count
                Button {
                    presenter.startGenerationForMissingEntries()
                } label: {
                    Label("Generate Missing (\(missingCount))", systemImage: "waveform.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(GenerationManager.shared.isActive)
            }

            // Export/Merge (solo si hay entries)
            if presenter.viewModel.hasEntries {
                Button {
                    showingMergeOptions = true
                } label: {
                    Label("Export Project", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(presenter.viewModel.isMerging)
            }

            // Show in Finder
            if !presenter.viewModel.isNewProject {
                Button {
                    presenter.showInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Label("Audio Entries", systemImage: "square.grid.2x2")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Text("\(presenter.viewModel.entries.count) entries")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                ForEach(presenter.viewModel.entries) { entry in
                    let entryId = entry.id
                    let isEntryPlaying = presenter.viewModel.playingEntryId == entry.id
                    AudioEntryCard(
                        entry: entry,
                        isPlaying: isEntryPlaying,
                        isGenerating: presenter.viewModel.isGenerating && !entry.hasAudio,
                        onPlay: {
                            Task { await presenter.playEntry(id: entryId) }
                        },
                        onStop: {
                            Task { await presenter.stopEntry() }
                        },
                        onImageTap: entry.imageFullPath != nil ? {
                            if let path = entry.imageFullPath {
                                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                            }
                        } : nil,
                        onGenerateAudio: !entry.hasAudio && !GenerationManager.shared.isActive ? {
                            presenter.startGenerationForEntry(id: entryId)
                        } : nil
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEntryPlaying ? Color.appHighlight : Color.clear, lineWidth: 3)
                    )
                    .contextMenu {
                        Button {
                            Task { await presenter.toggleEntryRead(id: entryId) }
                        } label: {
                            Label(entry.isRead ? "Mark as Unread" : "Mark as Read", systemImage: entry.isRead ? "book.closed" : "checkmark.circle")
                        }

                        if entry.hasAudio {
                            Button {
                                presenter.startGenerationForEntry(id: entryId)
                            } label: {
                                Label("Regenerate Audio", systemImage: "arrow.clockwise")
                            }
                            .disabled(GenerationManager.shared.isActive)
                        }

                        Divider()

                        Button(role: .destructive) {
                            Task { await presenter.deleteEntry(id: entryId) }
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            // Header with Auto-play toggle
            HStack {
                Label("Audio Player", systemImage: "speaker.wave.2")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                Spacer()

                // Auto-play toggle
                Toggle(isOn: autoPlayBinding) {
                    Label("Auto-play", systemImage: "repeat")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // Waveform
            WaveformView(
                samples: presenter.viewModel.waveformSamples,
                progress: presenter.viewModel.playbackProgress,
                onSeek: { progress in
                    Task { await presenter.seek(to: progress) }
                }
            )

            // Playback controls with Previous/Next
            HStack(spacing: 16) {
                // Previous button
                Button {
                    Task { await presenter.playPrevious() }
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(Color.appTextPrimary)
                }
                .buttonStyle(.plain)
                .disabled(presenter.viewModel.currentPlayingIndex < 0)

                // Main playback controls
                PlaybackControlsView(
                    isPlaying: presenter.viewModel.isPlaying,
                    currentTime: presenter.viewModel.currentTimeFormatted,
                    duration: presenter.viewModel.audioDurationFormatted,
                    onPlayPause: {
                        Task { await presenter.togglePlayPause() }
                    },
                    onBackward: {
                        Task { await presenter.skipBackward() }
                    },
                    onForward: {
                        Task { await presenter.skipForward() }
                    }
                )
                .disabled(!presenter.viewModel.canPlay)

                // Next button
                Button {
                    Task { await presenter.playNext() }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(Color.appTextPrimary)
                }
                .buttonStyle(.plain)
                .disabled(presenter.viewModel.currentPlayingIndex < 0 ||
                          presenter.viewModel.currentPlayingIndex >= presenter.viewModel.entries.count - 1)
            }

            // Current entry indicator
            if presenter.viewModel.currentPlayingIndex >= 0 {
                HStack {
                    Text("Playing entry \(presenter.viewModel.currentPlayingIndex + 1) of \(presenter.viewModel.entries.count)")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)

                    if presenter.viewModel.isAutoPlayEnabled {
                        Label("Auto-play enabled", systemImage: "repeat")
                            .font(.caption)
                            .foregroundColor(Color.appHighlight)
                    }
                }
            }

            // Speed selector
            HStack(spacing: 8) {
                Text("Speed:")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)

                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    speedButton(for: speed)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.appSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func speedButton(for speed: Double) -> some View {
        let isSelected = abs(presenter.viewModel.playbackSpeed - Float(speed)) < 0.01
        let label = speed == 1.0 ? "1x" : speed == 2.0 ? "2x" : "\(speed)x"

        Button {
            Task { await presenter.setPlaybackSpeed(Float(speed)) }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.appAccent : Color.appTertiary.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }

    // MARK: - Auto-Save Indicator

    @ViewBuilder
    private var autoSaveIndicator: some View {
        switch presenter.viewModel.autoSaveState {
        case .idle:
            EmptyView()
        case .pending:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.appHighlight)
                    .frame(width: 6, height: 6)
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
        case .saving:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Saving...")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color(hex: "4caf50"))
                Text("Saved")
                    .font(.caption)
                    .foregroundColor(Color(hex: "4caf50"))
            }
        }
    }

    // MARK: - Overlays

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
            }
            .padding(32)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 10)
        }
    }


    private var capturingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.largeTitle)
                    .foregroundColor(Color.appAccent)
                Text("Processing screenshot...")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
                ProgressView()
                    .controlSize(.small)
            }
            .padding(32)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 10)
        }
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundColor(Color.appAccent)
                Text(presenter.viewModel.importProgressText)
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
                ProgressView(
                    value: Double(presenter.viewModel.importProgress.current),
                    total: max(1, Double(presenter.viewModel.importProgress.total))
                )
                .progressViewStyle(.linear)
                .frame(width: 200)
            }
            .padding(32)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 10)
        }
    }

    private var mergingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Exporting project...")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
                Text("Merging audio, images, and text")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
            }
            .padding(40)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 20)
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

    private var saveSuccessBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showSaveSuccess },
            set: { presenter.viewModel.showSaveSuccess = $0 }
        )
    }

    private var importResultBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.showImportResult },
            set: { presenter.viewModel.showImportResult = $0 }
        )
    }

    private var autoPlayBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewModel.isAutoPlayEnabled },
            set: { _ in presenter.toggleAutoPlay() }
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
            set: {
                presenter.viewModel.isCloneMode = $0
                if $0 {
                    // VoiceDesign and cloning are mutually exclusive: clear accent
                    presenter.viewModel.selectedAccent = ""
                    presenter.viewModel.voiceDesignCustom = ""
                }
            }
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

    private var accentBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.selectedAccent },
            set: {
                presenter.viewModel.selectedAccent = $0
                if !$0.isEmpty {
                    // VoiceDesign and cloning are mutually exclusive: disable cloning
                    presenter.viewModel.isCloneMode = false
                    presenter.viewModel.referenceAudioURL = nil
                }
            }
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

// MARK: - Async Entry Image

/// Loads an image asynchronously off the main thread to avoid blocking the UI
private struct AsyncEntryImage: View {
    let imagePath: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.appPrimary.opacity(0.3)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .task(id: imagePath) {
            image = await Task.detached(priority: .utility) {
                NSImage(contentsOfFile: imagePath)
            }.value
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProjectDetailView(
            presenter: DependencyContainer.shared.makeEditorPresenter(),
            projectId: Identifier<Project>()
        )
    }
}

