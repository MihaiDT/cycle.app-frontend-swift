import SwiftUI

// MARK: - Personal Reading
//
// Under the header illustration, one quiet row pins the reference
// range (established by the image) to the user's own measurement —
// label, value, verdict badge. The rules above and below replace a
// tinted card so the reading stays chrome-free.

struct CycleStatInfoPersonalReading: View {
    let kind: CycleStatInfoKind
    let previousValue: String?
    let badge: CycleStatusBadge?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thinRule
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(kind.recapLabel.uppercased())
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
                Spacer(minLength: 8)
            }
            .padding(.top, 18)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(previousValue ?? "No data")
                    .font(.raleway(
                        previousValue != nil ? "Bold" : "SemiBold",
                        size: previousValue != nil ? 30 : 20,
                        relativeTo: .title
                    ))
                    .tracking(-0.4)
                    .foregroundStyle(
                        previousValue != nil
                            ? DesignColors.text
                            : DesignColors.text.opacity(0.45)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let badge {
                    Text(badge.label)
                        .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(badgeColor(for: badge.tone))
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 18)

            thinRule
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let value = previousValue ?? "no data"
        let suffix = badge.map { ", \($0.label.lowercased())" } ?? ""
        return "\(kind.recapLabel), \(value)\(suffix)"
    }

    private func badgeColor(for tone: CycleStatusTone) -> Color {
        switch tone {
        case .normal:         return DesignColors.statusSuccess
        case .needsAttention: return DesignColors.accentWarmText
        }
    }

    private var thinRule: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(0.10))
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}
