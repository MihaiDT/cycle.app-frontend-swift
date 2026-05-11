import SwiftUI

// MARK: - Collapsible Medical Disclaimer
//
// Compact, accordion-style variant of `MedicalDeviceDisclaimer`
// for screens where the full three-paragraph disclaimer would
// crowd the layout (e.g. `PatternDetailScreen`, where the bottom
// of the scroll is already busy with stats + editorial). Reuses
// the exact copy from `MedicalDeviceDisclaimer.bodyText` /
// `.emergencyText` so the legal posture stays identical to the
// expanded variant — single source of truth.
//
// Default state is collapsed (eyebrow + chevron only). Tapping
// the row expands the body inline. Use this on data / detail
// surfaces; keep the full `MedicalDeviceDisclaimer` on the
// educational explainer screens (How patterns work, When to
// see a doctor, About) where the disclaimer IS part of the
// content the user is reading.

struct CollapsibleMedicalDisclaimer: View {
    /// Externally owned so the host screen can react to state
    /// changes (e.g. trim trailing scroll padding when collapsed).
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            header
            if isExpanded {
                expandedBody
                    // Pure opacity transition — the surrounding
                    // VStack interpolates its own height with the
                    // spring animation, so the body fades in as
                    // space opens downward. Earlier `.move(edge:
                    // .top)` slid the body from above its final
                    // position and visually crossed the tile grid.
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Header (always visible)

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        } label: {
            HStack(spacing: 8) {
                Text(MedicalDeviceDisclaimer.eyebrow)
                    .font(.raleway("Bold", size: 12, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.accentWarmText)
                    .textCase(.uppercase)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignColors.accentWarmText.opacity(0.65))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(MedicalDeviceDisclaimer.eyebrow)
        .accessibilityHint(isExpanded ? "Hide details" : "Show details")
    }

    // MARK: - Expanded body

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(MedicalDeviceDisclaimer.bodyText)
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(MedicalDeviceDisclaimer.emergencyText)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
