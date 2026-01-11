import SwiftUI

// MARK: - Design Colors (Figma Palette)

public enum DesignColors {
    // Text Colors
    public static let text = Color(hex: 0x5C4A3B)  // Cocoa Dark - text important
    public static let textSecondary = Color(hex: 0x6E6A68)  // Soft Charcoal
    public static let textPlaceholder = Color(hex: 0xA69F98)  // Warm Grey

    // Glass Effect Colors
    public static let glassGray = Color(hex: 0x8C8C8C)
    public static let glassDarkTint = Color(hex: 0x171717)
    public static let glassPeach = Color(hex: 0xFDD2C9)
    public static let glassInnerGlow = Color(hex: 0xF2F2F2)
    public static let glassBorder = Color(hex: 0xA6A6A6)

    // Gradient Colors
    public static let gradientLight = Color(hex: 0xEFE1DC)
    public static let gradientMid = Color(hex: 0xA5958B)
    public static let gradientDark = Color(hex: 0x5C4A3B)

    // Accent Colors
    public static let accent = Color(hex: 0xC18F7D)
    public static let accentLight = Color(hex: 0xD6A59A)
    public static let link = Color(hex: 0x7A5F50)

    // Progress Bar
    public static let progressBackground = Color(hex: 0xF3EDEA)
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
