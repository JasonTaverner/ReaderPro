import SwiftUI

/// Entry point de la aplicación ReaderPro
@main
struct ReaderProApp: App {

    // MARK: - Properties

    /// Contenedor de dependencias (singleton)
    private let container = DependencyContainer.shared

    /// App delegate para manejar ciclo de vida (terminación de servidores)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ZStack {
                ProjectListView(
                    presenter: container.makeProjectListPresenter(),
                    ttsCoordinator: container.ttsCoordinator
                )

                GenerationProgressPanel(manager: container.generationManager)
            }
            .frame(minWidth: 800, minHeight: 600)
            .preferredColorScheme(.dark)
        }
        .commands {
            // Comandos de menú personalizados
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    // TODO: Abrir ventana de nuevo proyecto
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView(presenter: container.makeSettingsPresenter())
        }
    }
}

/// App delegate para manejar eventos del ciclo de vida de la aplicación
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Descargar los modelos de Kokoro en segundo plano si faltan (primer arranque)
        Task { @MainActor in
            KokoroModelStore.shared.downloadIfNeeded()
        }

        // Arrancar el servidor TTS del proveedor activo al iniciar la app
        Task { @MainActor in
            await DependencyContainer.shared.ttsCoordinator.startActiveServer()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Punto de limpieza más fiable que applicationWillTerminate en SwiftUI
        DependencyContainer.shared.ttsCoordinator.stopAllServers()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Segundo intento de limpieza por si applicationShouldTerminate no se llamó
        DependencyContainer.shared.ttsCoordinator.stopAllServers()
    }
}
