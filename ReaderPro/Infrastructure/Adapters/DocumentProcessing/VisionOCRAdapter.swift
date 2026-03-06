import Foundation
@preconcurrency import Vision
import AppKit
import ImageIO
import ScreenCaptureKit

/// Adaptador de OCR usando el framework Vision de Apple
/// Implementa OCRPort para reconocimiento de texto en imágenes
final class VisionOCRAdapter: OCRPort {

    // MARK: - OCRPort Properties

    var isAvailable: Bool {
        get async { true } // Vision disponible desde macOS 10.15+
    }

    var supportedLanguages: [String] {
        get async { ["es-ES", "en-US", "fr-FR", "de-DE", "pt-BR", "it-IT"] }
    }

    // MARK: - recognizeText(from ImageData)

    func recognizeText(from imageData: ImageData) async throws -> RecognizedText {
        print("[OCR] Processing image for OCR, data size: \(imageData.data.count) bytes")

        guard let cgImage = createCGImage(from: imageData.data) else {
            print("[OCR] ERROR: Failed to create CGImage from data")
            throw OCRError.invalidImageFormat
        }

        print("[OCR] CGImage created: \(cgImage.width) x \(cgImage.height) pixels")

        return try await performOCR(on: cgImage)
    }

    // MARK: - recognizeText(from pdfPath, pageNumber)

    func recognizeText(from pdfPath: String, pageNumber: Int) async throws -> RecognizedText {
        guard FileManager.default.fileExists(atPath: pdfPath) else {
            throw OCRError.recognitionFailed("Archivo no encontrado: \(pdfPath)")
        }

        guard let pdfDocument = CGPDFDocument(URL(fileURLWithPath: pdfPath) as CFURL),
              let page = pdfDocument.page(at: pageNumber) else {
            throw OCRError.recognitionFailed("No se pudo leer la página \(pageNumber)")
        }

        let cgImage = try renderPDFPage(page)
        return try await performOCR(on: cgImage)
    }

    // MARK: - recognizeText(from pdfPath) - all pages

    func recognizeText(from pdfPath: String) async throws -> [RecognizedText] {
        guard FileManager.default.fileExists(atPath: pdfPath) else {
            throw OCRError.recognitionFailed("Archivo no encontrado: \(pdfPath)")
        }

        guard let pdfDocument = CGPDFDocument(URL(fileURLWithPath: pdfPath) as CFURL) else {
            throw OCRError.recognitionFailed("PDF inválido")
        }

        var results: [RecognizedText] = []
        for pageIndex in 1...pdfDocument.numberOfPages {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            let cgImage = try renderPDFPage(page)
            let text = try await performOCR(on: cgImage)
            results.append(text)
        }

        return results
    }

    // MARK: - recognizeTextFromScreen

    func recognizeTextFromScreen(region: ScreenRegion?) async throws -> RecognizedText {
        // Verificar permiso de captura de pantalla
        let hasPermission = CGPreflightScreenCaptureAccess()
        if !hasPermission {
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                throw OCRError.recognitionFailed(
                    "Sin permiso de grabación de pantalla. Actívalo en Ajustes del Sistema → Privacidad → Grabación de pantalla."
                )
            }
        }

        // Capturar pantalla con ScreenCaptureKit
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw OCRError.recognitionFailed("No se encontró pantalla")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.showsCursor = false

        let fullImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // Si hay región, recortar
        let cgImage: CGImage
        if let region = region {
            let scaleX = CGFloat(fullImage.width) / CGFloat(display.width)
            let scaleY = CGFloat(fullImage.height) / CGFloat(display.height)
            let cropRect = CGRect(
                x: CGFloat(region.x) * scaleX,
                y: CGFloat(region.y) * scaleY,
                width: CGFloat(region.width) * scaleX,
                height: CGFloat(region.height) * scaleY
            )
            guard let cropped = fullImage.cropping(to: cropRect) else {
                throw OCRError.recognitionFailed("No se pudo recortar la imagen")
            }
            cgImage = cropped
        } else {
            cgImage = fullImage
        }

        return try await performOCR(on: cgImage)
    }

    // MARK: - Private Methods

    private func createCGImage(from data: Data) -> CGImage? {
        // Prefer CGImageSource (more reliable for PNG/JPEG than NSImage roundtrip)
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           CGImageSourceGetCount(source) > 0,
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            print("[OCR] CGImage via CGImageSource: \(cgImage.width)x\(cgImage.height)")
            return cgImage
        }

        // Fallback to NSImage
        print("[OCR] CGImageSource failed, falling back to NSImage")
        guard let nsImage = NSImage(data: data) else {
            print("[OCR] NSImage creation also failed")
            return nil
        }
        var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
        let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        if let cgImage = cgImage {
            print("[OCR] CGImage via NSImage: \(cgImage.width)x\(cgImage.height)")
        } else {
            print("[OCR] NSImage.cgImage also returned nil")
        }
        return cgImage
    }

    private func performOCR(on cgImage: CGImage) async throws -> RecognizedText {
        print("[OCR] Starting OCR on image: \(cgImage.width)x\(cgImage.height)")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("[OCR] ERROR: VNRecognizeTextRequest failed: \(error.localizedDescription)")
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                print("[OCR] Observations count: \(observations.count)")

                guard !observations.isEmpty else {
                    print("[OCR] ERROR: No text observations found in image")
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let recognizedStrings = observations.compactMap { observation -> (String, Float)? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return (candidate.string, candidate.confidence)
                }

                print("[OCR] Recognized strings count: \(recognizedStrings.count)")
                for (index, item) in recognizedStrings.enumerated() {
                    print("[OCR]   [\(index)] \"\(item.0)\" (confidence: \(item.1))")
                }

                guard !recognizedStrings.isEmpty else {
                    print("[OCR] ERROR: No candidates from observations")
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let rawText = recognizedStrings.map { $0.0 }.joined(separator: "\n")
                let avgConfidence = recognizedStrings.map { $0.1 }.reduce(0, +) / Float(recognizedStrings.count)

                // Normalize OCR text: join hyphenated words, fix line breaks, remove page numbers
                let fullText = TextNormalizer.normalizeOCRText(rawText)

                print("[OCR] Raw text length: \(rawText.count), normalized: \(fullText.count)")
                print("[OCR] Average confidence: \(avgConfidence)")

                do {
                    let result = try RecognizedText(
                        text: fullText,
                        confidence: Double(avgConfidence),
                        language: nil
                    )
                    continuation.resume(returning: result)
                } catch {
                    print("[OCR] ERROR: Failed to create RecognizedText: \(error)")
                    continuation.resume(throwing: error)
                }
            }

            // Configuración del request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es", "en"]

            print("[OCR] VNRecognizeTextRequest configured:")
            print("[OCR]   recognitionLevel: .accurate")
            print("[OCR]   usesLanguageCorrection: true")
            print("[OCR]   recognitionLanguages: \(request.recognitionLanguages)")

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    print("[OCR] VNImageRequestHandler.perform completed successfully")
                } catch {
                    print("[OCR] ERROR: VNImageRequestHandler.perform failed: \(error)")
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    private func renderPDFPage(_ page: CGPDFPage) throws -> CGImage {
        let pageRect = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 300.0 / 72.0
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OCRError.recognitionFailed("No se pudo crear contexto gráfico")
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.scaleBy(x: scale, y: scale)
        context.drawPDFPage(page)

        guard let cgImage = context.makeImage() else {
            throw OCRError.recognitionFailed("No se pudo renderizar la página PDF")
        }

        return cgImage
    }
}
