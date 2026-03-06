import SwiftUI
import AppKit

/// Thread-safe async image cache for thumbnail display.
/// Loads and downscales images on a background thread to avoid blocking the UI.
/// Thumbnails are capped at 300px to keep memory low while looking sharp.
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: NSImage] = [:]
    private var order: [String] = []
    private let maxSize = 100
    private let thumbnailMaxDimension: CGFloat = 300

    /// Returns cached thumbnail if available (fast, no I/O)
    func cachedImage(for path: String) -> NSImage? {
        cache[path]
    }

    /// Loads image from disk, creates thumbnail, caches it. Safe to call from any thread.
    func loadImage(for path: String) async -> NSImage? {
        // Check cache first
        if let cached = cache[path] {
            return cached
        }

        // Load and thumbnail on background thread
        let maxDim = thumbnailMaxDimension
        let thumb: NSImage? = await Task.detached(priority: .utility) {
            guard let original = NSImage(contentsOfFile: path) else { return nil }
            let originalSize = original.size
            guard originalSize.width > 0 && originalSize.height > 0 else { return nil }

            // Skip downscale if already small
            guard originalSize.width > maxDim || originalSize.height > maxDim else {
                return original
            }

            let scale = min(maxDim / originalSize.width, maxDim / originalSize.height)
            let newSize = NSSize(width: round(originalSize.width * scale),
                                 height: round(originalSize.height * scale))

            // Use CGContext instead of lockFocus for thread safety
            guard let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(newSize.width),
                pixelsHigh: Int(newSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else { return original }

            NSGraphicsContext.saveGraphicsState()
            let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
            NSGraphicsContext.current = context
            original.draw(in: NSRect(origin: .zero, size: newSize),
                          from: NSRect(origin: .zero, size: originalSize),
                          operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let thumb = NSImage(size: newSize)
            thumb.addRepresentation(bitmapRep)
            return thumb
        }.value

        guard let thumb else { return nil }

        // Store in cache
        cache[path] = thumb
        order.removeAll { $0 == path }
        order.append(path)
        if order.count > maxSize {
            let evicted = order.removeFirst()
            cache.removeValue(forKey: evicted)
        }
        return thumb
    }

    func clear() {
        cache.removeAll()
        order.removeAll()
    }
}

/// Card component para mostrar un AudioEntry en cuadricula
/// Componente reutilizable que muestra imagen, texto, estado y boton de play
struct AudioEntryCard: View {

    // MARK: - Properties

    let entry: AudioEntryDTO
    let isPlaying: Bool
    let isGenerating: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    var onImageTap: (() -> Void)? = nil
    var onGenerateAudio: (() -> Void)? = nil

    /// Async-loaded thumbnail image
    @State private var thumbnailImage: NSImage?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Imagen o placeholder con texto superpuesto
            imageArea

            // Footer: numero + play/generate + estado
            HStack(spacing: 6) {
                Text(entry.formattedNumber)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.appTextSecondary)

                Spacer()

                if entry.hasAudio {
                    playButton
                } else {
                    generateAudioButton
                }

                statusBadge
            }
        }
        .padding(10)
        .background(Color.appSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isPlaying ? Color.appHighlight : Color.appTertiary.opacity(0.3),
                    lineWidth: isPlaying ? 2 : 1
                )
        )
        .task(id: entry.imageFullPath) {
            guard let fullPath = entry.imageFullPath else {
                thumbnailImage = nil
                return
            }
            thumbnailImage = await ThumbnailCache.shared.loadImage(for: fullPath)
        }
    }

    // MARK: - Subviews

    private var imageArea: some View {
        ZStack(alignment: .bottom) {
            // Fondo: imagen real o placeholder
            if let nsImage = thumbnailImage {
                Color.clear
                    .frame(height: 160)
                    .overlay(
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
            } else {
                // Placeholder sin imagen (or loading)
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.appPrimary.opacity(0.4))
                    .overlay(
                        Group {
                            if entry.imageFullPath != nil {
                                // Loading indicator
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("\u{1F50A}")
                                    .font(.largeTitle)
                            }
                        }
                    )
                    .frame(height: 160)
            }

            // Texto superpuesto con fondo semi-transparente
            Text(entry.textPreview)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.6))
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .cornerRadius(6)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.imageFullPath != nil {
                onImageTap?()
            }
        }
        .overlay(alignment: .topTrailing) {
            // Icono de expandir si hay imagen
            if entry.imageFullPath != nil {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .padding(4)
            }
        }
    }

    private var playButton: some View {
        Button {
            if isPlaying {
                onStop()
            } else {
                onPlay()
            }
        } label: {
            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                .font(.body)
                .foregroundColor(isPlaying ? .red : Color.appHighlight)
        }
        .buttonStyle(.plain)
    }

    private var generateAudioButton: some View {
        Button {
            onGenerateAudio?()
        } label: {
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "waveform.badge.plus")
                    .font(.body)
                    .foregroundColor(Color.appAccent)
            }
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .help("Generate audio for this entry")
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            if entry.isRead {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "4caf50"))
                Text("Read")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "4caf50"))
            } else if entry.hasAudio {
                Circle()
                    .fill(Color.appHighlight)
                    .frame(width: 6, height: 6)
                Text("Ready")
                    .font(.caption2)
                    .foregroundColor(Color.appHighlight)
            } else {
                Circle()
                    .fill(Color.appTextMuted)
                    .frame(width: 6, height: 6)
                Text("Draft")
                    .font(.caption2)
                    .foregroundColor(Color.appTextMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview("With Audio & Image") {
    AudioEntryCard(
        entry: AudioEntryDTO(
            id: "1",
            number: 1,
            textPreview: "Hola mundo, este es un texto de prueba para ver como se ve truncado",
            audioPath: "audio/001.wav",
            imagePath: "images/001.png",
            imageFullPath: nil
        ),
        isPlaying: false,
        isGenerating: false,
        onPlay: {},
        onStop: {}
    )
    .frame(width: 170)
    .padding()
}

#Preview("Playing") {
    AudioEntryCard(
        entry: AudioEntryDTO(
            id: "2",
            number: 2,
            textPreview: "Segunda entrada con audio reproduciendose",
            audioPath: "audio/002.wav",
            imagePath: nil
        ),
        isPlaying: true,
        isGenerating: false,
        onPlay: {},
        onStop: {}
    )
    .frame(width: 170)
    .padding()
}

#Preview("Draft - No Audio") {
    AudioEntryCard(
        entry: AudioEntryDTO(
            id: "3",
            number: 3,
            textPreview: "Entrada sin audio generado todavia",
            audioPath: nil,
            imagePath: nil
        ),
        isPlaying: false,
        isGenerating: false,
        onPlay: {},
        onStop: {},
        onGenerateAudio: { print("Generate audio tapped") }
    )
    .frame(width: 170)
    .padding()
}

#Preview("Generating Audio") {
    AudioEntryCard(
        entry: AudioEntryDTO(
            id: "4",
            number: 4,
            textPreview: "Generando audio...",
            audioPath: nil,
            imagePath: nil
        ),
        isPlaying: false,
        isGenerating: true,
        onPlay: {},
        onStop: {},
        onGenerateAudio: {}
    )
    .frame(width: 170)
    .padding()
}
