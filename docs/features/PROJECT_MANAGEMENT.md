# Project Management

Projects are the central organizational unit in ReaderPro. Each project contains text entries with associated audio and images, stored as files on disk.

## Data Model

### Project (Aggregate Root)

```
Project
├── id: ProjectId (UUID)
├── name: ProjectName
├── text: TextContent? (optional main text)
├── voiceConfiguration: VoiceConfiguration
├── voice: Voice
├── status: ProjectStatus
├── entries: [AudioEntry]
├── coverImagePath: String?
├── createdAt: Date
└── updatedAt: Date
```

### AudioEntry

```
AudioEntry
├── id: EntryId (UUID)
├── text: TextContent
├── audioPath: String?
├── imagePath: String?
└── createdAt: Date
```

## File System Layout

```
~/Documents/ReaderProLibrary/           ← Base directory (configurable)
├── My Project/
│   ├── project.json                    ← Project metadata
│   ├── 001.txt                         ← Entry 1 text
│   ├── 001.wav                         ← Entry 1 audio
│   ├── 001.png                         ← Entry 1 image (optional)
│   ├── 002.txt
│   ├── 002.wav
│   ├── cover.png                       ← Project cover image
│   └── Fusion_001/                     ← Merged export
│       ├── documento_completo.txt
│       ├── audio_completo.wav
│       └── imagenes.pdf
├── Another Project/
│   └── ...
```

### Numbering Rules

- Files numbered sequentially: `001`, `002`, `003`, etc.
- System finds highest existing number and adds +1
- Text, audio, and image for one entry share the same number
- Fusion folders follow their own sequence: `Fusion_001`, `Fusion_002`, etc.

## CRUD Operations

### Create Project

**Use Case:** `CreateProjectUseCase`

1. User enters project name in CreateProjectView
2. Creates empty project (no text, no entries)
3. Navigates to ProjectDetailView for editing

**Defaults:** Voice `af_bella`, speed 1.0, pitch 1.0, provider `.kokoro`

### Load Project

**Use Case:** `GetProjectUseCase`

1. Reads `project.json` from project directory
2. Maps JSON to domain objects via `ProjectMapper`
3. Resolves absolute paths for audio/image files
4. Returns full project with entries

### Update Project

**Use Case:** `UpdateProjectUseCase`

Triggered by auto-save (2-second debounce) when editing:
- Project name
- Text content
- Voice configuration (voiceId, speed, pitch)

### Delete Project

**Use Case:** `DeleteProjectUseCase`

1. Confirmation alert in UI
2. Deletes entire project directory (including all files)
3. Refreshes project list

### List Projects

**Use Case:** `ListProjectsUseCase`

- Scans all directories in base path
- Loads `project.json` from each
- Returns `[ProjectSummary]` sorted by `updatedAt` descending
- Supports search by name or text content

## Project Export (Merge)

**Use Case:** `MergeProjectUseCase`

Creates a `Fusion_XXX/` folder containing:
- **documento_completo.txt** — All entry texts concatenated with separators
- **audio_completo.wav** — All audio files merged into one
- **imagenes.pdf** — All entry images combined into a single PDF

## Cover Images

- Set via context menu in project list or "set cover" in detail view
- Copied to project directory as `cover.png`
- Stored as relative path in `project.json`
- Used as thumbnail in project list

## Show in Finder

Both ProjectListView (context menu) and ProjectDetailView (actions section) provide "Show in Finder" to open the project's folder:

```swift
NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectDir)
```

## Storage Configuration

The base directory defaults to `~/Documents/ReaderProLibrary/` but can be changed in Settings.

- Uses security-scoped bookmarks for sandboxed access
- Changing directory requires app restart
- "Reset to Default" restores the default location

## JSON Schema

See [Infrastructure Layer](../architecture/INFRASTRUCTURE_LAYER.md#filesystemprojectrepository) for the full `project.json` schema.
