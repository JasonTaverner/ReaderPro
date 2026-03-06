import SwiftUI

/// Sidebar view that displays folders for organizing projects
struct FolderSidebarView: View {

    @ObservedObject var presenter: ProjectListPresenter
    @State private var editingFolderId: Identifier<Folder>?
    @State private var editingName: String = ""
    @State private var folderToDelete: FolderSummary?

    var body: some View {
        List(selection: folderSelectionBinding) {
            // All Projects
            Label {
                Text("All Projects")
            } icon: {
                Image(systemName: "rectangle.grid.2x2")
                    .foregroundColor(.accentColor)
            }
            .tag(FolderSelection.all)

            // Uncategorized
            Label {
                HStack {
                    Text("Uncategorized")
                    Spacer()
                    let count = uncategorizedCount
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            } icon: {
                Image(systemName: "tray")
                    .foregroundColor(.secondary)
            }
            .tag(FolderSelection.uncategorized)

            Section("Folders") {
                ForEach(presenter.viewModel.folders) { folder in
                    folderRow(folder)
                        .tag(FolderSelection.folder(folder.folderId))
                }

                // New folder row (inline creation)
                if presenter.viewModel.isCreatingFolder {
                    newFolderRow
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                presenter.viewModel.isCreatingFolder = true
                presenter.viewModel.newFolderName = ""
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("Delete Folder?", isPresented: deleteAlertBinding) {
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    Task {
                        await presenter.deleteFolder(id: folder.folderId)
                        folderToDelete = nil
                    }
                }
            }
        } message: {
            if let folder = folderToDelete {
                Text("Delete \"\(folder.name)\"? Projects in this folder will become uncategorized.")
            }
        }
    }

    // MARK: - Folder Row

    @ViewBuilder
    private func folderRow(_ folder: FolderSummary) -> some View {
        if editingFolderId == folder.folderId {
            // Inline rename
            TextField("Folder name", text: $editingName, onCommit: {
                Task {
                    await presenter.renameFolder(id: folder.folderId, newName: editingName)
                    editingFolderId = nil
                }
            })
            .textFieldStyle(.plain)
            .onExitCommand {
                editingFolderId = nil
            }
        } else {
            Label {
                HStack {
                    Text(folder.name)
                    Spacer()
                    if folder.projectCount > 0 {
                        Text("\(folder.projectCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundColor(Color(hex: folder.colorHex) ?? .accentColor)
            }
            .contextMenu {
                Button {
                    editingFolderId = folder.folderId
                    editingName = folder.name
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    folderToDelete = folder
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - New Folder Row

    private var newFolderNameBinding: Binding<String> {
        Binding(
            get: { presenter.viewModel.newFolderName },
            set: { presenter.viewModel.newFolderName = $0 }
        )
    }

    private var newFolderRow: some View {
        TextField("New Folder", text: newFolderNameBinding, onCommit: {
            let name = presenter.viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                Task {
                    await presenter.createFolder(name: name)
                }
            }
            presenter.viewModel.isCreatingFolder = false
        })
        .textFieldStyle(.plain)
        .onExitCommand {
            presenter.viewModel.isCreatingFolder = false
        }
    }

    // MARK: - Bindings

    private var folderSelectionBinding: Binding<FolderSelection?> {
        Binding(
            get: { presenter.viewModel.selectedFolder },
            set: { newValue in
                if let selection = newValue {
                    presenter.selectFolder(selection)
                }
            }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        )
    }

    private var uncategorizedCount: Int {
        presenter.viewModel.folders.isEmpty ? 0 :
        (presenter.viewModel.projects.count - presenter.viewModel.folders.reduce(0) { $0 + $1.projectCount })
    }
}

