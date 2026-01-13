import SwiftUI

// MARK: - Design Colors (Figma Palette)

public enum DesignColors {
    // MARK: - Backgrounds
    public static let background = Color(hex: 0xFDFCF7)  // Ivory Whisper - fundal
    public static let backgroundElegant = Color(hex: 0xFDFCF7)  // Champagne Silk - eleganta, confort

    // MARK: - Text Colors
    public static let text = Color(hex: 0x5C4A3B)  // Cocoa Dark - text important
    public static let textPrincipal = Color(hex: 0x7A5F50)  // Deep Cocoa - text principal/contrast
    public static let textSecondary = Color(hex: 0x6E6A68)  // Soft Charcoal - text secundar
    public static let textPlaceholder = Color(hex: 0xA69F98)  // Warm Grey - placeholder
    public static let textCard = Color(hex: 0xB49B87)  // Rose Taupe - text secundar/card-uri

    // MARK: - Accent Colors
    public static let accent = Color(hex: 0xEBCFC3)  // Soft Blush - primary accent butoane principale
    public static let accentSecondary = Color(hex: 0xD6A59A)  // Dusty Rose - accent secundar, hover, active
    public static let accentWarm = Color(hex: 0xC18F7D)  // Terracotta Warm - alert/highlight bland

    // MARK: - Structure Colors
    public static let structure = Color(hex: 0xDECBC1)  // Warm Sandstone - structura vizuala
    public static let divider = Color(hex: 0xD8D3CB)  // Moonlit Grey - divider/borders subtle

    // MARK: - Rose Taupe - for periods/feminine accents
    public static let roseTaupe = Color(hex: 0xC8ADA7)  // Rose Taupe - accent feminin, cald
    public static let roseTaupeLight = Color(hex: 0xD6C5C0)  // Rose Taupe lighter

    // MARK: - Gradient Colors (mapped to palette)
    public static let gradientLight = Color(hex: 0xDECBC1)  // Warm Sandstone
    public static let gradientMid = Color(hex: 0xB49B87)  // Rose Taupe (text card)
    public static let gradientDark = Color(hex: 0x5C4A3B)  // Cocoa Dark

    // MARK: - Glass Effect Colors (for liquid glass UI)
    public static let glassGray = Color(hex: 0xA69F98)  // Warm Grey
    public static let glassDarkTint = Color(hex: 0x5C4A3B)  // Cocoa Dark
    public static let glassPeach = Color(hex: 0xEBCFC3)  // Soft Blush
    public static let glassInnerGlow = Color(hex: 0xFDFCF7)  // Ivory Whisper

    // MARK: - Legacy/Compatibility (mapped to palette)
    public static let link = Color(hex: 0x7A5F50)  // Deep Cocoa
    public static let accentLight = Color(hex: 0xD6A59A)  // Dusty Rose
    public static let periodPink = Color(hex: 0xC8ADA7)  // Rose Taupe
    public static let periodPinkLight = Color(hex: 0xD6C5C0)  // Rose Taupe Light
    public static let progressBackground = Color(hex: 0xDECBC1)  // Warm Sandstone
}

extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
