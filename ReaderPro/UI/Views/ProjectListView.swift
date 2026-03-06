import SwiftUI
import UniformTypeIdentifiers

/// Vista principal para la lista de proyectos
/// Usa NavigationSplitView con sidebar de carpetas y grid de proyectos
struct ProjectListView: View {

    // MARK: - Navigation Types

    enum Destination: Hashable {
        case create
        case detail(Identifier<Project>)
    }

    // MARK: - Properties

    @StateObject private var presenter: ProjectListPresenter
    @ObservedObject var ttsCoordinator: TTSServerCoordinator
    @State private var projectToDelete: ProjectSummary?
    @State private var generationError: String?
    @State private var navigationPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showServerSetup = false

    // MARK: - Initialization

    init(presenter: ProjectListPresenter, ttsCoordinator: TTSServerCoordinator) {
        _presenter = StateObject(wrappedValue: presenter)
        self.ttsCoordinator = ttsCoordinator
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FolderSidebarView(presenter: presenter)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            NavigationStack(path: $navigationPath) {
                ZStack {
                    Color.appPrimary.ignoresSafeArea()

                    contentView
                }
                .navigationTitle(navigationTitle)
                .searchable(
                    text: searchBinding,
                    prompt: "Search by name or content"
                )
                .toolbar {
                    toolbarContent
                }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .create:
                        CreateProjectView(
                            presenter: presenter,
                            onProjectCreated: { projectId in
                                navigationPath.removeLast()
                                navigationPath.append(Destination.detail(projectId))
                            }
                        )
                    case .detail(let projectId):
                        ProjectDetailView(
                            presenter: DependencyContainer.shared.makeEditorPresenter(),
                            projectId: projectId
                        )
                    }
                }
                .alert("Delete Project?", isPresented: deleteAlertBinding) {
                    deleteAlertButtons
                } message: {
                    if let project = projectToDelete {
                        Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
                    }
                }
                .alert("Error", isPresented: generationErrorBinding) {
                    Button("OK") {
                        generationError = nil
                    }
                } message: {
                    if let error = generationError {
                        Text(error)
                    }
                }
                .onChange(of: navigationPath) { _, _ in
                    if navigationPath.isEmpty {
                        Task {
                            await presenter.onAppear()
                        }
                    }
                }
            }
        }
        .task {
            if !navigationPath.isEmpty {
                navigationPath = NavigationPath()
            }
            await presenter.onAppear()
            await ttsCoordinator.startActiveServer()

            if !UserDefaults.standard.bool(forKey: "hasCompletedTTSSetup") {
                showServerSetup = true
            }
        }
        .sheet(isPresented: $showServerSetup) {
            ServerSetupView(coordinator: ttsCoordinator)
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch presenter.viewModel.selectedFolder {
        case .all:
            return "All Projects"
        case .uncategorized:
            return "Uncategorized"
        case .folder(let id):
            return presenter.viewModel.folders.first(where: { $0.folderId == id })?.name ?? "Projects"
        }
    }


    private var generationErrorBinding: Binding<Bool> {
        Binding(
            get: { generationError != nil },
            set: { if !$0 { generationError = nil } }
        )
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if presenter.viewModel.isLoading && presenter.viewModel.projects.isEmpty {
                loadingView
            } else if let error = presenter.viewModel.error {
                errorView(message: error)
            } else if presenter.viewModel.showEmptyState {
                emptyStateView
            } else if presenter.viewModel.showNoResults {
                noResultsView
            } else {
                projectListView
            }
        }
    }

    // MARK: - Subviews

    private var projectListView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 12) {
                ForEach(presenter.viewModel.projects) { project in
                    ProjectCardView(
                        project: project,
                        thumbnailFullPath: presenter.viewModel.thumbnailFullPaths[project.id]
                    ) {
                        navigationPath.append(Destination.detail(project.projectId))
                    }
                    .contextMenu {
                        contextMenuButtons(for: project)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await presenter.onAppear()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading projects...")
                .font(.headline)
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.appHighlight)

            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.appTextPrimary)

            Text(message)
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task {
                    await presenter.onAppear()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Color.appTextMuted)

            Text("No Projects")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.appTextPrimary)

            Text("Create your first project to get started")
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                navigationPath.append(Destination.create)
            } label: {
                Label("New Project", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Color.appTextMuted)

            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.appTextPrimary)

            Text("No projects match \"\(presenter.viewModel.searchQuery)\"")
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await presenter.search(query: "")
                }
            } label: {
                Text("Clear Search")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            ServerStatusView(coordinator: ttsCoordinator)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                navigationPath.append(Destination.create)
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .help("Create a new project")
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task {
                    await presenter.onAppear()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh project list")
            .disabled(presenter.viewModel.isLoading)
        }

        ToolbarItem(placement: .automatic) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Open settings")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuButtons(for project: ProjectSummary) -> some View {
        Button {
            navigationPath.append(Destination.detail(project.projectId))
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Divider()

        if project.hasAudio {
            Button {
                navigationPath.append(Destination.detail(project.projectId))
            } label: {
                Label("Play Audio", systemImage: "play.circle")
            }
        } else if !project.textPreview.isEmpty {
            Button {
                generateAudioForProject(project)
            } label: {
                Label("Generate Audio", systemImage: "waveform")
            }
            .disabled(GenerationManager.shared.isActive)
        }

        Divider()

        // Move to Folder submenu
        Menu("Move to Folder") {
            // Remove from folder
            if project.folderId != nil {
                Button {
                    Task {
                        await presenter.moveProjectToFolder(projectId: project.projectId, folderId: nil)
                    }
                } label: {
                    Label("Remove from Folder", systemImage: "tray")
                }

                Divider()
            }

            // Available folders
            ForEach(presenter.viewModel.folders) { folder in
                if project.folderId != folder.folderId {
                    Button {
                        Task {
                            await presenter.moveProjectToFolder(
                                projectId: project.projectId,
                                folderId: folder.folderId
                            )
                        }
                    } label: {
                        Label(folder.name, systemImage: "folder.fill")
                    }
                }
            }
        }

        Divider()

        Button {
            presenter.showInFinder(project: project)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }

        Button {
            addCoverImage(for: project)
        } label: {
            Label("Add Cover Image", systemImage: "photo.badge.plus")
        }

        Divider()

        Button(role: .destructive) {
            projectToDelete = project
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func addCoverImage(for project: ProjectSummary) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a cover image for \"\(project.name)\""

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await presenter.setCoverImage(for: project.projectId, imageURL: url)
            }
        }
    }

    private func generateAudioForProject(_ project: ProjectSummary) {
        GenerationManager.shared.startJob(
            type: .projectText,
            projectName: project.name
        ) { job in
            do {
                job.status = .processing
                job.statusMessage = "Generating audio..."
                job.appendLog("Generating audio for \(project.name)...")

                let duration = try await presenter.generateAudio(for: project.projectId)
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                print("[ProjectListView] Audio generated: \(minutes):\(String(format: "%02d", seconds))")

                job.status = .completed
                job.statusMessage = "Audio generated"
                job.appendLog("Audio generated (\(minutes):\(String(format: "%02d", seconds)))", level: .success)

                await MainActor.run {
                    navigationPath.append(Destination.detail(project.projectId))
                }
            } catch {
                job.status = .failed
                job.errorMessage = error.localizedDescription
                job.appendLog("Error: \(error.localizedDescription)", level: .error)

                await MainActor.run {
                    generationError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Bindings

    private var searchBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.searchQuery },
            set: { newValue in
                Task {
                    await presenter.search(query: newValue)
                }
            }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )
    }

    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) {
            projectToDelete = nil
        }

        Button("Delete", role: .destructive) {
            if let project = projectToDelete {
                Task {
                    await presenter.deleteProject(id: project.projectId)
                    projectToDelete = nil
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Projects") {
    ProjectListView(
        presenter: DependencyContainer.shared.makeProjectListPresenter(),
        ttsCoordinator: DependencyContainer.shared.ttsCoordinator
    )
}
