import Foundation
import Combine
import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Presenter para el editor de proyectos
/// Coordina la creación, edición y generación de audio
@MainActor
final class EditorPresenter: ObservableObject {

    // MARK: - Published Properties

    /// ViewModel que la View observa
    @Published private(set) var viewModel = EditorViewModel()

    // MARK: - Dependencies

    private let createProjectUseCase: CreateProjectUseCaseProtocol
    private let getProjectUseCase: GetProjectUseCaseProtocol
    private let updateProjectUseCase: UpdateProjectUseCaseProtocol
    private let generateAudioUseCase: GenerateAudioUseCaseProtocol
    private let saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol
    private let captureAndProcessUseCase: CaptureAndProcessUseCaseProtocol
    private let processImageBatchUseCase: ProcessImageBatchUseCaseProtocol
    private let processDocumentUseCase: ProcessDocumentUseCaseProtocol
    private let generateAudioForEntryUseCase: GenerateAudioForEntryUseCaseProtocol
    private let mergeProjectUseCase: MergeProjectUseCase?
    private let processTextBatchUseCase: ProcessTextBatchUseCaseProtocol?
    private let ttsPort: TTSPort
    private var audioPlayer: AudioPlayerPort
    private let audioStorage: AudioStoragePort
    private let ttsCoordinator: TTSServerCoordinator?
    private let clonedVoiceRepository: ClonedVoiceRepositoryPort?
    private let generationManager: GenerationManager

    /// Subscription para propagar cambios del viewModel anidado
    private var viewModelCancellable: AnyCancellable?

    /// Subscription para observar cambios de provider en el coordinator
    private var providerCancellable: AnyCancellable?

    /// Subscription to bridge GenerationManager active state to viewModel.isGenerating
    private var generationCancellable: AnyCancellable?

    // MARK: - UserDefaults Keys

    static let cloneFastModeKey = "cloneFastMode"
    static let cloneFastModelKey = "cloneFastModel"

    /// Timer para actualizar el estado de reproducción
    private var updateTimer: Timer?

    /// Timer for auto-save debounce
    private var autoSaveTimer: Timer?

    /// Debounce interval for auto-save (2 seconds)
    private let autoSaveInterval: TimeInterval = 2.0

    /// Intervalo de salto (segundos)
    private let skipInterval: TimeInterval = 10.0

    // MARK: - Initialization

    init(
        createProjectUseCase: CreateProjectUseCaseProtocol,
        getProjectUseCase: GetProjectUseCaseProtocol,
        updateProjectUseCase: UpdateProjectUseCaseProtocol,
        generateAudioUseCase: GenerateAudioUseCaseProtocol,
        saveAudioEntryUseCase: SaveAudioEntryUseCaseProtocol,
        captureAndProcessUseCase: CaptureAndProcessUseCaseProtocol,
        processImageBatchUseCase: ProcessImageBatchUseCaseProtocol,
        processDocumentUseCase: ProcessDocumentUseCaseProtocol,
        generateAudioForEntryUseCase: GenerateAudioForEntryUseCaseProtocol,
        mergeProjectUseCase: MergeProjectUseCase? = nil,
        processTextBatchUseCase: ProcessTextBatchUseCaseProtocol? = nil,
        ttsPort: TTSPort,
        audioPlayer: AudioPlayerPort,
        audioStorage: AudioStoragePort,
        ttsCoordinator: TTSServerCoordinator? = nil,
        clonedVoiceRepository: ClonedVoiceRepositoryPort? = nil,
        generationManager: GenerationManager = .shared
    ) {
        self.createProjectUseCase = createProjectUseCase
        self.getProjectUseCase = getProjectUseCase
        self.updateProjectUseCase = updateProjectUseCase
        self.generateAudioUseCase = generateAudioUseCase
        self.saveAudioEntryUseCase = saveAudioEntryUseCase
        self.captureAndProcessUseCase = captureAndProcessUseCase
        self.processImageBatchUseCase = processImageBatchUseCase
        self.processDocumentUseCase = processDocumentUseCase
        self.generateAudioForEntryUseCase = generateAudioForEntryUseCase
        self.mergeProjectUseCase = mergeProjectUseCase
        self.processTextBatchUseCase = processTextBatchUseCase
        self.ttsPort = ttsPort
        self.audioPlayer = audioPlayer
        self.audioStorage = audioStorage
        self.ttsCoordinator = ttsCoordinator
        self.clonedVoiceRepository = clonedVoiceRepository
        self.generationManager = generationManager

        // Propagar cambios del viewModel anidado al presenter
        // Esto soluciona el problema de SwiftUI con ObservableObjects anidados
        viewModelCancellable = viewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Setup playback completion callback for auto-play
        self.audioPlayer.onPlaybackComplete = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handlePlaybackCompletion()
            }
        }

        // Observe provider changes from coordinator to reload voices and sync UI
        if let coordinator = ttsCoordinator {
            providerCancellable = coordinator.$activeProvider
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .sink { [weak self] provider in
                    guard let self = self else { return }
                    let rawValue = provider.rawValue
                    guard self.viewModel.activeProvider != rawValue else { return }
                    self.viewModel.activeProvider = rawValue
                    Task { @MainActor [weak self] in
                        await self?.loadVoices()
                    }
                }
        }

        // Load all persisted voice/clone defaults from UserDefaults
        applyPersistedDefaults()

        // Bridge GenerationManager.isActive → viewModel.isGenerating for backward compat.
        // Only update when the value actually changes to avoid cascading objectWillChange.
        generationCancellable = generationManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newValue = self.generationManager.isActive
                if self.viewModel.isGenerating != newValue {
                    self.viewModel.isGenerating = newValue
                }
            }
    }

    // MARK: - View Lifecycle

    /// Llamado cuando la vista aparece
    /// - Parameter projectId: ID del proyecto a editar, o nil para crear uno nuevo
    func onAppear(projectId: Identifier<Project>?) async {
        // Si ya estamos en este proyecto y no es nuevo, no resetear todo (evita parpadeo)
        if let currentId = viewModel.projectId, let newId = projectId?.value.uuidString, currentId == newId {
            return
        }

        viewModel.reset()
        viewModel.isLoading = true
        viewModel.error = nil
        viewModel.activeProvider = ttsCoordinator?.activeProvider.rawValue ?? "kokoro"

        // Re-apply persisted defaults after reset (fresh from UserDefaults in case
        // the user changed them in Settings while the editor was open)
        applyPersistedDefaults()

        do {
            // 1. Load project data (fast, ~17ms)
            if let projectId = projectId {
                try await loadProject(projectId)
            }
        } catch {
            viewModel.error = error.localizedDescription
        }

        // Show the UI immediately — entries, text, etc. are ready
        viewModel.isLoading = false

        // 2. Load voices, cloned profiles, and audio in parallel (slow, ~1.8s total)
        // These don't block the main content from rendering
        async let voicesTask: () = loadVoices()
        async let cloneTask: () = loadClonedVoiceProfiles()
        _ = await (voicesTask, cloneTask)

        // 2.5. Apply default clone profile if none selected
        let defaultProfileId = UserDefaults.standard.string(forKey: SettingsPresenter.defaultCloneProfileIdKey) ?? ""
        if viewModel.selectedClonedVoiceId == nil,
           !defaultProfileId.isEmpty,
           viewModel.savedClonedVoices.contains(where: { $0.id == defaultProfileId }) {
            selectClonedVoiceProfile(id: defaultProfileId)
        }

        // 3. Load audio player if needed
        if viewModel.hasAudio {
            await loadAudio()
        }
    }

    /// Llamado cuando la vista desaparece
    func onDisappear() async {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        stopUpdateTimer()
        await stopPlayback()
        viewModel.playingEntryId = nil
        viewModel.currentPlayingIndex = -1

        // Release heavy data to free memory when navigating away
        viewModel.entries = []
        viewModel.waveformSamples = []
        viewModel.entryTexts = [:]
        viewModel.audioPath = nil
        await ThumbnailCache.shared.clear()
    }

    // MARK: - User Actions

    /// Actualiza el texto del proyecto
    func updateText(_ text: String) {
        viewModel.text = text
        updateEstimatedDuration()
        scheduleAutoSave()
    }

    /// Actualiza el nombre del proyecto
    func updateName(_ name: String) {
        viewModel.name = name
        scheduleAutoSave()
    }

    // MARK: - Entry Tab Actions

    /// Selects an entry tab (nil = project text)
    func selectEntryTab(_ entryId: String?) {
        viewModel.selectedEntryTab = entryId
    }

    /// Updates the text of a specific entry (local cache + auto-save)
    func updateEntryText(entryId: String, text: String) {
        viewModel.entryTexts[entryId] = text
        scheduleAutoSave()
    }

    /// Creates a new empty entry and selects its tab
    func addNewEntry() async {
        do {
            // Ensure project is saved
            if viewModel.isNewProject {
                try await createProject()
            }

            guard let projectIdString = viewModel.projectId,
                  let uuid = UUID(uuidString: projectIdString) else {
                throw ApplicationError.projectNotFound
            }

            let projectId = Identifier<Project>(uuid)

            // Save a new text-only entry
            let request = SaveAudioEntryRequest(
                projectId: projectId,
                text: "New entry"
            )
            let response = try await saveAudioEntryUseCase.execute(request)

            // Reload entries
            try await reloadEntries(projectId)

            // Select the new entry tab
            viewModel.selectedEntryTab = response.entryId

        } catch {
            print("[EditorPresenter] addNewEntry failed: \(error)")
            viewModel.error = error.localizedDescription
        }
    }

    /// Deletes an entry and selects an adjacent tab
    func deleteEntry(id: String) async {
        guard let projectIdString = viewModel.projectId,
              let projectUUID = UUID(uuidString: projectIdString) else { return }

        // Find the entry index before deletion for tab selection
        let currentIndex = viewModel.entries.firstIndex(where: { $0.id == id })

        do {
            let projectId = Identifier<Project>(projectUUID)

            // Delete via UpdateProjectUseCase
            let request = UpdateProjectRequest(
                projectId: projectId,
                entriesToDelete: [id]
            )
            _ = try await updateProjectUseCase.execute(request)

            // Remove from local cache
            viewModel.entryTexts.removeValue(forKey: id)

            // Reload entries
            try await reloadEntries(projectId)

            // Select adjacent tab
            if viewModel.selectedEntryTab == id {
                if let idx = currentIndex {
                    if idx > 0 && !viewModel.entries.isEmpty {
                        viewModel.selectedEntryTab = viewModel.entries[min(idx - 1, viewModel.entries.count - 1)].id
                    } else if !viewModel.entries.isEmpty {
                        viewModel.selectedEntryTab = viewModel.entries[0].id
                    } else {
                        viewModel.selectedEntryTab = nil
                    }
                } else {
                    viewModel.selectedEntryTab = nil
                }
            }

        } catch {
            print("[EditorPresenter] deleteEntry failed: \(error)")
            viewModel.error = error.localizedDescription
        }
    }

    /// Toggles the read status of an entry and persists the change
    func toggleEntryRead(id: String) async {
        guard let projectIdString = viewModel.projectId,
              let projectUUID = UUID(uuidString: projectIdString) else { return }

        do {
            let projectId = Identifier<Project>(projectUUID)
            let request = UpdateProjectRequest(
                projectId: projectId,
                entryReadToggles: [id]
            )
            _ = try await updateProjectUseCase.execute(request)
            try await reloadEntries(projectId)
        } catch {
            print("[EditorPresenter] toggleEntryRead failed: \(error)")
            viewModel.error = error.localizedDescription
        }
    }

    /// Switches the active TTS provider (called from in-project picker)
    func switchProvider(to rawValue: String) {
        guard let provider = Voice.TTSProvider(rawValue: rawValue) else { return }
        Task { await ttsCoordinator?.switchProvider(to: provider) }
    }

    /// Selecciona una voz
    func selectVoice(_ voiceId: String) {
        viewModel.selectedVoiceId = voiceId
        
        // Reset VoiceDesign and Clone modes when selecting a standard voice
        // to avoid them overriding the speaker selection in buildCurrentVoiceConfiguration
        viewModel.selectedAccent = ""
        viewModel.isCloneMode = false
        viewModel.voiceDesignCustom = ""
        
        scheduleAutoSave()
    }

    /// Actualiza la velocidad
    func updateSpeed(_ speed: Double) {
        viewModel.speed = speed
        scheduleAutoSave()
    }

    /// Guarda el proyecto (crea o actualiza)
    func save() async {
        print("[EditorPresenter] save() called - isNewProject: \(viewModel.isNewProject)")
        viewModel.isLoading = true
        viewModel.error = nil

        do {
            if viewModel.isNewProject {
                // Crear nuevo proyecto
                print("[EditorPresenter] Creating new project...")
                try await createProject()
                print("[EditorPresenter] Project created with ID: \(viewModel.projectId ?? "nil")")
            } else {
                // Actualizar proyecto existente
                print("[EditorPresenter] Updating existing project: \(viewModel.projectId ?? "nil")")
                try await updateProject()
                print("[EditorPresenter] Project updated")
            }
            // Mostrar éxito
            viewModel.showSaveSuccess = true
        } catch {
            print("[EditorPresenter] Save failed: \(error)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isLoading = false
    }

    /// Launches audio generation via GenerationManager.
    /// Call this from the UI instead of generateAudio() directly.
    func startGeneration() {
        let projectName = viewModel.name.isEmpty ? "Untitled" : viewModel.name
        generationManager.startJob(type: .projectText, projectName: projectName) { [weak self] job in
            await self?.generateAudio(job: job)
        }
    }

    /// Launches audio generation for a specific entry via GenerationManager.
    func startGenerationForEntry(id: String) {
        let projectName = viewModel.name.isEmpty ? "Untitled" : viewModel.name
        generationManager.startJob(type: .entry, projectName: projectName) { [weak self] job in
            await self?.generateAudioForEntry(id: id, job: job)
        }
    }

    /// Launches batch audio generation for all entries that don't have audio yet.
    func startGenerationForMissingEntries() {
        let entriesWithoutAudio = viewModel.entries.filter { !$0.hasAudio }
        guard !entriesWithoutAudio.isEmpty else { return }

        let projectName = viewModel.name.isEmpty ? "Untitled" : viewModel.name
        generationManager.startJob(type: .entryBatch, projectName: projectName) { [weak self] job in
            await self?.generateAudioForMissingEntries(entries: entriesWithoutAudio, job: job)
        }
    }

    /// Genera audio y lo guarda como nueva AudioEntry en el proyecto
    private func generateAudio(job: GenerationJob) async {
        viewModel.error = nil
        job.status = .preparing
        job.appendLog("Preparing project...")

        do {
            // 1. Asegurar que el proyecto está guardado
            if viewModel.isNewProject {
                print("[EditorPresenter] Creating project before generating audio...")
                try await createProject()
            } else {
                print("[EditorPresenter] Saving pending changes before generating audio...")
                try await updateProject()
            }

            guard let projectIdString = viewModel.projectId,
                  let uuid = UUID(uuidString: projectIdString) else {
                throw ApplicationError.projectNotFound
            }

            let projectId = Identifier<Project>(uuid)

            // 2. Construir objetos de dominio desde el viewModel
            let textContent = try TextContent(viewModel.text)
            let (voiceConfig, voice) = try buildCurrentVoiceConfiguration()

            // 3. Check cancellation before expensive TTS call
            try Task.checkCancellation()

            // 4. Sintetizar audio via TTS
            job.status = .processing
            job.statusMessage = "Synthesizing audio..."
            job.appendLog("Synthesizing audio...")
            print("[EditorPresenter] Synthesizing audio for project: \(projectIdString)")
            let audioData = try await ttsPort.synthesize(
                text: textContent,
                voiceConfiguration: voiceConfig,
                voice: voice
            )

            // 5. Check cancellation before saving
            try Task.checkCancellation()

            // 6. Guardar como nueva entrada usando SaveAudioEntryUseCase
            job.status = .finalizing
            job.statusMessage = "Saving audio entry..."
            job.appendLog("Saving audio entry...")
            let entryRequest = SaveAudioEntryRequest(
                projectId: projectId,
                text: viewModel.text,
                audioData: audioData.data,
                audioDuration: audioData.duration
            )
            let entryResponse = try await saveAudioEntryUseCase.execute(entryRequest)
            print("[EditorPresenter] Entry saved: \(entryResponse.entryId), audio: \(entryResponse.audioPath)")

            // 7. Recargar entries del proyecto para mantener sync con persistencia
            try await reloadEntries(projectId)

            // 8. Mostrar éxito
            let duration = audioData.duration
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            viewModel.generatedAudioDuration = String(format: "%d:%02d", minutes, seconds)
            viewModel.showAudioGeneratedSuccess = true

            job.status = .completed
            job.statusMessage = "Audio generated successfully"
            job.appendLog("Audio generated (\(minutes):\(String(format: "%02d", seconds)))", level: .success)

        } catch is CancellationError {
            print("[EditorPresenter] Generate audio cancelled")
            job.status = .cancelled
        } catch {
            print("[EditorPresenter] Generate audio failed: \(error)")
            viewModel.error = error.localizedDescription
            job.status = .failed
            job.errorMessage = error.localizedDescription
            job.appendLog("Error: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Screen Capture

    /// Captura una región de pantalla, ejecuta OCR y guarda como AudioEntry
    func captureScreen() async {
        viewModel.isCapturing = true
        viewModel.error = nil

        do {
            // 1. Asegurar que el proyecto está guardado
            if viewModel.isNewProject {
                try await createProject()
            }

            guard let projectIdString = viewModel.projectId,
                  let uuid = UUID(uuidString: projectIdString) else {
                throw ApplicationError.projectNotFound
            }

            let projectId = Identifier<Project>(uuid)

            // 2. Ejecutar captura + OCR + guardar
            let request = CaptureAndProcessRequest(
                projectId: projectId,
                generateAudio: false
            )

            let response = try await captureAndProcessUseCase.execute(request)

            // 3. Actualizar texto en el editor con el texto reconocido
            viewModel.text = response.recognizedText
            updateEstimatedDuration()

            // 4. Recargar entries del proyecto
            try await reloadEntries(projectId)

            print("[EditorPresenter] Screen capture OCR completed: \(response.recognizedText.prefix(50))...")

        } catch let error as ScreenCaptureError where error == .userCancelled {
            // El usuario canceló la captura - no es un error
            print("[EditorPresenter] Screen capture cancelled by user")
        } catch {
            print("[EditorPresenter] Screen capture failed: \(error)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isCapturing = false
    }

    // MARK: - Batch Image Import

    /// Abre un panel de selección de imágenes, ejecuta OCR en lote y guarda como AudioEntries
    /// Intenta generar audio automáticamente con Kokoro TTS
    func importImages() async {
        // 1. Open file picker
        let imageURLs = openImagePicker()
        guard !imageURLs.isEmpty else { return }

        viewModel.isImportingImages = true
        viewModel.importProgress = (0, imageURLs.count)
        viewModel.error = nil

        do {
            // 2. Ensure project is saved
            if viewModel.isNewProject {
                try await createProject()
            }

            guard let projectIdString = viewModel.projectId,
                  let uuid = UUID(uuidString: projectIdString) else {
                throw ApplicationError.projectNotFound
            }

            let projectId = Identifier<Project>(uuid)

            // Remember existing entry count to find new ones later
            let existingEntryCount = viewModel.entries.count

            // 3. Build voice configuration from current settings (including VoiceDesign)
            var voiceConfig: VoiceConfiguration? = nil
            var selectedVoice: Voice? = nil

            if viewModel.selectedVoiceId != nil {
                let result = try buildCurrentVoiceConfiguration()
                voiceConfig = result.voiceConfig
                selectedVoice = result.voice
            }

            // 4. Process batch with audio generation enabled (only if voice is configured)
            let request = ProcessImageBatchRequest(
                projectId: projectId,
                imageURLs: imageURLs,
                generateAudio: voiceConfig != nil && selectedVoice != nil,
                voiceConfiguration: voiceConfig,
                voice: selectedVoice,
                onProgress: { [weak self] current, total in
                    Task { @MainActor [weak self] in
                        self?.viewModel.importProgress = (current, total)
                    }
                }
            )

            let response = try await processImageBatchUseCase.execute(request)

            // 6. Reload entries
            try await reloadEntries(projectId)

            // 6.5. Auto-select the first newly imported entry tab
            if viewModel.entries.count > existingEntryCount {
                viewModel.selectedEntryTab = viewModel.entries[existingEntryCount].id
            }

            // 7. Update text with last recognized text
            if let lastEntry = response.successfulEntries.last {
                viewModel.text = lastEntry.recognizedText
                updateEstimatedDuration()
            }

            // 8. Show result with audio generation info
            var resultMessage = "Imported \(response.successCount) image(s)"
            if response.entriesWithAudio > 0 {
                resultMessage += " with \(response.entriesWithAudio) audio(s) generated"
            }
            if response.entriesWithoutAudio > 0 {
                resultMessage += ". \(response.entriesWithoutAudio) without audio"
            }
            if response.failureCount > 0 {
                resultMessage += ". \(response.failureCount) failed"
            }
            resultMessage += "."

            viewModel.importResult = resultMessage
            viewModel.showImportResult = true

        } catch {
            print("[EditorPresenter] Import images failed: \(error)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isImportingImages = false
    }

    // MARK: - Document Import

    /// Abre un panel de selección de documento PDF/EPUB, extrae texto por secciones y crea AudioEntries
    func importDocument() async {
        // 1. Open file picker
        guard let documentURL = openDocumentPicker() else { return }

        viewModel.isImportingImages = true
        viewModel.importProgress = (0, 1)
        viewModel.error = nil

        do {
            // 2. Ensure project is saved
            if viewModel.isNewProject {
                try await createProject()
            }

            guard let projectIdString = viewModel.projectId,
                  let uuid = UUID(uuidString: projectIdString) else {
                throw ApplicationError.projectNotFound
            }

            let projectId = Identifier<Project>(uuid)

            // 3. Process document
            let request = ProcessDocumentRequest(
                projectId: projectId,
                documentURL: documentURL,
                onProgress: { [weak self] current, total in
                    Task { @MainActor [weak self] in
                        self?.viewModel.importProgress = (current, total)
                    }
                }
            )

            let response = try await processDocumentUseCase.execute(request)

            // 4. Reload entries
            try await reloadEntries(projectId)

            // 5. Show result
            if response.failureCount == 0 {
                viewModel.importResult = "Successfully imported \(response.successCount) section(s) from \(response.documentType)."
            } else {
                viewModel.importResult = "Imported \(response.successCount) of \(response.totalSections) sections from \(response.documentType). \(response.failureCount) failed."
            }
            viewModel.showImportResult = true

        } catch {
            print("[EditorPresenter] Import document failed: \(error)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isImportingImages = false
    }

    /// Abre NSOpenPanel para seleccionar un documento PDF o EPUB
    private func openDocumentPicker() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.pdf,
            UTType(filenameExtension: "epub") ?? UTType.data,
        ]
        panel.message = "Select a PDF or EPUB document to import"
        panel.prompt = "Import"

        let result = panel.runModal()
        guard result == .OK else { return nil }
        return panel.url
    }

    /// Abre NSOpenPanel para seleccionar imágenes
    private func openImagePicker() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType.tiff,
            UTType.bmp,
        ]
        panel.message = "Select images to import with OCR"
        panel.prompt = "Import"

        let result = panel.runModal()
        guard result == .OK else { return [] }
        return panel.urls
    }

    // MARK: - Playback Controls

    /// Carga el audio del proyecto en el reproductor
    func loadAudio() async {
        guard let audioPath = viewModel.audioPath, !audioPath.isEmpty else { return }

        do {
            // Construir path completo usando URL para correctness
            let baseURL = URL(fileURLWithPath: audioStorage.baseDirectory, isDirectory: true)
            let fullURL = baseURL.appendingPathComponent(audioPath)
            let fullPath = fullURL.path

            try await audioPlayer.load(path: fullPath)
            viewModel.audioDuration = audioPlayer.duration

            // Generar waveform
            let samples = try await audioPlayer.generateWaveformSamples(sampleCount: 200)
            viewModel.waveformSamples = samples

            // Iniciar timer de actualización
            startUpdateTimer()
        } catch {
            print("[EditorPresenter] Failed to load audio: \(error)")
        }
    }

    /// Inicia la reproducción
    func play() async {
        await audioPlayer.play()
        updatePlaybackState()
        startUpdateTimer()
    }

    /// Pausa la reproducción
    func pause() async {
        stopUpdateTimer()
        await audioPlayer.pause()
        updatePlaybackState()
    }

    /// Toggle play/pause
    func togglePlayPause() async {
        if viewModel.isPlaying {
            await pause()
        } else {
            await play()
        }
    }

    /// Busca a una posición específica (0.0 - 1.0)
    func seek(to progress: Double) async {
        let clampedProgress = max(0, min(1.0, progress))
        let targetTime = clampedProgress * viewModel.audioDuration
        await audioPlayer.seek(to: targetTime)
        updatePlaybackState()
    }

    /// Salta 10 segundos hacia atrás
    func skipBackward() async {
        let newTime = max(0, viewModel.currentTime - skipInterval)
        await audioPlayer.seek(to: newTime)
        updatePlaybackState()
    }

    /// Salta 10 segundos hacia adelante
    func skipForward() async {
        let newTime = min(viewModel.audioDuration, viewModel.currentTime + skipInterval)
        await audioPlayer.seek(to: newTime)
        updatePlaybackState()
    }

    /// Configura la velocidad de reproducción
    func setPlaybackSpeed(_ speed: Float) async {
        let clampedSpeed = max(0.5, min(2.0, speed))
        await audioPlayer.setRate(clampedSpeed)
        viewModel.playbackSpeed = audioPlayer.rate
    }

    /// Detiene la reproducción y limpia estado
    func stopPlayback() async {
        stopUpdateTimer()
        await audioPlayer.stop()
        viewModel.isPlaying = false
        viewModel.currentTime = 0
    }

    // MARK: - Entry Playback

    /// Reproduce audio de un entry específico
    func playEntry(id: String) async {
        guard let entryIndex = viewModel.entries.firstIndex(where: { $0.id == id }),
              let audioPath = viewModel.entries[entryIndex].audioPath else { return }

        // Detener reproducción actual si hay
        await stopPlayback()

        // Marcar entry como reproduciéndose y guardar índice
        viewModel.playingEntryId = id
        viewModel.currentPlayingIndex = entryIndex

        // Construir path completo
        let baseURL = URL(fileURLWithPath: audioStorage.baseDirectory, isDirectory: true)
        let fullURL = baseURL.appendingPathComponent(audioPath)
        let fullPath = fullURL.path

        do {
            try await audioPlayer.load(path: fullPath)
            viewModel.audioDuration = audioPlayer.duration

            let samples = try await audioPlayer.generateWaveformSamples(sampleCount: 200)
            viewModel.waveformSamples = samples
            startUpdateTimer()
            await audioPlayer.play()
            updatePlaybackState()
        } catch {
            print("[EditorPresenter] Failed to play entry: \(error)")
            viewModel.playingEntryId = nil
            viewModel.currentPlayingIndex = -1
        }
    }

    /// Detiene la reproducción del entry actual
    func stopEntry() async {
        await stopPlayback()
        // No limpiamos el ID para que la UI se mantenga visible
        // viewModel.playingEntryId = nil
        // viewModel.currentPlayingIndex = -1
    }

    // MARK: - Auto-Play Controls

    /// Activa/desactiva el modo auto-play
    func toggleAutoPlay() {
        viewModel.isAutoPlayEnabled.toggle()
        print("[EditorPresenter] Auto-play \(viewModel.isAutoPlayEnabled ? "enabled" : "disabled")")
    }

    /// Reproduce el siguiente entry con audio
    func playNext() async {
        // Buscar el siguiente entry con audio (a partir del siguiente índice, o desde 0 si no hay ninguno reproduciéndose)
        let nextIndex = findNextEntryWithAudio(from: viewModel.currentPlayingIndex + 1)

        if let nextIndex = nextIndex {
            let entry = viewModel.entries[nextIndex]
            await playEntry(id: entry.id)
        } else {
            // No hay más entries con audio, detener la reproducción pero mantener la UI visible
            await stopPlayback()
        }
    }

    /// Reproduce el entry anterior con audio
    func playPrevious() async {
        guard viewModel.currentPlayingIndex >= 0 else { return }

        if viewModel.currentPlayingIndex == 0 {
            // Si estamos en el primero, reiniciar el actual
            await audioPlayer.seek(to: 0)
            updatePlaybackState()
            return
        }

        // Buscar el entry anterior con audio
        let prevIndex = findPreviousEntryWithAudio(from: viewModel.currentPlayingIndex - 1)

        if let prevIndex = prevIndex {
            let entry = viewModel.entries[prevIndex]
            await playEntry(id: entry.id)
        } else {
            // No hay entries anteriores con audio, reiniciar el actual
            await audioPlayer.seek(to: 0)
            updatePlaybackState()
        }
    }

    /// Maneja la finalización de reproducción (llamado por el callback del AudioPlayer)
    func handlePlaybackCompletion() async {
        print("[EditorPresenter] Playback completed, autoPlay: \(viewModel.isAutoPlayEnabled)")

        if viewModel.isAutoPlayEnabled {
            await playNext()
        } else {
            await stopPlayback()
        }
    }

    // MARK: - Private Auto-Play Helpers

    /// Encuentra el siguiente entry con audio a partir del índice dado
    private func findNextEntryWithAudio(from startIndex: Int) -> Int? {
        for i in startIndex..<viewModel.entries.count {
            if viewModel.entries[i].audioPath != nil {
                return i
            }
        }
        return nil
    }

    /// Encuentra el entry anterior con audio a partir del índice dado
    private func findPreviousEntryWithAudio(from startIndex: Int) -> Int? {
        for i in stride(from: startIndex, through: 0, by: -1) {
            if viewModel.entries[i].audioPath != nil {
                return i
            }
        }
        return nil
    }

    /// Genera audio para un entry que no tiene audio
    /// - Parameter id: ID del entry (formato string del EntryId)
    private func generateAudioForEntry(id: String, job: GenerationJob) async {
        guard let projectIdString = viewModel.projectId,
              let projectUUID = UUID(uuidString: projectIdString) else {
            viewModel.error = "Proyecto no encontrado"
            job.status = .failed
            job.errorMessage = "Proyecto no encontrado"
            return
        }

        guard let entryIdUUID = UUID(uuidString: id) else {
            viewModel.error = "ID de entrada inválido"
            job.status = .failed
            job.errorMessage = "ID de entrada inválido"
            return
        }

        viewModel.error = nil
        job.status = .preparing
        job.appendLog("Preparing entry generation...")

        do {
            // Build full voice configuration (including VoiceDesign accent/gender/emotion)
            let (voiceConfig, selectedVoice) = try buildCurrentVoiceConfiguration()

            // Check cancellation before expensive TTS call
            try Task.checkCancellation()

            job.status = .processing
            job.statusMessage = "Synthesizing audio for entry..."
            job.appendLog("Synthesizing audio...")
            print("[EditorPresenter] generateAudioForEntry: id=\(id)")

            let request = GenerateAudioForEntryRequest(
                projectId: Identifier<Project>(projectUUID),
                entryId: EntryId(entryIdUUID),
                voiceConfiguration: voiceConfig,
                voice: selectedVoice
            )

            let response = try await generateAudioForEntryUseCase.execute(request)

            // Reload entries to reflect the new audio
            try await reloadEntries(Identifier<Project>(projectUUID))

            print("[EditorPresenter] Audio generated for entry \(id): \(response.audioPath)")

            job.status = .completed
            job.statusMessage = "Audio generated for entry"
            job.appendLog("Audio generated for entry", level: .success)

        } catch is CancellationError {
            print("[EditorPresenter] Generate audio for entry cancelled")
            job.status = .cancelled
        } catch {
            print("[EditorPresenter] Generate audio for entry failed: \(error)")
            viewModel.error = error.localizedDescription
            job.status = .failed
            job.errorMessage = error.localizedDescription
            job.appendLog("Error: \(error.localizedDescription)", level: .error)
        }
    }

    /// Genera audio para todas las entries que no tienen audio
    private func generateAudioForMissingEntries(entries: [AudioEntryDTO], job: GenerationJob) async {
        guard let projectIdString = viewModel.projectId,
              let projectUUID = UUID(uuidString: projectIdString) else {
            job.status = .failed
            job.errorMessage = "Proyecto no encontrado"
            return
        }

        let total = entries.count
        job.status = .preparing
        job.statusMessage = "Preparing batch generation (\(total) entries)..."
        job.appendLog("Starting batch generation for \(total) entries without audio")

        do {
            let (voiceConfig, selectedVoice) = try buildCurrentVoiceConfiguration()

            var completed = 0
            var failed = 0

            for entry in entries {
                try Task.checkCancellation()

                guard let entryUUID = UUID(uuidString: entry.id) else {
                    failed += 1
                    job.appendLog("Skipped entry \(entry.formattedNumber): invalid ID", level: .warning)
                    continue
                }

                job.status = .processing
                job.statusMessage = "Generating \(completed + 1)/\(total) — Entry \(entry.formattedNumber)..."
                job.progress = Double(completed) / Double(total)
                job.appendLog("Generating audio for entry \(entry.formattedNumber)...")

                do {
                    let request = GenerateAudioForEntryRequest(
                        projectId: Identifier<Project>(projectUUID),
                        entryId: EntryId(entryUUID),
                        voiceConfiguration: voiceConfig,
                        voice: selectedVoice
                    )
                    _ = try await generateAudioForEntryUseCase.execute(request)
                    completed += 1
                    job.appendLog("Entry \(entry.formattedNumber) done", level: .success)
                } catch {
                    failed += 1
                    job.appendLog("Entry \(entry.formattedNumber) failed: \(error.localizedDescription)", level: .error)
                }
            }

            // Reload entries to reflect all new audio
            try await reloadEntries(Identifier<Project>(projectUUID))

            job.progress = 1.0
            job.status = .completed
            job.statusMessage = "Batch complete: \(completed) generated, \(failed) failed"
            job.appendLog("Batch generation finished: \(completed)/\(total) successful", level: .success)

        } catch is CancellationError {
            print("[EditorPresenter] Batch generation cancelled")
            // Reload to show entries that were generated before cancellation
            if let projectUUID = UUID(uuidString: projectIdString) {
                try? await reloadEntries(Identifier<Project>(projectUUID))
            }
            job.status = .cancelled
        } catch {
            viewModel.error = error.localizedDescription
            job.status = .failed
            job.errorMessage = error.localizedDescription
            job.appendLog("Batch generation error: \(error.localizedDescription)", level: .error)
        }
    }

    /// Cancels the in-progress audio generation.
    func cancelGeneration() {
        generationManager.cancelCurrentJob()
    }

    /// Actualiza el estado de reproducción desde el AudioPlayer
    func updatePlaybackState() {
        let newTime = audioPlayer.currentTime
        let newPlaying = audioPlayer.isPlaying
        // Only update @Published properties if values actually changed
        // to avoid unnecessary SwiftUI re-renders
        if abs(viewModel.currentTime - newTime) > 0.05 {
            viewModel.currentTime = newTime
        }
        if viewModel.isPlaying != newPlaying {
            viewModel.isPlaying = newPlaying
        }
    }

    // MARK: - Transcription

    /// Transcribes the selected reference audio to text using mlx-whisper
    func transcribeReferenceAudio() async {
        guard let audioURL = viewModel.referenceAudioURL else {
            viewModel.error = "No reference audio selected"
            return
        }

        guard let coordinator = ttsCoordinator else {
            viewModel.error = "TTS coordinator not available"
            return
        }

        viewModel.isTranscribing = true
        viewModel.error = nil

        do {
            let text = try await coordinator.transcribeAudio(url: audioURL)
            viewModel.referenceText = text
            print("[EditorPresenter] Transcription completed: \(text.prefix(80))...")
        } catch {
            print("[EditorPresenter] Transcription failed: \(error)")
            viewModel.error = "Transcription failed: \(error.localizedDescription)"
        }

        viewModel.isTranscribing = false
    }

    // MARK: - Cloned Voice Profiles

    /// Loads all saved cloned voice profiles
    func loadClonedVoiceProfiles() async {
        guard let repo = clonedVoiceRepository else { return }
        do {
            let profiles = try await repo.findAll()
            viewModel.savedClonedVoices = profiles.map { ClonedVoiceProfileDTO(from: $0) }
        } catch {
            print("[EditorPresenter] Failed to load cloned voice profiles: \(error)")
        }
    }

    /// Saves the current reference audio + text as a named profile
    func saveClonedVoiceProfile(name: String) async {
        guard let repo = clonedVoiceRepository else { return }
        guard let audioURL = viewModel.referenceAudioURL else {
            viewModel.error = "No reference audio selected"
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            viewModel.error = "Profile name cannot be empty"
            return
        }

        viewModel.isSavingCloneProfile = true

        do {
            let audioData = try Data(contentsOf: audioURL)
            let audioFileName = "reference.\(audioURL.pathExtension)"

            // Get duration
            let audioFile = try AVAudioFile(forReading: audioURL)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            let profile = ClonedVoiceProfile(
                id: UUID().uuidString,
                name: trimmedName,
                audioFileName: audioFileName,
                referenceText: viewModel.referenceText,
                audioDuration: duration,
                createdAt: Date()
            )

            try await repo.save(profile, audioData: audioData)
            await loadClonedVoiceProfiles()

            // Select the newly saved profile
            viewModel.selectedClonedVoiceId = profile.id

            print("[EditorPresenter] Saved cloned voice profile: \(trimmedName)")
        } catch {
            print("[EditorPresenter] Failed to save cloned voice profile: \(error)")
            viewModel.error = "Failed to save voice profile: \(error.localizedDescription)"
        }

        viewModel.isSavingCloneProfile = false
    }

    /// Selects a saved cloned voice profile, populating the reference audio + text
    func selectClonedVoiceProfile(id: String?) {
        guard let repo = clonedVoiceRepository else { return }

        viewModel.selectedClonedVoiceId = id

        guard let id = id else {
            // "New (manual)" selected - clear fields
            viewModel.referenceAudioURL = nil
            viewModel.referenceText = ""
            return
        }

        Task {
            guard let profile = try? await repo.findById(id) else { return }
            let audioURL = repo.audioURL(for: profile)
            viewModel.referenceAudioURL = audioURL
            viewModel.referenceText = profile.referenceText
            viewModel.isCloneMode = true
        }
    }

    /// Deletes a saved cloned voice profile
    func deleteClonedVoiceProfile(id: String) async {
        guard let repo = clonedVoiceRepository else { return }

        do {
            try await repo.delete(id)
            await loadClonedVoiceProfiles()

            // If the deleted profile was selected, clear selection
            if viewModel.selectedClonedVoiceId == id {
                viewModel.selectedClonedVoiceId = nil
                viewModel.referenceAudioURL = nil
                viewModel.referenceText = ""
            }

            print("[EditorPresenter] Deleted cloned voice profile: \(id)")
        } catch {
            print("[EditorPresenter] Failed to delete cloned voice profile: \(error)")
            viewModel.error = "Failed to delete voice profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Voice Configuration Builder

    /// Builds a full VoiceConfiguration from the current ViewModel state,
    /// including VoiceDesign accent/gender/emotion and voice cloning settings.
    /// This ensures ALL generation paths use the same config.
    private func buildCurrentVoiceConfiguration() throws -> (voiceConfig: VoiceConfiguration, voice: Voice) {
        guard let voiceId = viewModel.selectedVoiceId else {
            throw ApplicationError.audioGenerationFailed("No voice selected")
        }
        guard let voiceDTO = viewModel.availableVoices.first(where: { $0.id == voiceId }) else {
            throw ApplicationError.audioGenerationFailed("Selected voice not found")
        }

        let speed = try VoiceConfiguration.Speed(viewModel.speed)

        // Build instruct from emotion preset or custom text
        let instruct: String? = {
            if !viewModel.customInstruct.isEmpty {
                return viewModel.customInstruct
            }
            if viewModel.selectedEmotion != "neutral",
               let emotion = SpeechEmotion(rawValue: viewModel.selectedEmotion) {
                return emotion.instruct
            }
            return nil
        }()

        // Build voiceDesignInstruct + language if accent is selected
        let selectedAccent = VoiceAccent(rawValue: viewModel.selectedAccent)
        let voiceDesignInstruct: String?
        let voiceDesignLanguage: String?

        if let accent = selectedAccent {
            if !viewModel.voiceDesignCustom.isEmpty {
                voiceDesignInstruct = viewModel.voiceDesignCustom
            } else {
                let gender = VoiceGender(rawValue: viewModel.voiceDesignGender) ?? .female
                voiceDesignInstruct = accent.voiceDesignInstruct(gender: gender, style: instruct)
            }
            voiceDesignLanguage = accent.languageCode
        } else {
            voiceDesignInstruct = nil
            voiceDesignLanguage = nil
        }

        // VoiceDesign and Voice Cloning are mutually exclusive.
        // VoiceDesign uses its own model; cloning uses the Base model.
        // If both are enabled, Cloning takes priority (explicit user choice).
        let useCloning = viewModel.isCloneMode

        // Persist clone optimization settings
        UserDefaults.standard.set(viewModel.cloneFastMode, forKey: Self.cloneFastModeKey)
        UserDefaults.standard.set(viewModel.cloneFastModel, forKey: Self.cloneFastModelKey)

        let voiceConfig = VoiceConfiguration(
            voiceId: voiceId,
            speed: speed,
            instruct: instruct,
            referenceAudioURL: useCloning ? viewModel.referenceAudioURL : nil,
            referenceText: useCloning ? viewModel.referenceText : nil,
            voiceDesignInstruct: useCloning ? nil : voiceDesignInstruct,
            voiceDesignLanguage: useCloning ? nil : voiceDesignLanguage,
            cloneFastMode: useCloning ? viewModel.cloneFastMode : false,
            cloneFastModel: useCloning ? viewModel.cloneFastModel : false,
            cloneAccentInstruct: useCloning ? viewModel.cloneTargetAccent?.instruct : nil
        )

        let voice = Voice(
            id: voiceDTO.id,
            name: voiceDTO.name,
            language: voiceDTO.language,
            provider: Voice.TTSProvider(rawValue: voiceDTO.provider) ?? .native,
            isDefault: voiceDTO.isDefault
        )

        let mode = useCloning ? "clone" : (voiceDesignInstruct != nil ? "voice_design" : "custom_voice")
        print("[EditorPresenter] VoiceConfig built: mode=\(mode), accent=\(viewModel.selectedAccent.isEmpty ? "none" : viewModel.selectedAccent), gender=\(viewModel.voiceDesignGender), emotion=\(viewModel.selectedEmotion), voiceDesignInstruct=\(voiceDesignInstruct?.prefix(80) ?? "nil"), voiceDesignLanguage=\(voiceDesignLanguage ?? "nil"), instruct=\(instruct ?? "nil")")

        return (voiceConfig, voice)
    }

    // Generation tracking is now handled by GenerationManager

    // MARK: - Private Methods

    /// Applies all persisted voice defaults from UserDefaults to the viewModel.
    /// Called from init() and onAppear() so defaults are always fresh.
    private func applyPersistedDefaults() {
        // Clone optimization settings
        viewModel.cloneFastMode = UserDefaults.standard.bool(forKey: Self.cloneFastModeKey)
        viewModel.cloneFastModel = UserDefaults.standard.bool(forKey: Self.cloneFastModelKey)

        // Qwen3 voice defaults
        if let accent = UserDefaults.standard.string(forKey: SettingsPresenter.defaultQwen3AccentKey) {
            viewModel.selectedAccent = accent
        }
        if let emotion = UserDefaults.standard.string(forKey: SettingsPresenter.defaultQwen3EmotionKey) {
            viewModel.selectedEmotion = emotion
        }
        if let gender = UserDefaults.standard.string(forKey: SettingsPresenter.defaultQwen3GenderKey) {
            viewModel.voiceDesignGender = gender
        }

        // Clone defaults
        viewModel.isCloneMode = UserDefaults.standard.bool(forKey: SettingsPresenter.defaultCloneEnabledKey)
        if let cloneAccent = UserDefaults.standard.string(forKey: SettingsPresenter.defaultCloneAccentKey),
           !cloneAccent.isEmpty,
           let accent = CloneTargetAccent(rawValue: cloneAccent) {
            viewModel.cloneTargetAccent = accent
        }
    }

    // MARK: - Auto-Save

    /// Schedules auto-save with debounce
    /// Resets timer on each call, saves when timer expires
    private func scheduleAutoSave() {
        // Cancel existing timer
        autoSaveTimer?.invalidate()

        // Only auto-save existing projects (not new ones without ID)
        guard !viewModel.isNewProject else { return }

        viewModel.autoSaveState = .pending

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performAutoSave()
            }
        }
    }

    /// Performs the actual auto-save
    private func performAutoSave() async {
        viewModel.autoSaveState = .saving

        do {
            try await updateProject()
            viewModel.autoSaveState = .saved

            // Reset to idle after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if viewModel.autoSaveState == .saved {
                viewModel.autoSaveState = .idle
            }
        } catch {
            viewModel.autoSaveState = .idle
            viewModel.error = error.localizedDescription
        }
    }

    /// Inicia el timer para actualizar el estado de reproducción
    private func startUpdateTimer() {
        stopUpdateTimer()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.audioPlayer.isPlaying {
                    if self.viewModel.isPlaying {
                        self.viewModel.isPlaying = false
                    }
                    self.stopUpdateTimer()
                    return
                }
                self.updatePlaybackState()
            }
        }
    }

    /// Detiene el timer de actualización
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Carga las voces disponibles del TTS Port
    private func loadVoices() async {
        let voices = await ttsPort.availableVoices()
        let dtos = voices.map { VoiceDTO(from: $0) }

        // Compute new selection BEFORE updating the voices list so that
        // both properties are consistent when SwiftUI renders.
        let currentExists = voices.contains(where: { $0.id == viewModel.selectedVoiceId })
        if viewModel.selectedVoiceId == nil || !currentExists {
            if let defaultVoice = voices.first(where: { $0.isDefault }) {
                viewModel.selectedVoiceId = defaultVoice.id
            } else if let firstVoice = voices.first {
                viewModel.selectedVoiceId = firstVoice.id
            }
        }

        // Update voices after selection so the Picker never renders with
        // a selectedId that doesn't match any tag in the list.
        viewModel.availableVoices = dtos
    }

    /// Carga un proyecto existente
    private func loadProject(_ projectId: Identifier<Project>) async throws {
        let request = GetProjectRequest(projectId: projectId)
        let response = try await getProjectUseCase.execute(request)

        viewModel.projectId = projectId.value.uuidString
        viewModel.folderName = response.folderName
        viewModel.name = response.name
        viewModel.text = response.text
        viewModel.selectedVoiceId = response.voiceId
        viewModel.speed = response.speed
        viewModel.audioPath = response.audioPath

        // Map entries to DTOs (con path completo de imagen para la UI)
        viewModel.entries = response.entries.enumerated().map { index, entry in
            AudioEntryDTO(from: entry, number: index + 1, storageBaseDirectory: audioStorage.baseDirectory)
        }

        // Populate entry texts cache
        viewModel.entryTexts = [:]
        for entry in viewModel.entries {
            viewModel.entryTexts[entry.id] = entry.fullText
        }

        updateEstimatedDuration()
    }

    /// Crea un nuevo proyecto
    private func createProject() async throws {
        let selectedVoice = viewModel.availableVoices.first(where: { $0.id == viewModel.selectedVoiceId })
        let request = CreateProjectRequest(
            text: viewModel.text,
            name: viewModel.name.isEmpty ? nil : viewModel.name,
            voiceId: viewModel.selectedVoiceId ?? "",
            voiceName: selectedVoice?.name ?? "",
            voiceLanguage: selectedVoice?.language ?? "",
            voiceProvider: Voice.TTSProvider(rawValue: selectedVoice?.provider ?? "native") ?? .native,
            speed: viewModel.speed
        )

        let response = try await createProjectUseCase.execute(request)
        viewModel.projectId = response.projectId.value.uuidString
        viewModel.folderName = response.folderName
    }

    /// Actualiza un proyecto existente
    private func updateProject() async throws {
        guard let projectIdString = viewModel.projectId,
              let uuid = UUID(uuidString: projectIdString) else {
            throw ApplicationError.projectNotFound
        }

        let projectId = Identifier<Project>(uuid)
        let selectedVoice = viewModel.availableVoices.first(where: { $0.id == viewModel.selectedVoiceId })

        // Collect entry text updates (only entries whose text differs from persisted)
        var entryTextUpdates: [String: String]? = nil
        if !viewModel.entryTexts.isEmpty {
            var updates: [String: String] = [:]
            for entry in viewModel.entries {
                if let editedText = viewModel.entryTexts[entry.id],
                   editedText != entry.fullText {
                    updates[entry.id] = editedText
                }
            }
            if !updates.isEmpty {
                entryTextUpdates = updates
            }
        }

        let request = UpdateProjectRequest(
            projectId: projectId,
            name: viewModel.name.isEmpty ? nil : viewModel.name,
            text: viewModel.text,
            voiceId: viewModel.selectedVoiceId,
            voiceName: selectedVoice?.name,
            voiceLanguage: selectedVoice?.language,
            voiceProvider: selectedVoice != nil ? Voice.TTSProvider(rawValue: selectedVoice!.provider) : nil,
            speed: viewModel.speed,
            entryTextUpdates: entryTextUpdates
        )

        let updateResponse = try await updateProjectUseCase.execute(request)
        viewModel.folderName = updateResponse.folderName

        // After save, update the entries DTOs to reflect saved texts
        if let updates = entryTextUpdates {
            for (entryId, newText) in updates {
                if let idx = viewModel.entries.firstIndex(where: { $0.id == entryId }) {
                    let old = viewModel.entries[idx]
                    viewModel.entries[idx] = AudioEntryDTO(
                        id: old.id,
                        number: old.number,
                        textPreview: String(newText.prefix(50)),
                        fullText: newText,
                        audioPath: nil, // text changed, audio invalidated
                        imagePath: old.imagePath,
                        imageFullPath: old.imageFullPath
                    )
                }
            }
        }
    }

    /// Recarga las entries del proyecto desde persistencia
    private func reloadEntries(_ projectId: Identifier<Project>) async throws {
        let request = GetProjectRequest(projectId: projectId)
        let response = try await getProjectUseCase.execute(request)
        viewModel.folderName = response.folderName
        viewModel.entries = response.entries.enumerated().map { index, entry in
            AudioEntryDTO(from: entry, number: index + 1, storageBaseDirectory: audioStorage.baseDirectory)
        }

        // Update entry texts cache with new/updated entries
        for entry in viewModel.entries {
            if viewModel.entryTexts[entry.id] == nil {
                viewModel.entryTexts[entry.id] = entry.fullText
            }
        }
    }

    /// Actualiza la duración estimada basada en el texto
    private func updateEstimatedDuration() {
        let wordCount = viewModel.text.split(separator: " ").count
        // ~150 palabras por minuto
        let seconds = Int(Double(wordCount) / 150.0 * 60.0)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        viewModel.estimatedDuration = String(format: "%d:%02d", minutes, remainingSeconds)
    }

    // MARK: - Finder

    /// Abre la carpeta del proyecto en Finder
    func showInFinder() {
        let folderName = viewModel.folderName ?? viewModel.projectId
        print("[EditorPresenter] showInFinder: folderName=\(viewModel.folderName ?? "nil"), projectId=\(viewModel.projectId ?? "nil"), resolved=\(folderName ?? "nil")")
        guard let folderName = folderName else {
            print("[EditorPresenter] showInFinder: no folderName or projectId, aborting")
            return
        }
        let projectDir = (audioStorage.baseDirectory as NSString)
            .appendingPathComponent(folderName)
        print("[EditorPresenter] showInFinder: opening \(projectDir), exists=\(FileManager.default.fileExists(atPath: projectDir))")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectDir)
    }

    // MARK: - Merge/Export

    /// Exporta/mergea el proyecto según el tipo seleccionado
    func mergeProject(type: MergeType) async {
        guard let mergeProjectUseCase = mergeProjectUseCase else {
            viewModel.error = "Exportación no disponible"
            return
        }

        guard let projectIdString = viewModel.projectId,
              let uuid = UUID(uuidString: projectIdString) else {
            viewModel.error = "Proyecto no encontrado"
            return
        }

        viewModel.isMerging = true
        viewModel.error = nil

        do {
            let projectId = Identifier<Project>(uuid)
            let request = MergeProjectRequest(
                projectId: projectId,
                mergeType: type,
                silenceBetweenAudios: 0.5
            )

            let response = try await mergeProjectUseCase.execute(request)

            viewModel.mergeResult = response
            viewModel.showMergeResult = true

            print("[EditorPresenter] Merge completed: \(response.exportsDirectory)")

        } catch {
            print("[EditorPresenter] Merge failed: \(error)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isMerging = false
    }

    // MARK: - Text Batch Import

    /// Procesa un lote de texto dividiéndolo en fragmentos y creando AudioEntries
    func processTextBatch(text: String, splitMode: TextSplitMode, generateAudio: Bool) async {
        guard let processTextBatchUseCase = processTextBatchUseCase else {
            viewModel.error = "Importación de texto no disponible"
            return
        }

        guard let projectIdString = viewModel.projectId,
              let uuid = UUID(uuidString: projectIdString) else {
            viewModel.error = "Proyecto no encontrado"
            return
        }

        viewModel.isImportingImages = true
        viewModel.importProgress = (0, 1)
        viewModel.error = nil

        do {
            // Ensure project is saved first
            if viewModel.isNewProject {
                try await createProject()
            }

            let projectId = Identifier<Project>(uuid)

            // Build voice configuration from current settings (including VoiceDesign)
            var voiceConfig: VoiceConfiguration? = nil
            var selectedVoice: Voice? = nil

            if generateAudio, viewModel.selectedVoiceId != nil {
                let result = try buildCurrentVoiceConfiguration()
                voiceConfig = result.voiceConfig
                selectedVoice = result.voice
            }

            let request = ProcessTextBatchRequest(
                projectId: projectId,
                text: text,
                splitMode: splitMode,
                generateAudio: generateAudio,
                voiceConfiguration: voiceConfig,
                voice: selectedVoice,
                onProgress: { [weak self] current, total in
                    Task { @MainActor [weak self] in
                        self?.viewModel.importProgress = (current, total)
                    }
                }
            )

            let response = try await processTextBatchUseCase.execute(request)

            // Reload entries
            try await reloadEntries(projectId)

            // Show result
            var resultMessage = "Imported \(response.entriesCreated) text fragment(s)"
            if response.entriesWithAudio > 0 {
                resultMessage += " with \(response.entriesWithAudio) audio(s) generated"
            }
            if response.failureCount > 0 {
                resultMessage += ". \(response.failureCount) failed"
            }
            resultMessage += "."

            viewModel.importResult = resultMessage
            viewModel.showImportResult = true

            print("[EditorPresenter] Text batch processed: \(response.entriesCreated) entries")

        } catch {
            print("[EditorPresenter] Text batch import failed: \(error)")
            viewModel.error = error.localizedDescription
        }

        viewModel.isImportingImages = false
    }
}
