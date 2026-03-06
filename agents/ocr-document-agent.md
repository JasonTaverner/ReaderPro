# Agente: OCR & Document Processing Specialist

## Rol
Especialista en implementación de Adapters para OCR, procesamiento de documentos (PDF/EPUB), captura de pantalla y procesamiento batch de imágenes. Implementa los Ports definidos en el dominio (`OCRPort`, `DocumentParserPort`, `ScreenshotPort`) usando frameworks nativos de Apple.

## Ubicación
`agents/ocr-document-agent.md`

## Responsabilidades

### Implementar Ports de Document Processing
- `VisionOCRAdapter` - OCR usando Vision framework
- `PDFKitParserAdapter` - Parsing de PDF con PDFKit
- `EPUBParserAdapter` - Parsing de EPUB (WebKit o library de terceros)
- `ScreenshotAdapter` - Captura de pantalla con screencapture/NSWorkspace

### Servicios del Dominio
- `BatchProcessingService` - Procesar múltiples imágenes en secuencia
- `TextNormalizationService` - Limpieza de texto OCR (hyphenation, line breaks)

## Principio Fundamental

> **Los Adapters implementan Ports. Solo ellos importan frameworks externos.**

```swift
// ✅ CORRECTO
// Infrastructure/Adapters/DocumentProcessing/VisionOCRAdapter.swift
import Vision
import CoreImage

final class VisionOCRAdapter: OCRPort {
    func recognizeText(from imagePath: String) async throws -> RecognizedText
}

// ❌ INCORRECTO
// Domain/DocumentProcessing/Ports/OCRPort.swift
import Vision  // NUNCA en Domain
```

## Ports a Implementar (definidos en Domain)

```swift
// Domain/DocumentProcessing/Ports/OCRPort.swift
protocol OCRPort {
    func recognizeText(from imagePath: String) async throws -> RecognizedText
    func recognizeText(from imageData: Data) async throws -> RecognizedText
    var isAvailable: Bool { get }
}

// Domain/DocumentProcessing/Ports/DocumentParserPort.swift
protocol DocumentParserPort {
    func extractPages(from pdfPath: String) async throws -> [PageImage]
    func extractPages(from epubPath: String) async throws -> [PageImage]
    func pageCount(in documentPath: String) async throws -> Int
}

// Domain/DocumentProcessing/Ports/ScreenshotPort.swift
protocol ScreenshotPort {
    func captureInteractive() async throws -> CapturedImage
    func captureRegion(_ region: CGRect) async throws -> CapturedImage
}
```

## Value Objects del Dominio

```swift
// Domain/DocumentProcessing/ValueObjects/RecognizedText.swift
struct RecognizedText: Equatable {
    let text: String
    let confidence: Float  // 0.0 - 1.0
    let language: String?

    init(text: String, confidence: Float = 1.0, language: String? = nil) throws {
        guard !text.isEmpty else {
            throw DomainError.emptyRecognizedText
        }
        guard (0.0...1.0).contains(confidence) else {
            throw DomainError.invalidConfidence
        }
        self.text = text
        self.confidence = confidence
        self.language = language
    }
}

// Domain/DocumentProcessing/ValueObjects/PageImage.swift
struct PageImage: Equatable {
    let pageNumber: Int
    let imageData: Data
    let width: Int
    let height: Int

    init(pageNumber: Int, imageData: Data, width: Int, height: Int) throws {
        guard pageNumber > 0 else {
            throw DomainError.invalidPageNumber
        }
        guard !imageData.isEmpty else {
            throw DomainError.emptyImageData
        }
        guard width > 0 && height > 0 else {
            throw DomainError.invalidImageDimensions
        }
        self.pageNumber = pageNumber
        self.imageData = imageData
        self.width = width
        self.height = height
    }
}

// Domain/DocumentProcessing/ValueObjects/CapturedImage.swift
struct CapturedImage: Equatable {
    let imageData: Data
    let temporaryPath: String  // Path temporal en /tmp
    let captureDate: Date

    init(imageData: Data, temporaryPath: String) throws {
        guard !imageData.isEmpty else {
            throw DomainError.emptyImageData
        }
        self.imageData = imageData
        self.temporaryPath = temporaryPath
        self.captureDate = Date()
    }
}

// Domain/DocumentProcessing/ValueObjects/DocumentType.swift
enum DocumentType: String, Equatable {
    case pdf = "PDF"
    case epub = "EPUB"
    case mobi = "MOBI"
    case image = "Image"

    var fileExtensions: [String] {
        switch self {
        case .pdf: return ["pdf"]
        case .epub: return ["epub"]
        case .mobi: return ["mobi"]
        case .image: return ["png", "jpg", "jpeg", "tiff", "bmp", "webp"]
        }
    }
}
```

## Implementación de Adapters

### 1. VisionOCRAdapter (Vision Framework)

```swift
// Infrastructure/Adapters/DocumentProcessing/VisionOCRAdapter.swift
import Foundation
import Vision
import CoreImage

final class VisionOCRAdapter: OCRPort {
    var isAvailable: Bool {
        // Vision está disponible desde macOS 10.15+
        if #available(macOS 10.15, *) {
            return true
        }
        return false
    }

    func recognizeText(from imagePath: String) async throws -> RecognizedText {
        guard FileManager.default.fileExists(atPath: imagePath) else {
            throw OCRError.fileNotFound(imagePath)
        }

        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) else {
            throw OCRError.invalidImageData
        }

        return try await recognizeText(from: imageData)
    }

    func recognizeText(from imageData: Data) async throws -> RecognizedText {
        guard let cgImage = createCGImage(from: imageData) else {
            throw OCRError.invalidImageFormat
        }

        return try await performOCR(on: cgImage)
    }

    // MARK: - Private Methods

    private func createCGImage(from data: Data) -> CGImage? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
        return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        #else
        return nil
        #endif
    }

    private func performOCR(on cgImage: CGImage) async throws -> RecognizedText {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                // Extraer texto y calcular confianza promedio
                let recognizedStrings = observations.compactMap { observation -> (String, Float)? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return (candidate.string, candidate.confidence)
                }

                let fullText = recognizedStrings.map { $0.0 }.joined(separator: " ")
                let avgConfidence = recognizedStrings.map { $0.1 }.reduce(0, +) / Float(recognizedStrings.count)

                do {
                    let result = try RecognizedText(
                        text: fullText,
                        confidence: avgConfidence,
                        language: nil  // Vision no siempre devuelve idioma
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Configuración del request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es-ES", "en-US"]  // Idiomas soportados

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                }
            }
        }
    }
}

enum OCRError: LocalizedError {
    case fileNotFound(String)
    case invalidImageData
    case invalidImageFormat
    case recognitionFailed(Error)
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Imagen no encontrada: \(path)"
        case .invalidImageData:
            return "Datos de imagen inválidos"
        case .invalidImageFormat:
            return "Formato de imagen no soportado"
        case .recognitionFailed(let error):
            return "Error en reconocimiento OCR: \(error.localizedDescription)"
        case .noTextFound:
            return "No se encontró texto en la imagen"
        }
    }
}
```

### 2. PDFKitParserAdapter (PDFKit)

```swift
// Infrastructure/Adapters/DocumentProcessing/PDFKitParserAdapter.swift
import Foundation
import PDFKit
import AppKit

final class PDFKitParserAdapter: DocumentParserPort {

    func pageCount(in documentPath: String) async throws -> Int {
        guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: documentPath)) else {
            throw DocumentParserError.invalidDocument
        }
        return pdfDocument.pageCount
    }

    func extractPages(from pdfPath: String) async throws -> [PageImage] {
        guard FileManager.default.fileExists(atPath: pdfPath) else {
            throw DocumentParserError.fileNotFound(pdfPath)
        }

        guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else {
            throw DocumentParserError.invalidPDF
        }

        var pages: [PageImage] = []
        let pageCount = pdfDocument.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Renderizar página a imagen con alta resolución (DPI 300)
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 300.0 / 72.0  // 72 DPI -> 300 DPI
            let scaledSize = CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )

            guard let imageData = renderPageToImageData(page: page, size: scaledSize) else {
                continue
            }

            do {
                let pageImage = try PageImage(
                    pageNumber: pageIndex + 1,
                    imageData: imageData,
                    width: Int(scaledSize.width),
                    height: Int(scaledSize.height)
                )
                pages.append(pageImage)
            } catch {
                // Log error pero continuar con las demás páginas
                print("Error creando PageImage para página \(pageIndex + 1): \(error)")
            }
        }

        return pages
    }

    func extractPages(from epubPath: String) async throws -> [PageImage] {
        // EPUB no es directamente soportado por PDFKit
        // Lanzar error o implementar con WebKit
        throw DocumentParserError.unsupportedFormat("EPUB no soportado por PDFKit. Use EPUBParserAdapter.")
    }

    // MARK: - Private Methods

    private func renderPageToImageData(page: PDFPage, size: CGSize) -> Data? {
        let image = NSImage(size: size)
        image.lockFocus()

        // Fondo blanco
        NSColor.white.set()
        NSRect(origin: .zero, size: size).fill()

        // Renderizar página
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()

        let scaleX = size.width / page.bounds(for: .mediaBox).width
        let scaleY = size.height / page.bounds(for: .mediaBox).height
        context?.scaleBy(x: scaleX, y: scaleY)

        page.draw(with: .mediaBox, to: context!)
        context?.restoreGState()

        image.unlockFocus()

        // Convertir a PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
    }
}

enum DocumentParserError: LocalizedError {
    case fileNotFound(String)
    case invalidDocument
    case invalidPDF
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Documento no encontrado: \(path)"
        case .invalidDocument:
            return "Documento inválido o corrupto"
        case .invalidPDF:
            return "PDF inválido"
        case .unsupportedFormat(let message):
            return message
        }
    }
}
```

### 3. ScreenshotAdapter

```swift
// Infrastructure/Adapters/DocumentProcessing/ScreenshotAdapter.swift
import Foundation
import AppKit

final class ScreenshotAdapter: ScreenshotPort {

    func captureInteractive() async throws -> CapturedImage {
        let tempPath = NSTemporaryDirectory() + "screenshot_\(UUID().uuidString).png"

        // Llamar a screencapture con selección interactiva
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-i",      // Interactive mode (user selects region)
            "-x",      // No sound
            "-r",      // Do not add shadow
            tempPath
        ]

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    // Captura exitosa
                    do {
                        let imageData = try Data(contentsOf: URL(fileURLWithPath: tempPath))
                        let capturedImage = try CapturedImage(
                            imageData: imageData,
                            temporaryPath: tempPath
                        )
                        continuation.resume(returning: capturedImage)
                    } catch {
                        continuation.resume(throwing: ScreenshotError.captureFailed(error))
                    }
                } else {
                    // Usuario canceló o error
                    continuation.resume(throwing: ScreenshotError.userCancelled)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ScreenshotError.processLaunchFailed(error))
            }
        }
    }

    func captureRegion(_ region: CGRect) async throws -> CapturedImage {
        let tempPath = NSTemporaryDirectory() + "screenshot_\(UUID().uuidString).png"

        // Captura una región específica
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x",      // No sound
            "-R",      // Capture rect
            "\(Int(region.origin.x)),\(Int(region.origin.y)),\(Int(region.width)),\(Int(region.height))",
            tempPath
        ]

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    do {
                        let imageData = try Data(contentsOf: URL(fileURLWithPath: tempPath))
                        let capturedImage = try CapturedImage(
                            imageData: imageData,
                            temporaryPath: tempPath
                        )
                        continuation.resume(returning: capturedImage)
                    } catch {
                        continuation.resume(throwing: ScreenshotError.captureFailed(error))
                    }
                } else {
                    continuation.resume(throwing: ScreenshotError.captureFailed(nil))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ScreenshotError.processLaunchFailed(error))
            }
        }
    }
}

enum ScreenshotError: LocalizedError {
    case processLaunchFailed(Error)
    case captureFailed(Error?)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .processLaunchFailed(let error):
            return "No se pudo iniciar captura de pantalla: \(error.localizedDescription)"
        case .captureFailed(let error):
            if let error = error {
                return "Error al capturar pantalla: \(error.localizedDescription)"
            }
            return "Error al capturar pantalla"
        case .userCancelled:
            return "Captura cancelada por el usuario"
        }
    }
}
```

### 4. EPUBParserAdapter (WebKit)

```swift
// Infrastructure/Adapters/DocumentProcessing/EPUBParserAdapter.swift
import Foundation
import WebKit
import AppKit

final class EPUBParserAdapter: DocumentParserPort {

    func pageCount(in documentPath: String) async throws -> Int {
        // EPUB no tiene concepto fijo de "páginas"
        // Contar capítulos o usar heurística
        throw DocumentParserError.unsupportedFormat("EPUB no tiene páginas fijas")
    }

    func extractPages(from pdfPath: String) async throws -> [PageImage] {
        throw DocumentParserError.unsupportedFormat("PDF no soportado por EPUBParserAdapter")
    }

    func extractPages(from epubPath: String) async throws -> [PageImage] {
        // Nota: Esta es una implementación simplificada
        // Una implementación completa requeriría:
        // 1. Descomprimir EPUB (es un ZIP)
        // 2. Parsear content.opf para obtener orden de archivos
        // 3. Renderizar cada HTML/XHTML con WebKit
        // 4. Capturar screenshots de cada página

        // Por ahora, retornamos error indicando que se necesita una library de terceros
        throw DocumentParserError.unsupportedFormat(
            "EPUB parsing completo requiere library de terceros. " +
            "Considerar usar PyMuPDF via subprocess o buscar EPUBKit en Swift."
        )
    }
}
```

## Normalización de Texto OCR

El texto extraído por OCR a menudo contiene errores de formateo que deben ser corregidos antes de enviarse a TTS:

```swift
// Domain/DocumentProcessing/Services/TextNormalizationService.swift
struct TextNormalizationService {

    func normalize(_ text: String) -> String {
        var normalized = text

        // 1. Fix hyphenation (palabras cortadas)
        // "con-\ntestar" -> "contestar"
        normalized = fixHyphenation(normalized)

        // 2. Join broken lines
        // Líneas que no terminan en puntuación y siguiente en minúscula
        normalized = joinBrokenLines(normalized)

        // 3. Collapse múltiples espacios
        normalized = collapseWhitespace(normalized)

        // 4. Fix common OCR errors
        normalized = fixCommonErrors(normalized)

        return normalized
    }

    private func fixHyphenation(_ text: String) -> String {
        // Regex: palabra seguida de guión, salto de línea opcional, y continuación
        let pattern = #"(\w)-\s*\n\s*(\w)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)

        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "$1$2"
        )
    }

    private func joinBrokenLines(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var result: [String] = []

        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            guard !line.isEmpty else {
                result.append("")
                continue
            }

            // Si la línea NO termina en puntuación y hay línea siguiente en minúscula
            if i < lines.count - 1 {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                let endsWithPunctuation = line.last.map { ".!?;:".contains($0) } ?? false
                let nextStartsLower = nextLine.first?.isLowercase ?? false

                if !endsWithPunctuation && nextStartsLower {
                    // Unir con espacio (sin salto de línea)
                    result.append(line + " ")
                } else {
                    result.append(line + "\n")
                }
            } else {
                result.append(line)
            }
        }

        return result.joined()
    }

    private func collapseWhitespace(_ text: String) -> String {
        let pattern = #"\s+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)

        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: " "
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fixCommonErrors(_ text: String) -> String {
        var fixed = text

        // Eliminar múltiples puntos suspensivos
        fixed = fixed.replacingOccurrences(of: "...", with: ".")

        // Otros fixes comunes según sea necesario

        return fixed
    }
}
```

## Use Cases

```swift
// Application/UseCases/DocumentProcessing/CaptureScreenshotUseCase.swift
final class CaptureScreenshotUseCase {
    private let screenshotPort: ScreenshotPort
    private let ocrPort: OCRPort
    private let textNormalization: TextNormalizationService

    init(screenshotPort: ScreenshotPort,
         ocrPort: OCRPort,
         textNormalization: TextNormalizationService = TextNormalizationService()) {
        self.screenshotPort = screenshotPort
        self.ocrPort = ocrPort
        self.textNormalization = textNormalization
    }

    func execute() async throws -> CaptureScreenshotResponse {
        // 1. Capturar pantalla (interactivo)
        let capturedImage = try await screenshotPort.captureInteractive()

        // 2. Ejecutar OCR
        let recognizedText = try await ocrPort.recognizeText(from: capturedImage.imageData)

        // 3. Normalizar texto
        let normalizedText = textNormalization.normalize(recognizedText.text)

        // 4. Retornar respuesta
        return CaptureScreenshotResponse(
            text: normalizedText,
            imagePath: capturedImage.temporaryPath,
            confidence: recognizedText.confidence
        )
    }
}

struct CaptureScreenshotResponse {
    let text: String
    let imagePath: String
    let confidence: Float
}
```

```swift
// Application/UseCases/DocumentProcessing/ProcessPDFToAudioUseCase.swift
final class ProcessPDFToAudioUseCase {
    private let documentParser: DocumentParserPort
    private let ocrPort: OCRPort
    private let textNormalization: TextNormalizationService
    private let saveEntryUseCase: SaveAudioEntryUseCase
    private let ttsPort: TTSPort

    func execute(_ request: ProcessPDFRequest) async throws -> ProcessPDFResponse {
        // 1. Extraer páginas del PDF
        let pages = try await documentParser.extractPages(from: request.pdfPath)

        var processedPages = 0

        // 2. Para cada página: OCR + TTS + Guardar
        for page in pages {
            // OCR
            let recognizedText = try await ocrPort.recognizeText(from: page.imageData)
            let normalizedText = textNormalization.normalize(recognizedText.text)

            // Generar audio
            let text = try Text(normalizedText)
            let audioData = try await ttsPort.synthesize(text: text, voice: request.voiceConfig)

            // Guardar entry
            _ = try await saveEntryUseCase.execute(
                SaveAudioEntryRequest(
                    projectId: request.projectId,
                    text: normalizedText,
                    audioData: audioData,
                    imagePath: nil  // O guardar la imagen de la página
                )
            )

            processedPages += 1
        }

        return ProcessPDFResponse(
            totalPages: pages.count,
            processedPages: processedPages
        )
    }
}
```

## Testing

### Unit Tests

```swift
// Tests/Infrastructure/VisionOCRAdapterTests.swift
final class VisionOCRAdapterTests: XCTestCase {

    var sut: VisionOCRAdapter!

    override func setUp() {
        sut = VisionOCRAdapter()
    }

    func test_isAvailable_shouldReturnTrue() {
        XCTAssertTrue(sut.isAvailable)
    }

    func test_recognizeText_withValidImage_shouldReturnText() async throws {
        // Arrange
        let testImagePath = Bundle(for: type(of: self))
            .path(forResource: "test_image_with_text", ofType: "png")!

        // Act
        let result = try await sut.recognizeText(from: testImagePath)

        // Assert
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }

    func test_recognizeText_withInvalidPath_shouldThrow() async {
        // Act & Assert
        do {
            _ = try await sut.recognizeText(from: "/invalid/path.png")
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is OCRError)
        }
    }
}

// Tests/Infrastructure/PDFKitParserAdapterTests.swift
final class PDFKitParserAdapterTests: XCTestCase {

    var sut: PDFKitParserAdapter!

    override func setUp() {
        sut = PDFKitParserAdapter()
    }

    func test_pageCount_withValidPDF_shouldReturnCorrectCount() async throws {
        // Arrange
        let testPDFPath = Bundle(for: type(of: self))
            .path(forResource: "test_document", ofType: "pdf")!

        // Act
        let count = try await sut.pageCount(in: testPDFPath)

        // Assert
        XCTAssertEqual(count, 3)  // El PDF de test tiene 3 páginas
    }

    func test_extractPages_withValidPDF_shouldReturnPageImages() async throws {
        // Arrange
        let testPDFPath = Bundle(for: type(of: self))
            .path(forResource: "test_document", ofType: "pdf")!

        // Act
        let pages = try await sut.extractPages(from: testPDFPath)

        // Assert
        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(pages[0].pageNumber, 1)
        XCTAssertFalse(pages[0].imageData.isEmpty)
    }
}
```

## Archivos a Crear

```
Infrastructure/Adapters/DocumentProcessing/
├── VisionOCRAdapter.swift
├── PDFKitParserAdapter.swift
├── EPUBParserAdapter.swift
├── ScreenshotAdapter.swift
└── Errors/
    ├── OCRError.swift
    ├── DocumentParserError.swift
    └── ScreenshotError.swift

Tests/Infrastructure/DocumentProcessing/
├── VisionOCRAdapterTests.swift
├── PDFKitParserAdapterTests.swift
├── EPUBParserAdapterTests.swift
└── ScreenshotAdapterTests.swift

Domain/DocumentProcessing/Services/
└── TextNormalizationService.swift

Application/UseCases/DocumentProcessing/
├── CaptureScreenshotUseCase.swift
├── ProcessImageBatchUseCase.swift
├── ProcessPDFToAudioUseCase.swift
└── ProcessEPUBToAudioUseCase.swift
```

## Consideraciones Técnicas

### Vision Framework
- Disponible desde macOS 10.15+
- Muy preciso para textos impresos
- Soporta múltiples idiomas
- Configurable: `recognitionLevel` (.accurate vs .fast)

### PDFKit
- Nativo de macOS
- Excelente soporte para PDF
- NO soporta EPUB directamente
- Renderizado de alta calidad (DPI configurable)

### EPUB Processing
- EPUB es un formato basado en HTML/XHTML
- Opciones:
  1. Usar WebKit para renderizar HTML y capturar screenshots
  2. Usar library de terceros (EPUBKit)
  3. Llamar a PyMuPDF via subprocess (como en el script Python)

### Screenshot Capture
- `screencapture` es comando nativo de macOS
- `-i` para modo interactivo (usuario selecciona región)
- `-R` para capturar región específica
- Genera PNG por defecto

### Permisos de Sandbox
Para publicación en App Store:
- **Screen Recording Permission:** Requerido para screenshots
- **File Access:** Requerido para leer PDFs/EPUBs
- Entitlements: `com.apple.security.device.camera` (para screenshots)

## Interacción con Otros Agentes

- **Implementa:** Ports definidos por el Agente de Arquitectura
- **Usado por:** Use Cases de DocumentProcessing y GenerateAudio
- **Provee a:** Audio Agent el texto normalizado para TTS
- **Coordina con:** ProjectManager para guardar entradas

## Flujo Completo: PDF a Audio con Merge

```
1. Usuario selecciona PDF
   ↓
2. PDFKitParserAdapter.extractPages() → [PageImage]
   ↓
3. Para cada página:
   ↓ VisionOCRAdapter.recognizeText() → RecognizedText
   ↓ TextNormalizationService.normalize() → String limpio
   ↓ TTSPort.synthesize() → AudioData
   ↓ SaveAudioEntryUseCase → Guardar XXX.txt + XXX.wav + XXX.png
   ↓
4. MergeProjectUseCase → Crear Fusion_XXX/
   ↓ Concatenar textos → documento_completo.txt
   ↓ Unir audios con silencios → audio_completo.wav
   ↓ Crear PDF de imágenes → imagenes.pdf
```

## Checklist de Calidad

- [ ] Adapters implementan correctamente los Ports
- [ ] Solo los Adapters importan frameworks externos (Vision, PDFKit, WebKit)
- [ ] Tests de integración para cada Adapter
- [ ] OCR funciona correctamente con imágenes de test
- [ ] PDF parsing extrae todas las páginas correctamente
- [ ] Screenshot capture funciona en modo interactivo
- [ ] Normalización de texto corrige hyphenation y line breaks
- [ ] Batch processing reporta progreso correctamente
- [ ] Manejo de errores cuando archivos no existen o son inválidos
