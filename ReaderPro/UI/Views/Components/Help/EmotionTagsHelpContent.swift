import SwiftUI

struct EmotionTagsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Controlar emociones con tags")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Puedes cambiar la emocion de la voz en diferentes partes del texto usando tags especiales.")
                    .foregroundColor(.secondary)
            }

            Divider()

            // Ejemplo principal
            VStack(alignment: .leading, spacing: 12) {
                Text("Ejemplo")
                    .font(.headline)

                exampleBox(
                    input: "[alegre] Hola! Como estas? [triste] Me siento un poco mal hoy... [susurrando] Pero no se lo digas a nadie.",
                    output: "El audio tendra tres partes: una alegre, una triste, y una susurrada."
                )
            }

            Divider()

            // Tags disponibles
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags de emocion disponibles")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(emotionTags, id: \.tag) { item in
                        tagCard(tag: item.tag, description: item.description, emoji: item.emoji)
                    }
                }
            }

            Divider()

            // Pausas
            VStack(alignment: .leading, spacing: 12) {
                Text("Pausas")
                    .font(.headline)

                Text("Puedes anadir pausas en el audio:")
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    tagCard(tag: "[pausa]", description: "Pausa de 1 segundo", emoji: "")
                    tagCard(tag: "[pausa:2s]", description: "Pausa de 2 segundos", emoji: "")
                    tagCard(tag: "[pausa:0.5s]", description: "Pausa de medio segundo", emoji: "")
                }
            }

            Divider()

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Consejos")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    tipRow(icon: "checkmark.circle.fill", color: .green,
                           text: "Los tags funcionan tanto en espanol como en ingles: [alegre] = [happy]")
                    tipRow(icon: "checkmark.circle.fill", color: .green,
                           text: "Puedes combinar tags de emocion con la configuracion de acento")
                    tipRow(icon: "exclamationmark.triangle.fill", color: .orange,
                           text: "Cada cambio de emocion genera un segmento separado, lo que puede aumentar el tiempo de generacion")
                    tipRow(icon: "info.circle.fill", color: .blue,
                           text: "Si no usas ningun tag, se aplicara la emocion seleccionada en el panel lateral")
                }
            }

            Spacer()
        }
    }

    private let emotionTags: [(tag: String, description: String, emoji: String)] = [
        ("[alegre]", "Tono alegre y entusiasta", ""),
        ("[triste]", "Tono triste y melancolico", ""),
        ("[enojado]", "Tono enojado y frustrado", ""),
        ("[susurrando]", "Susurro suave", ""),
        ("[gritando]", "Grito con enfasis", ""),
        ("[serio]", "Tono serio y formal", ""),
        ("[sarcastico]", "Tono sarcastico", ""),
        ("[emocionado]", "Emocion y anticipacion", ""),
        ("[cansado]", "Tono cansado y lento", ""),
        ("[nervioso]", "Tono nervioso y dubitativo", ""),
        ("[lento]", "Habla lenta y pausada", ""),
        ("[rapido]", "Habla rapida y energica", ""),
    ]

    private func exampleBox(input: String, output: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Escribes:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(input)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.appSecondary.opacity(0.3))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Resultado:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(output)
                    .padding()
                    .background(Color.appHighlight.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    private func tagCard(tag: String, description: String, emoji: String) -> some View {
        HStack(spacing: 12) {
            if !emoji.isEmpty {
                Text(emoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tag)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.appHighlight)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.appSecondary.opacity(0.2))
        .cornerRadius(8)
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
        }
    }
}
