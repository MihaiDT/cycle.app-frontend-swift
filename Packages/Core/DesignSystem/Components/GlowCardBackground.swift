import SwiftUI

// MARK: - Glow Card Tint

/// Aurora variants for glowCardBackground. Each card type on Home gets a
/// unique "warm bloom" — a set of layered radial gradients that paint the
/// card surface like a little sunset. All tints pull from the existing
/// warm palette (blush / dusty rose / terracotta / sandstone / rose taupe).
public enum GlowCardTint: Sendable {
    /// Dawn Mist — soft blush + sandstone + rose taupe light. Feel cards.
    case neutral
    /// Ember Glow — saturated terracotta + dusty rose + blush. Do cards.
    case rose
    /// Rose Twilight — rose taupe + dusty rose + warm brown depth. Go-deeper cards.
    case taupe
    /// Sunset Glow — terracotta top + dusty rose + blush + sunny highlight. The daily challenge.
    case cocoa
}

// MARK: - Aurora Layers

@ViewBuilder
private func glowAuroraLayers(_ tint: GlowCardTint) -> some View {
    switch tint {
    case .neutral:
        // Dawn Mist: soft blush top-left, sandstone right, rose-taupe-light center bottom, cream highlight.
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accent.opacity(0.80), .clear]),
                center: UnitPoint(x: 0.25, y: 0.30),
                startRadius: 30, endRadius: 180
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.structure.opacity(0.90), .clear]),
                center: UnitPoint(x: 0.80, y: 0.60),
                startRadius: 40, endRadius: 210
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.roseTaupeLight.opacity(0.70), .clear]),
                center: UnitPoint(x: 0.55, y: 0.95),
                startRadius: 30, endRadius: 190
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.cardWarm, .clear]),
                center: UnitPoint(x: 0.05, y: 0.90),
                startRadius: 20, endRadius: 160
            )
        }

    case .rose:
        // Ember Glow: terracotta top-left, dusty rose center-right, blush bottom.
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accentWarm.opacity(0.65), .clear]),
                center: UnitPoint(x: 0.30, y: 0.25),
                startRadius: 30, endRadius: 200
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accentSecondary.opacity(0.75), .clear]),
                center: UnitPoint(x: 0.80, y: 0.65),
                startRadius: 40, endRadius: 210
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accent.opacity(0.80), .clear]),
                center: UnitPoint(x: 0.20, y: 0.95),
                startRadius: 30, endRadius: 180
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.cardWarm, .clear]),
                center: UnitPoint(x: 0.55, y: 0.05),
                startRadius: 20, endRadius: 150
            )
        }

    case .taupe:
        // Rose Twilight: rose taupe top-right, dusty rose bottom-left, warm brown depth, cream spark.
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.roseTaupe.opacity(0.85), .clear]),
                center: UnitPoint(x: 0.85, y: 0.30),
                startRadius: 30, endRadius: 210
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accentSecondary.opacity(0.75), .clear]),
                center: UnitPoint(x: 0.20, y: 0.70),
                startRadius: 40, endRadius: 220
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.warmBrown.opacity(0.55), .clear]),
                center: UnitPoint(x: 0.60, y: 1.10),
                startRadius: 20, endRadius: 200
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.cardWarm.opacity(0.80), .clear]),
                center: UnitPoint(x: 1.00, y: 0.00),
                startRadius: 20, endRadius: 170
            )
        }

    case .cocoa:
        // Sunset Glow: terracotta top-right, dusty rose bottom-right, blush left-center, cream sun.
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accentWarm.opacity(0.55), .clear]),
                center: UnitPoint(x: 0.78, y: 0.22),
                startRadius: 30, endRadius: 190
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accentSecondary.opacity(0.65), .clear]),
                center: UnitPoint(x: 0.95, y: 0.85),
                startRadius: 40, endRadius: 220
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.accent.opacity(0.75), .clear]),
                center: UnitPoint(x: 0.18, y: 0.72),
                startRadius: 30, endRadius: 220
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignColors.cardWarm, .clear]),
                center: UnitPoint(x: 0.50, y: 0.05),
                startRadius: 20, endRadius: 170
            )
        }
    }
}

// MARK: - Glow Card Background

public extension View {
    /// Aurora glow card background used across the Home card stack and the
    /// Daily Glow challenge card. Each card type passes its own `tint`, which
    /// paints a unique set of layered radial gradients over a warm cream base —
    /// each card feels like a small sunrise / sunset scene.
    ///
    /// Text on top of these cards uses the standard cocoa palette
    /// (`DesignColors.text` for titles, `textPrincipal` for body).
    ///
    /// Includes a blush-tinted 0.8pt border, corner clipping, and a warm
    /// cocoa shadow that lifts the card off the home background.
    func glowCardBackground(tint: GlowCardTint = .neutral) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                .fill(DesignColors.cardGradientStart)
                .overlay(glowAuroraLayers(tint))
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.cardWarm.opacity(0.70),
                                    DesignColors.accentWarm.opacity(0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        .shadow(color: DesignColors.text.opacity(0.18), radius: 20, x: 0, y: 8)
        .shadow(color: DesignColors.text.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}
