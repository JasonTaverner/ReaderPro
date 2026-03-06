import Foundation

/// Configuración centralizada de directorios de almacenamiento
/// Single source of truth para el directorio base de la aplicación
/// Soporta security-scoped bookmarks para App Sandbox
final class StorageConfiguration {

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let bookmarkKey = "storageBookmarkData"
    private let pathKey = "storageBaseDirectory"

    /// Directorio base resuelto: custom si existe, default si no
    var baseDirectory: URL {
        resolvedDirectory ?? defaultDirectory
    }

    /// Directorio por defecto: ~/Documents/ReaderProLibrary
    var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReaderProLibrary", isDirectory: true)
    }

    /// Indica si se está usando un directorio personalizado
    var isCustomDirectory: Bool {
        resolvedDirectory != nil
    }

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Establece un nuevo directorio base con security-scoped bookmark
    /// - Parameter url: URL del directorio seleccionado por el usuario (desde NSOpenPanel)
    func setBaseDirectory(_ url: URL) throws {
        // Crear security-scoped bookmark para mantener acceso entre launches
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        userDefaults.set(bookmarkData, forKey: bookmarkKey)
        userDefaults.set(url.path, forKey: pathKey)
    }

    /// Resetea al directorio por defecto, eliminando la configuración personalizada
    func resetToDefault() {
        userDefaults.removeObject(forKey: bookmarkKey)
        userDefaults.removeObject(forKey: pathKey)
    }

    // MARK: - Private Methods

    /// Resuelve el directorio personalizado desde el bookmark guardado
    /// Retorna nil si no hay directorio personalizado configurado
    private var resolvedDirectory: URL? {
        guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Intentar renovar el bookmark
                if let newBookmarkData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    userDefaults.set(newBookmarkData, forKey: bookmarkKey)
                }
            }

            // Iniciar acceso al recurso con seguridad
            _ = url.startAccessingSecurityScopedResource()

            return url
        } catch {
            // Fallback: intentar con el path guardado directamente
            guard let path = userDefaults.string(forKey: pathKey) else {
                return nil
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
    }
}
