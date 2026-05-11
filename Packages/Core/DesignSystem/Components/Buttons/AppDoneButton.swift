import SwiftUI

/// Reusable save-with-feedback action button.
///
/// Drop this into any surface that needs a "tap → committing →
/// confirmed" flow.
///
/// Visual choreography across `Phase`:
///   * `.idle` — glass disc with an outline checkmark.
///   * `.loading` — same disc, check dims to ~60% opacity so
///     the user sees the tap registered without a fussy
///     spinner.
///   * `.success` — disc tints success-green, the check fills
///     and bolds in `statusSuccess`, the disc gently scales
///     up. Soft `.success` haptic fires on entry. Parent
///     reducer auto-dismisses ~800ms later.
///
/// Two haptic moments:
///   1. `.soft` impact on tap (touch confirmation).
///   2. `.success` notification when phase flips to `.success`
///      (action confirmation).
///
/// Footprint matches `AppCloseButton` so any header pairing
/// the two reads as a balanced chrome row.
public struct AppDoneButton: View {
    public enum Phase: Equatable, Sendable {
        case idle
        case loading
        case success
    }

    public static let visualDiameter: CGFloat = AppCloseButton.visualDiameter
    public static let hitDiameter: CGFloat = AppCloseButton.hitDiameter
    public static let glyphSize: CGFloat = AppCloseButton.glyphSize

    private let phase: Phase
    private let isEnabled: Bool
    private let accessibilityLabelOverride: String?
    private let action: () -> Void

    public init(
        phase: Phase = .idle,
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.phase = phase
        self.isEnabled = isEnabled
        self.accessibilityLabelOverride = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: handleTap) {
            Image(systemName: "checkmark")
                .font(.system(
                    size: Self.glyphSize,
                    weight: phase == .success ? .bold : .semibold
                ))
                .foregroundStyle(
                    phase == .success
                        ? DesignColors.statusSuccess
                        : DesignColors.text
                )
                .opacity(phase == .loading ? 0.55 : 1.0)
                .frame(width: Self.visualDiameter, height: Self.visualDiameter)
                .background(disc)
                .scaleEffect(phase == .success ? 1.08 : 1.0)
                .opacity(isEnabled || phase != .idle ? 1.0 : 0.4)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: phase)
                .frame(minWidth: Self.hitDiameter, minHeight: Self.hitDiameter)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || phase != .idle)
        .accessibilityLabel(accessibilityLabelOverride ?? defaultAccessibilityLabel)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Disc surface

    /// Plain `.ultraThinMaterial` disc with a success tint
    /// overlay, soft white rim, and subtle drop shadow.
    /// Avoids `.glassEffect()` (and therefore `nativeGlass`)
    /// so the disc tracks the parent during sheet
    /// slide-dismiss instead of getting stranded on its own
    /// Metal layer — the success-state check used to stay
    /// visible after the sheet had already moved off-screen.
    private var disc: some View {
        Circle()
            .fill(.ultraThinMaterial)
            // Same white wash as `AppCloseButton` so the
            // close+save pair reads with the iOS-26 toolbar
            // disc weight rather than as transparent ghost
            // chrome.
            .overlay {
                Circle().fill(Color.white.opacity(0.55))
            }
            .overlay {
                Circle()
                    .fill(
                        phase == .success
                            ? DesignColors.statusSuccess.opacity(0.22)
                            : Color.clear
                    )
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

    // MARK: - Behavior

    private func handleTap() {
        guard isEnabled, phase == .idle else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        action()
    }

    private var defaultAccessibilityLabel: String {
        switch phase {
        case .idle: "Done"
        case .loading: "Saving"
        case .success: "Saved"
        }
    }
}
