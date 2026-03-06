import Foundation
import ScreenCaptureKit
import AppKit
import ImageIO

/// Servicio de captura de pantalla usando ScreenCaptureKit (macOS 14+)
/// Flujo: captura pantalla completa → overlay de selección → recorta región
final class ScreenCaptureService: ScreenCapturePort {

    // MARK: - ScreenCapturePort

    func captureInteractive() async throws -> CapturedImage {
        // 1. Verificar permiso de captura de pantalla ANTES de intentar
        let hasPermission = CGPreflightScreenCaptureAccess()
        print("[ScreenCapture] CGPreflightScreenCaptureAccess: \(hasPermission)")

        if !hasPermission {
            let granted = CGRequestScreenCaptureAccess()
            print("[ScreenCapture] CGRequestScreenCaptureAccess: \(granted)")

            if !granted {
                throw ScreenCaptureError.captureFailed(
                    "Sin permiso de grabación de pantalla. Actívalo en Ajustes del Sistema → Privacidad → Grabación de pantalla."
                )
            }
        }

        // 2. Obtener displays disponibles via ScreenCaptureKit
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            print("[ScreenCapture] ERROR: SCShareableContent falló: \(error)")
            throw ScreenCaptureError.captureFailed("Error al acceder a la pantalla: \(error.localizedDescription)")
        }

        // 3. Encontrar la pantalla correcta: emparejar SCDisplay con NSScreen
        guard let targetScreen = NSScreen.main ?? NSScreen.screens.first else {
            throw ScreenCaptureError.captureFailed("No se encontró pantalla")
        }

        let screenNumber = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let display = content.displays.first(where: { $0.displayID == screenNumber })
            ?? content.displays.first

        guard let display = display else {
            throw ScreenCaptureError.captureFailed("No se encontró display")
        }

        let scaleFactor = targetScreen.backingScaleFactor
        print("[ScreenCapture] Display: \(display.width)x\(display.height), screen: \(targetScreen.frame), scaleFactor: \(scaleFactor)")

        // 4. Capturar pantalla completa con ScreenCaptureKit
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Usar dimensiones basadas en la pantalla real (points * scaleFactor = pixels)
        let captureWidth = Int(targetScreen.frame.width * scaleFactor)
        let captureHeight = Int(targetScreen.frame.height * scaleFactor)
        config.width = captureWidth
        config.height = captureHeight
        config.showsCursor = false
        print("[ScreenCapture] Requesting capture at: \(captureWidth)x\(captureHeight)")

        let fullScreenImage: CGImage
        do {
            fullScreenImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            print("[ScreenCapture] ERROR: SCScreenshotManager.captureImage falló: \(error)")
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }

        print("[ScreenCapture] Full screen captured: \(fullScreenImage.width)x\(fullScreenImage.height)")

        // 5. Mostrar overlay para selección interactiva en la pantalla correcta
        let screenFrame = targetScreen.frame
        print("[ScreenCapture] Screen frame for overlay: \(screenFrame)")

        let selectedRect = try await showSelectionOverlay(
            screenshot: fullScreenImage,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        print("[ScreenCapture] Selected region (points): \(selectedRect)")

        // 6. Convertir coordenadas de puntos (overlay) a píxeles (imagen)
        // Usar las dimensiones REALES de la imagen capturada para la conversión
        let scaleX = CGFloat(fullScreenImage.width) / screenFrame.width
        let scaleY = CGFloat(fullScreenImage.height) / screenFrame.height
        print("[ScreenCapture] Scale factors: x=\(scaleX), y=\(scaleY)")

        let cropRect = CGRect(
            x: selectedRect.origin.x * scaleX,
            y: selectedRect.origin.y * scaleY,
            width: selectedRect.width * scaleX,
            height: selectedRect.height * scaleY
        )

        print("[ScreenCapture] Crop rect (pixels): \(cropRect)")

        guard let croppedImage = fullScreenImage.cropping(to: cropRect) else {
            throw ScreenCaptureError.captureFailed("No se pudo recortar la imagen")
        }

        print("[ScreenCapture] Cropped image: \(croppedImage.width)x\(croppedImage.height)")

        // 7. Convertir a PNG data
        let imageData = try pngData(from: croppedImage)

        // 8. Guardar archivo temporal
        let tempPath = NSTemporaryDirectory() + "screenshot_\(UUID().uuidString).png"
        try imageData.write(to: URL(fileURLWithPath: tempPath))

        // 9. Copia debug
        try? imageData.write(to: URL(fileURLWithPath: "/tmp/debug_capture.png"))
        print("[ScreenCapture] Captured \(imageData.count) bytes, saved to \(tempPath)")

        return try CapturedImage(imageData: imageData, temporaryPath: tempPath)
    }

    // MARK: - Selection Overlay

    @MainActor
    private func showSelectionOverlay(
        screenshot: CGImage,
        screenFrame: CGRect,
        scaleFactor: CGFloat
    ) async throws -> CGRect {
        try await withCheckedThrowingContinuation { continuation in
            let overlay = SelectionOverlayWindow(
                screenshot: screenshot,
                screenFrame: screenFrame,
                scaleFactor: scaleFactor,
                onSelection: { rect in
                    continuation.resume(returning: rect)
                },
                onCancel: {
                    continuation.resume(throwing: ScreenCaptureError.userCancelled)
                }
            )
            overlay.showOverlay()
        }
    }

    // MARK: - PNG Conversion

    private func pngData(from cgImage: CGImage) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw ScreenCaptureError.invalidImageData
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenCaptureError.invalidImageData
        }
        return mutableData as Data
    }
}

// MARK: - Selection Overlay Window

/// Ventana fullscreen transparente que muestra el screenshot y permite seleccionar una región
private class SelectionOverlayWindow: NSWindow {

    init(
        screenshot: CGImage,
        screenFrame: CGRect,
        scaleFactor: CGFloat,
        onSelection: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .statusBar + 1
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false

        let overlayView = SelectionOverlayView(
            screenshot: screenshot,
            screenSize: screenFrame.size,
            scaleFactor: scaleFactor,
            onSelection: { [weak self] rect in
                NSCursor.pop()
                self?.orderOut(nil)
                onSelection(rect)
            },
            onCancel: { [weak self] in
                NSCursor.pop()
                self?.orderOut(nil)
                onCancel()
            }
        )

        contentView = overlayView

        // Posicionar la ventana exactamente sobre la pantalla objetivo
        setFrame(screenFrame, display: true)
    }

    func showOverlay() {
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Selection Overlay View

/// Vista que dibuja el screenshot, overlay oscuro, y rectángulo de selección
private class SelectionOverlayView: NSView {

    private let screenshotImage: NSImage
    private var selectionStart: NSPoint?
    private var selectionEnd: NSPoint?
    private let onSelection: (CGRect) -> Void
    private let onCancel: () -> Void

    init(
        screenshot: CGImage,
        screenSize: CGSize,
        scaleFactor: CGFloat,
        onSelection: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        // Crear NSImage con el tamaño en puntos de la pantalla
        // Esto asegura que la imagen se dibuje a escala 1:1 con el contenido real
        self.screenshotImage = NSImage(cgImage: screenshot, size: screenSize)
        self.onSelection = onSelection
        self.onCancel = onCancel
        super.init(frame: CGRect(origin: .zero, size: screenSize))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 1. Dibujar screenshot completo
        screenshotImage.draw(in: bounds)

        // 2. Overlay oscuro sobre todo
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        // 3. Si hay selección, dibujar la región seleccionada clara
        guard let start = selectionStart, let end = selectionEnd else { return }

        let rect = normalizedRect(from: start, to: end)
        guard rect.width > 1 && rect.height > 1 else { return }

        // Restaurar la zona seleccionada sin oscurecimiento
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).setClip()
        screenshotImage.draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()

        // Borde de selección
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        border.stroke()

        // Dimensiones
        let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        let textSize = (sizeText as NSString).size(withAttributes: attrs)
        let textOrigin = NSPoint(
            x: rect.midX - textSize.width / 2,
            y: rect.minY - textSize.height - 4
        )
        (sizeText as NSString).draw(at: textOrigin, withAttributes: attrs)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        selectionStart = convert(event.locationInWindow, from: nil)
        selectionEnd = selectionStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        selectionEnd = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = selectionStart, let end = selectionEnd else {
            onCancel()
            return
        }

        let rect = normalizedRect(from: start, to: end)

        // Verificar tamaño mínimo
        guard rect.width > 10 && rect.height > 10 else {
            onCancel()
            return
        }

        // Convertir de NSView (origin bottom-left) a screen/CGImage (origin top-left)
        let flippedRect = CGRect(
            x: rect.origin.x,
            y: bounds.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        onSelection(flippedRect)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Helpers

    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}
