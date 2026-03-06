import SwiftUI

struct VoicesHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Voces disponibles")
                .font(.title)
                .fontWeight(.bold)

            Text("ReaderPro incluye dos motores de voz: Kokoro (rapido) y Qwen3 (mas expresivo).")
                .foregroundColor(.secondary)

            Divider()

            // Kokoro
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "hare.fill")
                        .foregroundColor(Color.appHighlight)
                    Text("Kokoro")
                        .font(.headline)
                    Text("Rapido")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Text("Motor ligero y rapido, ideal para textos largos. 37 voces en multiples idiomas.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.appSecondary.opacity(0.2))
            .cornerRadius(12)

            // Qwen3
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color.appHighlight)
                    Text("Qwen3")
                        .font(.headline)
                    Text("Expresivo")
                        .font(.caption)
                        .foregroundColor(Color.appHighlight)
                }

                Text("Motor avanzado con control de emociones, acentos y clonacion de voz. Mas lento pero mas natural.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Funciones exclusivas de Qwen3:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        featureBadge("Emociones", icon: "face.smiling")
                        featureBadge("Acentos", icon: "globe")
                        featureBadge("Clonar voz", icon: "mic.badge.plus")
                    }
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color.appSecondary.opacity(0.2))
            .cornerRadius(12)

            Divider()

            // Voces Qwen3
            VStack(alignment: .leading, spacing: 12) {
                Text("Voces Qwen3 (9 premium)")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    voiceBadge("Vivian", style: "Calida", gender: "F")
                    voiceBadge("Serena", style: "Calmada", gender: "F")
                    voiceBadge("Ono Anna", style: "Brillante", gender: "F")
                    voiceBadge("Sohee", style: "Suave", gender: "F")
                    voiceBadge("Ryan", style: "Energetico", gender: "M")
                    voiceBadge("Dylan", style: "Joven", gender: "M")
                    voiceBadge("Eric", style: "Neutral", gender: "M")
                    voiceBadge("Aiden", style: "Amigable", gender: "M")
                    voiceBadge("Uncle Fu", style: "Profunda", gender: "M")
                }
            }

            Divider()

            // Acentos
            VStack(alignment: .leading, spacing: 12) {
                Text("Acentos disponibles (Qwen3)")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    accentBadge("ES", "Espana")
                    accentBadge("MX", "Mexico")
                    accentBadge("AR", "Argentina")
                    accentBadge("FR", "Francia")
                    accentBadge("DE", "Alemania")
                    accentBadge("IT", "Italia")
                    accentBadge("BR", "Brasil")
                    accentBadge("PT", "Portugal")
                    accentBadge("RU", "Rusia")
                }
            }

            Spacer()
        }
    }

    private func featureBadge(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appHighlight.opacity(0.3))
        .cornerRadius(6)
    }

    private func voiceBadge(_ name: String, style: String, gender: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: gender == "F" ? "person.fill" : "person.fill")
                .font(.caption2)
                .foregroundColor(gender == "F" ? .pink : .cyan)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(style)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appSecondary.opacity(0.3))
        .cornerRadius(6)
    }

    private func accentBadge(_ code: String, _ name: String) -> some View {
        HStack(spacing: 4) {
            Text(code)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color.appHighlight)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appSecondary.opacity(0.3))
        .cornerRadius(6)
    }
}
