import SwiftUI
import AppKit

/// Vista de detalle para mostrar una imagen en pantalla completa
/// Permite zoom, pan y cerrar con Escape o click fuera
struct ImageDetailView: View {

    // MARK: - Properties

    let imagePath: String
    let textContent: String?
    let onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fondo oscuro semi-transparente
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onClose()
                    }

                VStack(spacing: 0) {
                    // Toolbar con botón de cerrar
                    HStack {
                        Spacer()

                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding()

                    // Imagen con zoom y pan
                    if let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 0.5), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Imagen no encontrada
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("Imagen no encontrada")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Panel de texto (si hay contenido)
                    if let text = textContent, !text.isEmpty {
                        ScrollView {
                            Text(text)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: geometry.size.height * 0.3)
                        .background(Color.black.opacity(0.6))
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Preview

#Preview("Image Detail") {
    ImageDetailView(
        imagePath: "/tmp/test.png",
        textContent: "Este es el texto reconocido de la imagen mediante OCR. Puede contener múltiples líneas y párrafos que el usuario puede leer con más detalle.",
        onClose: {}
    )
}

#Preview("Image Detail - No Text") {
    ImageDetailView(
        imagePath: "/tmp/test.png",
        textContent: nil,
        onClose: {}
    )
}
