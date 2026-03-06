import SwiftUI

struct VoiceCloningHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Clonar una voz")
                .font(.title)
                .fontWeight(.bold)

            Text("Puedes clonar cualquier voz con solo 3-5 segundos de audio de referencia.")
                .foregroundColor(.secondary)

            Divider()

            // Pasos
            VStack(alignment: .leading, spacing: 16) {
                Text("Como clonar una voz")
                    .font(.headline)

                stepRow(number: 1, title: "Selecciona Qwen3 como proveedor",
                        description: "La clonacion solo esta disponible con el motor Qwen3.")

                stepRow(number: 2, title: "Activa 'Clonar voz'",
                        description: "En el panel lateral, activa el switch de clonacion.")

                stepRow(number: 3, title: "Sube un audio de referencia",
                        description: "Selecciona un archivo .wav o .mp3 de 3-10 segundos con la voz que quieres clonar.")

                stepRow(number: 4, title: "(Opcional) Anade transcripcion",
                        description: "Si anades el texto exacto del audio, la clonacion sera mas precisa.")

                stepRow(number: 5, title: "Genera audio",
                        description: "El texto se generara con la voz clonada.")
            }

            Divider()

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Consejos para mejor clonacion")
                    .font(.headline)

                tipCard(icon: "waveform", color: .blue,
                        title: "Audio limpio",
                        description: "Usa audio sin ruido de fondo, musica ni eco.")

                tipCard(icon: "timer", color: .orange,
                        title: "Duracion optima",
                        description: "5-10 segundos es ideal. Mas de 15 segundos no mejora y ralentiza.")

                tipCard(icon: "text.quote", color: .green,
                        title: "Incluye transcripcion",
                        description: "Anadir el texto exacto del audio mejora significativamente la calidad.")

                tipCard(icon: "speaker.wave.2", color: .purple,
                        title: "Voz natural",
                        description: "Usa audio con habla natural, no leido de forma monotona.")
            }

            Divider()

            // Opciones avanzadas
            VStack(alignment: .leading, spacing: 12) {
                Text("Opciones avanzadas")
                    .font(.headline)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modo rapido (x-vector)")
                            .fontWeight(.medium)
                        Text("Genera mas rapido pero con menor fidelidad de voz. Util para pruebas.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.appSecondary.opacity(0.2))
                .cornerRadius(8)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cpu")
                        .foregroundColor(.cyan)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modelo ligero (0.6B)")
                            .fontWeight(.medium)
                        Text("Usa el modelo de 0.6B parametros. Mas rapido y menos RAM, pero calidad reducida.")
                            .font(.subheadline)
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

    private func stepRow(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.appHighlight)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tipCard(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appSecondary.opacity(0.2))
        .cornerRadius(8)
    }
}
