import SwiftUI

/// Vista para crear un nuevo proyecto
/// Solo pide el nombre - es una vista completa de navegación (no modal)
struct CreateProjectView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @State private var projectName: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var isNameFieldFocused: Bool

    /// Presenter para crear el proyecto
    private let presenter: ProjectListPresenter

    /// Callback cuando se crea el proyecto exitosamente
    var onProjectCreated: ((Identifier<Project>) -> Void)?

    // MARK: - Initialization

    init(presenter: ProjectListPresenter, onProjectCreated: ((Identifier<Project>) -> Void)? = nil) {
        self.presenter = presenter
        self.onProjectCreated = onProjectCreated
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appPrimary.ignoresSafeArea()
            
            Form {
                Section {
                    TextField("Project Name", text: $projectName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            createProject()
                        }
                        .disabled(isCreating)
                } header: {
                    Text("Name")
                        .foregroundColor(Color.appTextPrimary)
                } footer: {
                    Text("Enter a name for your new project")
                        .foregroundColor(Color.appTextSecondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(Color.appHighlight)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .navigationTitle("New Project")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isCreating)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    createProject()
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Create")
                    }
                }
                .disabled(!canCreate)
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
    }

    // MARK: - Computed Properties

    private var canCreate: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    // MARK: - Actions

    private func createProject() {
        guard canCreate else { return }

        isCreating = true
        errorMessage = nil

        Task {
            let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[CreateProjectView] Creating project: \(trimmedName)")

            if let projectId = await presenter.createProject(name: trimmedName) {
                print("[CreateProjectView] Project created with ID: \(projectId.value)")
                await MainActor.run {
                    onProjectCreated?(projectId)
                    dismiss()
                }
            } else {
                print("[CreateProjectView] Failed to create project")
                await MainActor.run {
                    errorMessage = "Failed to create project. Please try again."
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CreateProjectView(
            presenter: DependencyContainer.shared.makeProjectListPresenter()
        )
    }
}
