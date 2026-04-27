import SwiftUI

// MARK: - Personal Reading
//
// Hero card on each stat info screen — same Apple Health pattern as
// the Body Signals detail cards. Caps eyebrow + big primary value +
// quiet status caption, all wrapped in `widgetCardStyle`.

struct CycleStatInfoPersonalReading: View {
    let kind: CycleStatInfoKind
    let previousValue: String?
    let badge: CycleStatusBadge?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.recapLabel.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(previousValue ?? "No data")
                    .font(.raleway(
                        previousValue != nil ? "Bold" : "SemiBold",
                        size: previousValue != nil ? 30 : 20,
                        relativeTo: .largeTitle
                    ))
                    .tracking(-0.4)
                    .foregroundStyle(
                        previousValue != nil
                            ? DesignColors.text
                            : DesignColors.text.opacity(0.5)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)

                if let badge {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(badgeDotColor(for: badge.tone))
                            .frame(width: 6, height: 6)
                        Text(badge.label.lowercased())
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                            .tracking(0.4)
                            .foregroundStyle(badgeTextColor(for: badge.tone))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let value = previousValue ?? "no data"
        let suffix = badge.map { ", \($0.label.lowercased())" } ?? ""
        return "\(kind.recapLabel), \(value)\(suffix)"
    }

    private func badgeDotColor(for tone: CycleStatusTone) -> Color {
        switch tone {
        case .normal:         return DesignColors.statusSuccess
        case .needsAttention: return DesignColors.accentHoney
        }
    }

    private func badgeTextColor(for tone: CycleStatusTone) -> Color {
        switch tone {
        case .normal:         return DesignColors.statusSuccess
        case .needsAttention: return DesignColors.accentHoneyText
        }
    }
}
