import SwiftUI

// MARK: - Theme

public struct ChessTheme {
    public let name: String
    public let background: Color
    public let surface: Color
    public let surfaceLight: Color
    public let primary: Color
    public let secondary: Color
    public let accent: Color
    public let textPrimary: Color
    public let textMuted: Color
    public let whiteSquare: Color
    public let blackSquare: Color

    public static let midnightStudy = ChessTheme(
        name: "Midnight Study",
        background: Color(hex: "1A1612"),
        surface: Color(hex: "2A2420"),
        surfaceLight: Color(hex: "3A3430"),
        primary: Color(hex: "E8A838"),
        secondary: Color(hex: "7EC8A0"),
        accent: Color(hex: "C85A3A"),
        textPrimary: Color(hex: "F5F0E8"),
        textMuted: Color(hex: "9A9088"),
        whiteSquare: Color(hex: "D4C4A8"),
        blackSquare: Color(hex: "8B7355")
    )
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
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
