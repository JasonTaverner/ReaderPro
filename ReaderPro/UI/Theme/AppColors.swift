import SwiftUI

extension Color {
    static let appPrimary = Color(hex: "121212")      // Fondo principal (Negro)
    static let appSecondary = Color(hex: "282828")    // Cards, Paneles y Botones secundarios
    static let appTertiary = Color(hex: "0E0E0E")     // Texto secundario, Iconos y Bordes sutiles
    static let appAccent = Color(hex: "424242")       // SPOTIFY (Solo para la acción principal)
    static let appHighlight = Color(hex: "D97205")    // Textos principales y Títulos

    // Variantes para texto
    static let appTextPrimary = Color.white
    static let appTextSecondary = Color.white.opacity(0.8)
    static let appTextMuted = Color.white.opacity(0.6)
    
    // Helper para hex
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appTertiary)
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
