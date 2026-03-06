import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: HelpSection = .emotions

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                helpSidebar

                Divider()

                ScrollView {
                    helpContent
                        .padding()
                }
            }
            .navigationTitle("Guía de uso")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var helpSidebar: some View {
        List(HelpSection.allCases, selection: $selectedSection) { section in
            Label(section.title, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
        .frame(width: 200)
    }

    @ViewBuilder
    private var helpContent: some View {
        switch selectedSection {
        case .emotions:
            EmotionTagsHelpContent()
        case .voices:
            VoicesHelpContent()
        case .cloning:
            VoiceCloningHelpContent()
        case .shortcuts:
            ShortcutsHelpContent()
        case .export:
            ExportHelpContent()
        }
    }
}

enum HelpSection: String, CaseIterable, Identifiable {
    case emotions
    case voices
    case cloning
    case shortcuts
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emotions: return "Emociones y Tags"
        case .voices: return "Voces disponibles"
        case .cloning: return "Clonar voz"
        case .shortcuts: return "Atajos de teclado"
        case .export: return "Exportar audio"
        }
    }

    var icon: String {
        switch self {
        case .emotions: return "face.smiling"
        case .voices: return "waveform"
        case .cloning: return "mic.badge.plus"
        case .shortcuts: return "keyboard"
        case .export: return "square.and.arrow.up"
        }
    }
}
