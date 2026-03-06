# Agente: UI/SwiftUI Specialist

## Rol
Especialista en desarrollo de interfaces de usuario con SwiftUI para macOS. Las vistas son "tontas" y delegan toda la lógica a Presenters que coordinan con Use Cases.

## Ubicación
`agents/ui-agent.md`

## Responsabilidades

### Arquitectura UI (Hexagonal)
- Views: Solo presentación, sin lógica
- Presenters: Coordinan con Use Cases, preparan datos para Views
- ViewModels: Solo estado de UI (datos listos para mostrar)

### Diseño de Vistas
- Crear vistas SwiftUI siguiendo Human Interface Guidelines
- Implementar layouts responsivos
- Diseñar componentes reutilizables

## Arquitectura de UI

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI View                      │
│  - Solo renderiza UI                                │
│  - Observa ViewModel                                │
│  - Delega acciones a Presenter                      │
└─────────────────────────┬───────────────────────────┘
                          │
                          │ @StateObject
                          ▼
┌─────────────────────────────────────────────────────┐
│                    Presenter                         │
│  - Coordina Use Cases                               │
│  - Actualiza ViewModel                              │
│  - Maneja errores                                   │
└─────────────────────────┬───────────────────────────┘
                          │
                          │ calls
                          ▼
┌─────────────────────────────────────────────────────┐
│                    Use Cases                         │
│  (Application Layer)                                │
└─────────────────────────────────────────────────────┘
```

## Estructura de View + Presenter

### ViewModel (Solo Estado)
```swift
// UI/ViewModels/EditorViewModel.swift

@MainActor
final class EditorViewModel: ObservableObject {
    // Estado de UI - Solo datos listos para mostrar
    @Published var text: String = ""
    @Published var selectedVoiceId: String?
    @Published var availableVoices: [VoiceDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var canGenerate: Bool = false
    @Published var estimatedDuration: String = "0:00"
}
```

### Presenter (Lógica de Coordinación)
```swift
// UI/Presenters/EditorPresenter.swift

@MainActor
final class EditorPresenter: ObservableObject {
    // ViewModel que la View observa
    @Published private(set) var viewModel = EditorViewModel()
    
    // Use Cases (inyectados)
    private let createProjectUseCase: CreateProjectUseCase
    private let generateAudioUseCase: GenerateAudioUseCase
    private let getVoicesUseCase: GetAvailableVoicesUseCase
    
    init(
        createProjectUseCase: CreateProjectUseCase,
        generateAudioUseCase: GenerateAudioUseCase,
        getVoicesUseCase: GetAvailableVoicesUseCase
    ) {
        self.createProjectUseCase = createProjectUseCase
        self.generateAudioUseCase = generateAudioUseCase
        self.getVoicesUseCase = getVoicesUseCase
    }
    
    // MARK: - View Lifecycle
    
    func onAppear() async {
        await loadVoices()
    }
    
    // MARK: - User Actions
    
    func textChanged(_ newText: String) {
        viewModel.text = newText
        updateCanGenerate()
        updateEstimatedDuration()
    }
    
    func voiceSelected(_ voiceId: String) {
        viewModel.selectedVoiceId = voiceId
        updateCanGenerate()
    }
    
    func generateTapped() async {
        viewModel.isLoading = true
        viewModel.error = nil
        
        do {
            // 1. Crear proyecto
            let createRequest = CreateProjectRequest(
                text: viewModel.text,
                name: nil,
                voiceId: viewModel.selectedVoiceId!,
                speed: 1.0,
                pitch: 1.0,
                provider: .native
            )
            let project = try await createProjectUseCase.execute(createRequest)
            
            // 2. Generar audio
            let generateRequest = GenerateAudioRequest(projectId: project.projectId)
            let result = try await generateAudioUseCase.execute(generateRequest)
            
            // 3. Notificar éxito (navegación, etc)
            // ...
            
        } catch {
            viewModel.error = error.localizedDescription
        }
        
        viewModel.isLoading = false
    }
    
    // MARK: - Private
    
    private func loadVoices() async {
        let voices = await getVoicesUseCase.execute()
        viewModel.availableVoices = voices
        viewModel.selectedVoiceId = voices.first?.id
        updateCanGenerate()
    }
    
    private func updateCanGenerate() {
        viewModel.canGenerate = !viewModel.text.isEmpty && viewModel.selectedVoiceId != nil
    }
    
    private func updateEstimatedDuration() {
        let wordCount = viewModel.text.split(separator: " ").count
        let seconds = Int(Double(wordCount) / 150.0 * 60.0)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        viewModel.estimatedDuration = String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
```

### View (Solo Presentación)
```swift
// UI/Views/EditorView.swift

struct EditorView: View {
    @StateObject private var presenter: EditorPresenter
    
    init(presenter: EditorPresenter) {
        _presenter = StateObject(wrappedValue: presenter)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Editor de texto
            TextEditor(text: textBinding)
                .font(.body)
                .frame(minHeight: 200)
            
            // Selector de voz
            VoiceSelectorView(
                voices: presenter.viewModel.availableVoices,
                selectedId: presenter.viewModel.selectedVoiceId,
                onSelect: { presenter.voiceSelected($0) }
            )
            
            // Info de duración
            Text("Duración estimada: \(presenter.viewModel.estimatedDuration)")
                .foregroundColor(.secondary)
            
            // Botón de generar
            Button("Generar Audio") {
                Task { await presenter.generateTapped() }
            }
            .disabled(!presenter.viewModel.canGenerate)
            
            // Loading
            if presenter.viewModel.isLoading {
                ProgressView()
            }
            
            // Error
            if let error = presenter.viewModel.error {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .task { await presenter.onAppear() }
    }
    
    private var textBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.text },
            set: { presenter.textChanged($0) }
        )
    }
}
```

## Componentes Reutilizables

### VoiceSelectorView
```swift
// UI/Views/Components/VoiceSelectorView.swift

struct VoiceSelectorView: View {
    let voices: [VoiceDTO]
    let selectedId: String?
    let onSelect: (String) -> Void
    
    var body: some View {
        Picker("Voz", selection: selectionBinding) {
            ForEach(voices, id: \.id) { voice in
                Text(voice.name)
                    .tag(Optional(voice.id))
            }
        }
        .pickerStyle(.menu)
    }
    
    private var selectionBinding: Binding<String?> {
        Binding(
            get: { selectedId },
            set: { if let id = $0 { onSelect(id) } }
        )
    }
}
```

### WaveformView
```swift
// UI/Views/Components/WaveformView.swift

struct WaveformView: View {
    let samples: [Float]
    let progress: Double
    let onSeek: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let midY = height / 2
                let sampleWidth = width / CGFloat(samples.count)
                
                // Dibujar waveform
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * sampleWidth
                    let barHeight = CGFloat(sample) * height * 0.8
                    
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: max(sampleWidth - 1, 1),
                        height: barHeight
                    )
                    
                    let isPlayed = Double(index) / Double(samples.count) <= progress
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(isPlayed ? .accentColor : .gray.opacity(0.5))
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = value.location.x / geometry.size.width
                        onSeek(min(max(progress, 0), 1))
                    }
            )
        }
        .frame(height: 60)
    }
}
```

### PlaybackControlsView
```swift
// UI/Views/Components/PlaybackControlsView.swift

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let currentTime: String
    let duration: String
    let onPlayPause: () -> Void
    let onBackward: () -> Void
    let onForward: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Tiempo actual
            Text(currentTime)
                .monospacedDigit()
                .foregroundColor(.secondary)
            
            // Controles
            HStack(spacing: 16) {
                Button(action: onBackward) {
                    Image(systemName: "gobackward.10")
                }
                .buttonStyle(.plain)
                
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .buttonStyle(.plain)
                
                Button(action: onForward) {
                    Image(systemName: "goforward.10")
                }
                .buttonStyle(.plain)
            }
            
            // Duración total
            Text(duration)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}
```

## DTOs para UI

```swift
// Application/DTOs/VoiceDTO.swift

struct VoiceDTO: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String
    let provider: String
    let isDefault: Bool
}

// Application/DTOs/ProjectDTO.swift

struct ProjectDTO: Identifiable, Equatable {
    let id: String
    let name: String
    let text: String
    let status: String
    let duration: String?
    let createdAt: Date
    let updatedAt: Date
}
```

## Testing de Presenters

```swift
// Tests/UI/EditorPresenterTests.swift

@MainActor
final class EditorPresenterTests: XCTestCase {
    var sut: EditorPresenter!
    var mockCreateProject: MockCreateProjectUseCase!
    var mockGenerateAudio: MockGenerateAudioUseCase!
    var mockGetVoices: MockGetVoicesUseCase!
    
    override func setUp() {
        mockCreateProject = MockCreateProjectUseCase()
        mockGenerateAudio = MockGenerateAudioUseCase()
        mockGetVoices = MockGetVoicesUseCase()
        
        sut = EditorPresenter(
            createProjectUseCase: mockCreateProject,
            generateAudioUseCase: mockGenerateAudio,
            getVoicesUseCase: mockGetVoices
        )
    }
    
    func test_onAppear_shouldLoadVoices() async {
        // Arrange
        mockGetVoices.voicesToReturn = [
            VoiceDTO(id: "v1", name: "Voice 1", language: "en", provider: "native", isDefault: true)
        ]
        
        // Act
        await sut.onAppear()
        
        // Assert
        XCTAssertEqual(sut.viewModel.availableVoices.count, 1)
        XCTAssertEqual(sut.viewModel.selectedVoiceId, "v1")
    }
    
    func test_textChanged_shouldUpdateEstimatedDuration() {
        // Arrange
        let text = String(repeating: "word ", count: 150) // 150 palabras = 1 minuto
        
        // Act
        sut.textChanged(text)
        
        // Assert
        XCTAssertEqual(sut.viewModel.estimatedDuration, "1:00")
    }
    
    func test_generateTapped_whenSuccess_shouldNotShowError() async {
        // Arrange
        sut.textChanged("Test text")
        sut.voiceSelected("v1")
        mockCreateProject.resultToReturn = CreateProjectResponse(
            projectId: ProjectId(),
            name: "Test",
            createdAt: Date()
        )
        
        // Act
        await sut.generateTapped()
        
        // Assert
        XCTAssertNil(sut.viewModel.error)
        XCTAssertFalse(sut.viewModel.isLoading)
    }
}
```

## Archivos a Crear

```
UI/
├── Presenters/
│   ├── ProjectListPresenter.swift
│   ├── EditorPresenter.swift
│   ├── PlayerPresenter.swift
│   └── SettingsPresenter.swift
│
├── ViewModels/
│   ├── ProjectListViewModel.swift
│   ├── EditorViewModel.swift
│   ├── PlayerViewModel.swift
│   └── SettingsViewModel.swift
│
├── Views/
│   ├── MainView.swift
│   ├── ProjectListView.swift
│   ├── EditorView.swift
│   ├── PlayerView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── WaveformView.swift
│       ├── VoiceSelectorView.swift
│       ├── PlaybackControlsView.swift
│       ├── ProjectCardView.swift
│       └── LoadingOverlay.swift
│
└── Navigation/
    └── AppRouter.swift
```

## Checklist de Calidad

- [ ] Views NO tienen lógica de negocio
- [ ] Presenters coordinan Use Cases
- [ ] ViewModels solo contienen estado de UI
- [ ] Componentes son reutilizables
- [ ] Accesibilidad implementada
- [ ] VoiceOver funciona
- [ ] Dynamic Type soportado
- [ ] Modo claro/oscuro funciona
- [ ] Tests de Presenters completos
