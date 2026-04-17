import SwiftUI

// MARK: - Rating Badge

struct RatingBadge: View {
    let rating: String
    var size: CGFloat = 32
    var animated: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0

    private var emoji: String {
        switch rating {
        case "gold": "🥇"
        case "silver": "🥈"
        case "bronze": "🥉"
        default: "⭐"
        }
    }

    private var label: String {
        rating.capitalized
    }

    private var badgeColor: Color {
        switch rating {
        case "gold": DesignColors.ratingGold
        case "silver": DesignColors.ratingSilver
        case "bronze": DesignColors.ratingBronze
        default: DesignColors.accentWarm
        }
    }

    private var accessibilityDescription: String {
        "Rating: \(label)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: size * 0.6))
                .accessibilityHidden(true)
            Text(label)
                .font(.raleway("SemiBold", size: size * 0.45, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(badgeColor.opacity(0.15))
                .overlay {
                    Capsule()
                        .strokeBorder(badgeColor.opacity(0.3), lineWidth: 1)
                }
        }
        .scaleEffect(animated && !reduceMotion ? scale : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            guard animated, !reduceMotion else {
                scale = 1
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1
            }
        }
    }
}
