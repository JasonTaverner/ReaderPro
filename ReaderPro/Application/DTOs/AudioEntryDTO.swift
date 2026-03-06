import Foundation

/// DTO para representar un AudioEntry en la capa de UI
struct AudioEntryDTO: Identifiable, Equatable {
    let id: String
    let number: Int           // 001, 002, 003...
    let textPreview: String   // First 50 chars of text
    let fullText: String      // Full text content of the entry
    let audioPath: String?
    let imagePath: String?
    let imageFullPath: String?  // Path completo resuelto para cargar la imagen
    let isRead: Bool

    var hasAudio: Bool { audioPath != nil }
    var hasImage: Bool { imagePath != nil }

    /// Número formateado como string (001, 002...)
    var formattedNumber: String {
        String(format: "%03d", number)
    }

    /// Crea DTO desde AudioEntry del dominio
    /// - Parameters:
    ///   - entry: AudioEntry del dominio
    ///   - number: Número secuencial del entry
    ///   - storageBaseDirectory: Directorio base del almacenamiento para resolver paths completos
    init(from entry: AudioEntry, number: Int, storageBaseDirectory: String? = nil) {
        self.id = entry.id.value.uuidString
        self.number = number
        self.textPreview = String(entry.text.value.prefix(50))
        self.fullText = entry.text.value
        self.audioPath = entry.audioPath
        self.imagePath = entry.imagePath
        self.isRead = entry.isRead

        if let imagePath = entry.imagePath, let baseDir = storageBaseDirectory {
            let baseURL = URL(fileURLWithPath: baseDir, isDirectory: true)
            self.imageFullPath = baseURL.appendingPathComponent(imagePath).path
        } else {
            self.imageFullPath = nil
        }
    }

    /// Init directo para tests y previews
    init(id: String, number: Int, textPreview: String, fullText: String = "", audioPath: String?, imagePath: String?, imageFullPath: String? = nil, isRead: Bool = false) {
        self.id = id
        self.number = number
        self.textPreview = textPreview
        self.fullText = fullText
        self.audioPath = audioPath
        self.imagePath = imagePath
        self.imageFullPath = imageFullPath
        self.isRead = isRead
    }
}
