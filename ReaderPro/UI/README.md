# UI Layer - SwiftUI Views

Capa de interfaz de usuario siguiendo arquitectura Hexagonal con Presenters.

## Arquitectura

```
┌─────────────────────────────────────────────┐
│           SwiftUI View                       │
│  - Observa ViewModel (@Published)           │
│  - Delega acciones a Presenter              │
│  - Solo presentación, SIN lógica            │
└──────────────┬──────────────────────────────┘
               │ @StateObject
               ▼
┌─────────────────────────────────────────────┐
│           Presenter                          │
│  - @MainActor ObservableObject              │
│  - Coordina Use Cases                       │
│  - Actualiza ViewModel                      │
│  - Maneja errores y loading                 │
└──────────────┬──────────────────────────────┘
               │ calls
               ▼
┌─────────────────────────────────────────────┐
│           Use Cases                          │
│         (Application Layer)                  │
└─────────────────────────────────────────────┘
```

## Componentes Implementados

### 1. ProjectListView
**Archivo**: `Views/ProjectListView.swift`

Vista principal para gestionar proyectos.

**Características**:
- ✅ Lista de proyectos con ProjectCardView
- ✅ Barra de búsqueda en tiempo real
- ✅ Botón "Nuevo Proyecto" en toolbar
- ✅ Swipe to delete con confirmación
- ✅ Pull to refresh
- ✅ Context menu con acciones:
  - Open, Play Audio, Duplicate, Export, Delete
- ✅ Estados bien definidos:
  - Loading (ProgressView)
  - Empty state (primer uso)
  - No results (búsqueda sin resultados)
  - Error (con retry)
  - Lista normal

**Conectado con**: `ProjectListPresenter`

### 2. ProjectCardView
**Archivo**: `Views/Components/ProjectCardView.swift`

Componente reutilizable para mostrar un proyecto.

**Características**:
- Card design con border y corner radius
- Badge de estado con colores (draft, generating, ready, error)
- Preview de texto (3 líneas)
- Metadata: voz, duración, fecha
- Tap action configurable
- 4 previews en Xcode

### 3. ProjectListPresenter
**Archivo**: `Presenters/ProjectListPresenter.swift`

Coordina la lógica de la lista de proyectos.

**Métodos**:
```swift
func onAppear() async
func deleteProject(id: Identifier<Project>) async
func search(query: String) async
```

**Test Coverage**: 20+ tests

### 4. ProjectListViewModel
**Archivo**: `ViewModels/ProjectListViewModel.swift`

Estado de UI para ProjectListView.

**Properties**:
```swift
@Published var projects: [ProjectSummary] = []
@Published var isLoading: Bool = false
@Published var error: String?
@Published var searchQuery: String = ""

// Computed
var hasProjects: Bool
var showEmptyState: Bool
var showNoResults: Bool
```

## Flujo de Datos

### Carga Inicial
1. View: `.task { await presenter.onAppear() }`
2. Presenter: Ejecuta `ListProjectsUseCase`
3. Presenter: Actualiza `viewModel.projects`
4. View: Re-renderiza con nuevos datos

### Búsqueda
1. View: Usuario escribe en searchBar
2. View: `searchBinding.set(newValue)`
3. Presenter: Ejecuta `search(query:)`
4. Presenter: Filtra proyectos en memoria
5. Presenter: Actualiza `viewModel.projects`
6. View: Re-renderiza resultados filtrados

### Eliminación
1. View: Usuario hace swipe → tap Delete
2. View: Muestra Alert de confirmación
3. View: Si confirma → `presenter.deleteProject(id:)`
4. Presenter: Ejecuta `DeleteProjectUseCase`
5. Presenter: Recarga lista con `ListProjectsUseCase`
6. View: Re-renderiza lista actualizada

### Pull to Refresh
1. View: Usuario hace pull down
2. View: `.refreshable { await presenter.onAppear() }`
3. Presenter: Recarga proyectos
4. View: Actualiza lista

## Inyección de Dependencias

### DependencyContainer
**Archivo**: `App/DependencyContainer.swift`

Contenedor singleton que crea todos los componentes:

```swift
// Adapters (Infrastructure)
- FileSystemProjectRepository
- FileSystemAudioStorage
- FileSystemStorage
- KokoroTTSAdapter

// Use Cases (Application)
- CreateProjectUseCase
- GetProjectUseCase
- ListProjectsUseCase
- UpdateProjectUseCase
- DeleteProjectUseCase
- GenerateAudioUseCase
- SaveAudioEntryUseCase

// Presenters (UI)
- makeProjectListPresenter()
```

### Entry Point
**Archivo**: `App/ReaderProApp.swift`

```swift
@main
struct ReaderProApp: App {
    private let container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ProjectListView(
                presenter: container.makeProjectListPresenter()
            )
        }
    }
}
```

## Testing

### Presenter Tests
**Archivo**: `Tests/UI/ProjectListPresenterTests.swift`

20+ tests con mocks de Use Cases:
- Initialization tests
- OnAppear tests (loading, sorting, errors)
- Delete tests (success, errors, reload)
- Search tests (filtering, case-insensitive)
- Integration tests (full flow)

### Mocks
- `MockListProjectsUseCase`
- `MockDeleteProjectUseCase`

## Previews en Xcode

Todas las vistas incluyen SwiftUI Previews:

```swift
#Preview("With Projects") { ... }
#Preview("Empty State") { ... }
#Preview("Loading") { ... }
#Preview("Error") { ... }
```

## Human Interface Guidelines

✅ **Seguidas**:
- Navigation con NavigationStack
- Searchable con .searchable()
- Pull to refresh con .refreshable()
- Swipe actions
- Context menus
- Alerts con confirmación
- ProgressView para loading
- Empty states con iconos y CTA
- Error states con retry
- Toolbar con acciones primarias
- Help tooltips (.help())
- Color semántico (success, error, etc.)
- SF Symbols para iconos

## Próximos Componentes

### EditorPresenter + EditorView
Para crear y editar proyectos.

### PlayerPresenter + PlayerView
Para reproducir audio con waveform.

### SettingsPresenter + SettingsView
Para configurar la aplicación.

### Componentes Compartidos
- WaveformView
- VoiceSelectorView
- PlaybackControlsView
- LoadingOverlay

## Convenciones

### Naming
- Views: `ProjectListView`, `EditorView`
- Presenters: `ProjectListPresenter`, `EditorPresenter`
- ViewModels: `ProjectListViewModel`, `EditorViewModel`
- Components: `ProjectCardView`, `WaveformView`

### Structure
```swift
struct MyView: View {
    // MARK: - Properties
    @StateObject private var presenter: MyPresenter

    // MARK: - Initialization
    init(presenter: MyPresenter) { ... }

    // MARK: - Body
    var body: some View { ... }

    // MARK: - Subviews
    private var subview: some View { ... }

    // MARK: - Actions
    private func action() { ... }

    // MARK: - Bindings
    private var binding: Binding<T> { ... }
}
```

### @MainActor
Todos los Presenters deben estar marcados con `@MainActor`:

```swift
@MainActor
final class MyPresenter: ObservableObject {
    @Published private(set) var viewModel = MyViewModel()
}
```

## Accesibilidad

TODO: Implementar
- [ ] VoiceOver labels
- [ ] Keyboard navigation
- [ ] Dynamic Type support
- [ ] High contrast mode
- [ ] Reduce motion

## Dark Mode

✅ Soportado automáticamente usando colores semánticos de SwiftUI.
