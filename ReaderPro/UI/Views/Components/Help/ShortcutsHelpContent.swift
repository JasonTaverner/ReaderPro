import SwiftUI

struct ShortcutsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Atajos de teclado")
                .font(.title)
                .fontWeight(.bold)

            Text("Usa estos atajos para trabajar mas rapido con ReaderPro.")
                .foregroundColor(.secondary)

            Divider()

            // Generacion
            VStack(alignment: .leading, spacing: 12) {
                Text("Generacion de audio")
                    .font(.headline)

                shortcutRow(keys: "Cmd + G", action: "Generar audio del texto actual")
                shortcutRow(keys: "Cmd + Shift + G", action: "Generar audio de todas las entradas")
                shortcutRow(keys: "Cmd + S", action: "Guardar proyecto")
            }

            Divider()

            // Reproduccion
            VStack(alignment: .leading, spacing: 12) {
                Text("Reproduccion")
                    .font(.headline)

                shortcutRow(keys: "Space", action: "Reproducir / Pausar")
                shortcutRow(keys: "Cmd + .", action: "Detener reproduccion")
            }

            Divider()

            // Edicion
            VStack(alignment: .leading, spacing: 12) {
                Text("Edicion")
                    .font(.headline)

                shortcutRow(keys: "Cmd + N", action: "Nuevo proyecto")
                shortcutRow(keys: "Cmd + I", action: "Importar texto")
                shortcutRow(keys: "Cmd + E", action: "Exportar audio")
            }

            Divider()

            // Captura
            VStack(alignment: .leading, spacing: 12) {
                Text("Captura")
                    .font(.headline)

                shortcutRow(keys: "Cmd + Shift + 4", action: "Captura de pantalla con OCR")
                shortcutRow(keys: "Cmd + Shift + V", action: "Pegar desde portapapeles")
            }

            Spacer()
        }
    }

    private func shortcutRow(keys: String, action: String) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(keys.components(separatedBy: " + "), id: \.self) { key in
                    Text(key)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.appTertiary, lineWidth: 1)
                        )

                    if key != keys.components(separatedBy: " + ").last {
                        Text("+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 160, alignment: .leading)

            Text(action)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
