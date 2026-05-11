import SwiftUI

/// Unified close button used across sheets, modals, settings
/// screens, and any chrome that owns a dismiss action.
///
/// One footprint, one glyph, one tactile response — so close
/// buttons feel identical regardless of where they appear. Use
/// this everywhere instead of hand-rolling an xmark in a circle.
///
/// - **Visual disc**: 40pt — sized to read with the same weight
///   as primary sheet headers (DayDetailView, CycleInsightsView,
///   ChallengeJourneyView). The reason it's 40 and not 36 is
///   that the native-glass surface is more transparent than the
///   tinted-fill discs older screens use; 40pt restores
///   perceptual parity.
/// - **Hit target**: 44pt — buffered per HIG so taps register
///   even on the disc's edge, and so saved-state scaling
///   (`AppDoneButton`) doesn't push the visual disc past the
///   tappable region.
/// - **Glass**: `nativeGlass` — Liquid Glass on iOS 26+, ultra
///   thin material with rim highlight on iOS 17–25.
/// - **Haptic**: soft impact fires automatically on tap.
///   Callers do not need to add their own.
public struct AppCloseButton: View {
    /// 44pt — matches the native iOS 26 toolbar disc (chevron /
    /// info buttons rendered via `ToolbarItem`), so close
    /// buttons in sheets read with the exact same footprint as
    /// chrome buttons on full screens. Visual and hit-target
    /// dimensions are equal — the disc itself is the tap zone.
    public static let visualDiameter: CGFloat = 44
    public static let hitDiameter: CGFloat = 44
    public static let glyphSize: CGFloat = 16

    private let accessibilityLabelOverride: String?
    private let action: () -> Void

    public init(
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabelOverride = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: handleTap) {
            Image(systemName: "xmark")
                .font(.system(size: Self.glyphSize, weight: .semibold))
                .foregroundStyle(DesignColors.text)
                .frame(width: Self.visualDiameter, height: Self.visualDiameter)
                .background(disc)
                .frame(minWidth: Self.hitDiameter, minHeight: Self.hitDiameter)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelOverride ?? "Close")
    }

    /// Plain `.ultraThinMaterial` disc with a soft rim
    /// highlight — same recipe as `AppDoneButton`. We avoid
    /// `.glassEffect()` (and `nativeGlass`) here because that
    /// API renders on a separate Metal layer that doesn't
    /// follow sheet slide-dismiss transitions, so the disc
    /// would briefly stay parked while the rest of the sheet
    /// moved off-screen.
    private var disc: some View {
        Circle()
            .fill(.ultraThinMaterial)
            // White wash on top of the material so the disc
            // reads with the same opacity as the iOS-26
            // toolbar discs on push screens (BodyPatternsView
            // chevron / info). Without it, the in-sheet
            // close disc reads markedly more transparent
            // than its toolbar sibling.
            .overlay {
                Circle().fill(Color.white.opacity(0.55))
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.7),
                                Color.white.opacity(0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func handleTap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        action()
    }
}
