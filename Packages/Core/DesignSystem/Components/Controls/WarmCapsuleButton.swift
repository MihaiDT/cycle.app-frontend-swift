import SwiftUI

// MARK: - Warm Capsule Button
//
// Primary "warm" CTA used across Calendar surfaces (period editing,
// empty states). Sibling to `GlassButton` (Liquid Glass) and
// `HeroGlassCapsuleButton` (white glass) — this one carries the app's
// signature `accentWarm → accentSecondary` gradient with a soft top
// gloss and warm shadow.
//
// Two prominences:
//   • `.compact` — snug inline pill (h22/v10) for CTAs that live
//                  alongside other controls (e.g. "Edit Period" on
//                  the Calendar bottom bar).
//   • `.primary` — generous pill (h26/v14) for the dominant action of
//                  the screen (e.g. "Save Period", "Log my first
//                  period").
//
// Optional leading SF Symbol icon. Light haptic on tap.

public struct WarmCapsuleButton: View {
    public enum Prominence: Sendable {
        case compact
        case primary
    }

    public let title: String
    public let icon: String?
    public let prominence: Prominence
    public let isFullWidth: Bool
    public let action: () -> Void

    @State private var hapticTrigger: Int = 0

    public init(
        _ title: String,
        icon: String? = nil,
        prominence: Prominence = .compact,
        isFullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.prominence = prominence
        self.isFullWidth = isFullWidth
        self.action = action
    }

    public var body: some View {
        Button {
            hapticTrigger &+= 1
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 12, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel(title)
    }

    private var hPadding: CGFloat {
        switch prominence {
        case .compact: 22
        case .primary: 26
        }
    }

    private var vPadding: CGFloat {
        switch prominence {
        case .compact: 10
        case .primary: 14
        }
    }
}

// MARK: - Previews

#Preview("Warm Capsule Buttons") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        VStack(spacing: 20) {
            WarmCapsuleButton("Edit Period", icon: "drop.fill") {}
            WarmCapsuleButton("Log my first period", icon: "plus", prominence: .primary) {}
            WarmCapsuleButton("Save Period", prominence: .primary) {}
            WarmCapsuleButton("Cancel") {}
            WarmCapsuleButton("Talk to Aria", icon: "message.fill", prominence: .primary, isFullWidth: true) {}
                .padding(.horizontal, 20)
        }
    }
}
