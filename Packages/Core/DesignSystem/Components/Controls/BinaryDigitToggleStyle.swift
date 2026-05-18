import SwiftUI

// MARK: - Binary Digit Toggle Style
//
// Replaces the system Toggle visual with a track that carries the
// IEC 60417 power-switch glyphs — a vertical bar (⏽) for on, an
// open circle (⭘) for off — drawn as native shapes so they stay
// crisp at any pixel density. The glyph lives in the EMPTY half
// of the track, opposite the thumb, so the white circle never
// covers it.
//
// Applied app-wide from `AppView` via `.toggleStyle(.binaryDigit)`
// so every `Toggle` across Profile, Settings, Tracking, etc. picks
// it up automatically.
//
// Design notes:
// - Track dimensions match Apple's stock toggle (51×31) so it sits
//   nicely next to system rows without throwing off the spacing.
// - On state uses DesignColors.accentWarm to stay on-brand; off
//   state is a muted neutral built from textSecondary so it reads
//   as "inactive" on both light and dark surfaces.
// - Glyphs are drawn from Shape primitives (Rectangle + Circle)
//   instead of unicode text so the stroke width and corner radius
//   stay under direct control and the icon doesn't rely on a font.
// - Tap target is the full HStack (label + switch) per Apple's
//   accessibility guidance.

public struct BinaryDigitToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 0)
            BinaryDigitSwitch(isOn: configuration.isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                configuration.isOn.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

public extension ToggleStyle where Self == BinaryDigitToggleStyle {
    /// Brand toggle: shows `1` in the on-state's empty track half,
    /// `0` in the off-state's empty track half. Pair with the
    /// system Toggle initialiser unchanged at the callsite.
    static var binaryDigit: BinaryDigitToggleStyle { BinaryDigitToggleStyle() }
}

// MARK: - Switch primitive

private struct BinaryDigitSwitch: View {
    let isOn: Bool

    private let trackWidth: CGFloat = 51
    private let trackHeight: CGFloat = 31
    private let thumbInset: CGFloat = 2

    private var thumbSize: CGFloat { trackHeight - thumbInset * 2 }
    private var thumbTravel: CGFloat { (trackWidth - trackHeight) / 2 }

    private var trackTint: Color {
        isOn ? DesignColors.accentWarm : DesignColors.textSecondary.opacity(0.28)
    }

    var body: some View {
        ZStack {
            track

            // IEC 60417 glyph — vertical bar when on, open circle
            // when off. Drawn as shapes so the strokes stay pixel-
            // crisp at any scale.
            powerGlyph
                .frame(width: thumbSize, height: thumbSize)
                .offset(x: isOn ? -thumbTravel : thumbTravel)

            thumb
        }
        .frame(width: trackWidth, height: trackHeight)
        .accessibilityHidden(true) // The parent Toggle handles a11y.
    }

    @ViewBuilder
    private var track: some View {
        if #available(iOS 26.0, *) {
            // Liquid Glass — the tint propagates through the glass
            // pass so the track reads as accent-coloured frosted
            // material rather than a flat fill.
            Color.clear
                .frame(width: trackWidth, height: trackHeight)
                .glassEffect(
                    .regular.tint(trackTint),
                    in: Capsule()
                )
        } else {
            // Pre-iOS 26 fallback: solid fill so the track still
            // reads as the brand colour even when the OS doesn't
            // ship the glass shader.
            Capsule()
                .fill(trackTint)
                .frame(width: trackWidth, height: trackHeight)
        }
    }

    @ViewBuilder
    private var thumb: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .frame(width: thumbSize, height: thumbSize)
                .glassEffect(.regular.interactive(), in: Circle())
                .offset(x: isOn ? thumbTravel : -thumbTravel)
        } else {
            Circle()
                .fill(Color.white)
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
                .offset(x: isOn ? thumbTravel : -thumbTravel)
        }
    }

    @ViewBuilder
    private var powerGlyph: some View {
        if isOn {
            // Vertical bar (⏽). Rounded ends so it looks intentional
            // at small sizes; ~half the thumb's height for proportion.
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(width: 2, height: 12)
        } else {
            // Open circle (⭘). Stroked, not filled, so it reads as
            // "open / off" rather than a dot.
            Circle()
                .strokeBorder(Color.white.opacity(0.92), lineWidth: 1.6)
                .frame(width: 11, height: 11)
        }
    }
}
