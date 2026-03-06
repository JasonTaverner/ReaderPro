import SwiftUI

struct ExportHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Exportar audio")
                .font(.title)
                .fontWeight(.bold)

            Text("Exporta tu audio generado en diferentes formatos y calidades.")
                .foregroundColor(.secondary)

            Divider()

            // Formatos
            VStack(alignment: .leading, spacing: 12) {
                Text("Formatos disponibles")
                    .font(.headline)

                formatCard(
                    format: "WAV",
                    description: "Sin comprension, maxima calidad. Archivos grandes.",
                    quality: "Lossless",
                    qualityColor: .green
                )

                formatCard(
                    format: "MP3",
                    description: "Comprimido, buena calidad. Compatible con todos los reproductores.",
                    quality: "Lossy",
                    qualityColor: .orange
                )

                formatCard(
                    format: "M4A (AAC)",
                    description: "Comprimido, mejor calidad que MP3 al mismo tamano.",
                    quality: "Lossy",
                    qualityColor: .orange
                )
            }

            Divider()

            // Merge / Fusion
            VStack(alignment: .leading, spacing: 12) {
                Text("Fusion de entradas")
                    .font(.headline)

                Text("Si tu proyecto tiene multiples entradas, puedes fusionarlas en un solo archivo:")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    mergeOption(
                        icon: "waveform.path",
                        title: "Audio completo",
                        description: "Une todos los audios en un solo archivo WAV."
                    )
                    mergeOption(
                        icon: "doc.text",
                        title: "Texto completo",
                        description: "Concatena todos los textos en un solo archivo TXT."
                    )
                    mergeOption(
                        icon: "photo.stack",
                        title: "Imagenes en PDF",
                        description: "Genera un PDF con todas las imagenes capturadas."
                    )
                }
            }

            Divider()

            // Ubicacion
            VStack(alignment: .leading, spacing: 12) {
                Text("Ubicacion de archivos")
                    .font(.headline)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(Color.appHighlight)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Los proyectos se guardan en:")
                            .font(.subheadline)
                        Text("~/Documents/KokoroLibrary/[NombreProyecto]/")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.appHighlight)
                        Text("Cada entrada tiene su archivo de texto (.txt), audio (.wav) e imagen (.png) con el mismo numero.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.appSecondary.opacity(0.2))
                .cornerRadius(8)
            }

            Spacer()
        }
    }

    private func formatCard(format: String, description: String, quality: String, qualityColor: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundColor(Color.appHighlight)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(format)
                        .fontWeight(.semibold)
                    Text(quality)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(qualityColor.opacity(0.2))
                        .foregroundColor(qualityColor)
                        .cornerRadius(4)
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.appSecondary.opacity(0.2))
        .cornerRadius(8)
    }

    private func mergeOption(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.appHighlight)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
