import SwiftUI

// MARK: - Hero Glass Capsule Button
//
// White-glass capsule CTA used as the primary "soft" action across the
// app — sibling to `GlassButton` but lighter and brighter so it reads
// well over warm hero gradients and on top of editorial card surfaces.
//
// Four layouts:
//   • `.small`   — tight inline pill for secondary affordances inside
//                  card headers (e.g. "See all" on Cycle History).
//                  Slightly muted text so the title keeps the spotlight.
//   • `.compact` — hugs content. Used inline next to other controls
//                  (e.g. "My cycle" on the home hero).
//   • `.large`   — generous pill for primary CTAs. Hugs content, no
//                  chevron, larger padding so the button feels weighty
//                  on full-screen flows (e.g. "Sync with Apple" on the
//                  Body Signals access flow).
//   • `.wide`    — expands to fill the available width and shows a
//                  trailing chevron. Used as the dominant CTA inside
//                  cards (e.g. "Enable body signals" on the prompt
//                  state of the Body Signals card).
//
// All layouts trigger a light haptic on tap. Callers can attach
// `.accessibilityHint(_:)` directly when extra context is needed.

public struct HeroGlassCapsuleButton: View {
    public enum Layout: Sendable {
        /// Tight inline pill for secondary affordances. No chevron.
        case small
        /// Hugs content. No chevron. Used inline on hero surfaces.
        case compact
        /// Generous pill for primary CTAs. Hugs content, no chevron.
        case large
        /// Full-width with trailing chevron. Used as a card CTA.
        case wide
    }

    public let title: String
    public let layout: Layout
    public let action: () -> Void

    @State private var hapticTrigger: Int = 0

    public init(
        _ title: String,
        layout: Layout = .compact,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.layout = layout
        self.action = action
    }

    public var body: some View {
        Button {
            hapticTrigger &+= 1
            action()
        } label: {
            label
                .heroGlassCapsule()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    @ViewBuilder
    private var label: some View {
        switch layout {
        case .small:
            Text(title)
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

        case .compact:
            Text(title)
                .font(.raleway("SemiBold", size: 15, relativeTo: .callout))
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)

        case .large:
            Text(title)
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.vertical, 16)

        case .wide:
            HStack(spacing: 8) {
                Text(title)
                    .font(.raleway("SemiBold", size: 14, relativeTo: .callout))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignColors.text.opacity(0.6))
            }
            .foregroundStyle(DesignColors.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Previews

#Preview("Hero Glass Capsule") {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.95, green: 0.83, blue: 0.78), Color(red: 0.82, green: 0.71, blue: 0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            HeroGlassCapsuleButton("See all", layout: .small) {}

            HeroGlassCapsuleButton("My cycle") {}

            HeroGlassCapsuleButton("Enable body signals", layout: .wide) {}
                .padding(.horizontal, 32)
        }
    }
}
