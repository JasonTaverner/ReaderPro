import SwiftUI

/// Card component para mostrar un proyecto en cuadricula
/// Componente reutilizable con layout vertical compacto
struct ProjectCardView: View {

    // MARK: - Properties

    let project: ProjectSummary
    let thumbnailFullPath: String?
    let onTap: () -> Void

    @State private var thumbnailImage: NSImage?

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header icon area
                headerArea

                // Nombre del proyecto
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Preview del texto
                Text(project.textPreview.isEmpty ? "No content" : project.textPreview)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Footer: metadata
                HStack(spacing: 6) {
                    // Voz + provider
                    Text(project.voiceName)
                        .font(.caption2)
                        .foregroundColor(Color.appTextMuted)
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appTertiary.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: thumbnailFullPath) {
            guard let path = thumbnailFullPath else {
                thumbnailImage = nil
                return
            }
            thumbnailImage = await ThumbnailCache.shared.loadImage(for: path)
        }
    }

    // MARK: - Subviews

    private var headerArea: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = thumbnailImage {
                // Thumbnail image (async loaded & downscaled)
                Color.clear
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
                    .cornerRadius(6)
                    .overlay(alignment: .bottom) {
                        // Project name overlay on image
                        Text(project.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appPrimary.opacity(0.8))
                    }
            } else {
                // Placeholder icon (or loading)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.appPrimary.opacity(0.4))
                    .overlay(
                        Group {
                            if thumbnailFullPath != nil {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: project.hasAudio ? "waveform" : "doc.text")
                                    .font(.title2)
                                    .foregroundColor(statusColor)
                            }
                        }
                    )
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            }

            // Duration badge (top-right)
            if let duration = project.durationFormatted {
                Text(duration)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appAccent.opacity(0.9))
                    .cornerRadius(4)
                    .padding(6)
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
    }

    // MARK: - Computed Properties

    private var statusText: String {
        switch project.status {
        case .draft:
            return "Draft"
        case .generating:
            return "Generating"
        case .ready:
            return "Ready"
        case .error:
            return "Error"
        }
    }

    private var statusColor: Color {
        switch project.status {
        case .draft:
            return Color.appTextMuted
        case .generating:
            return Color.appHighlight
        case .ready:
            return Color(hex: "4caf50") // Green for ready
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

#Preview("Ready Project") {
    ProjectCardView(
        project: ProjectSummary(
            projectId: Identifier<Project>(),
            name: "Sample Project",
            textPreview: "This is a sample text preview that shows how the project content looks in the card view.",
            status: .ready,
            hasAudio: true,
            voiceName: "Dora (Español)",
            voiceProvider: .kokoro,
            createdAt: Date(),
            updatedAt: Date()
        ),
        thumbnailFullPath: nil,
        onTap: {}
    )
    .frame(width: 180)
    .padding()
}

#Preview("Draft Project") {
    ProjectCardView(
        project: ProjectSummary(
            projectId: Identifier<Project>(),
            name: "Draft Document",
            textPreview: "Work in progress...",
            status: .draft,
            hasAudio: false,
            voiceName: "Alex (Español)",
            voiceProvider: .kokoro,
            createdAt: Date(),
            updatedAt: Date()
        ),
        thumbnailFullPath: nil,
        onTap: {}
    )
    .frame(width: 180)
    .padding()
}

#Preview("Grid Layout") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 12) {
        ForEach(0..<6, id: \.self) { i in
            ProjectCardView(
                project: ProjectSummary(
                    projectId: Identifier<Project>(),
                    name: "Project \(i + 1)",
                    textPreview: "Preview text for project number \(i + 1) with some content.",
                    status: i % 2 == 0 ? .ready : .draft,
                    hasAudio: i % 2 == 0,
                    voiceName: "Dora",
                    voiceProvider: .kokoro,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                thumbnailFullPath: nil,
                onTap: {}
            )
        }
    }
    .padding()
}
