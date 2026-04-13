import SwiftUI

// MARK: - Rating Badge

struct RatingBadge: View {
    let rating: String
    var size: CGFloat = 32
    var animated: Bool = false

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
        case "gold": Color(red: 1.0, green: 0.84, blue: 0.0)
        case "silver": Color(red: 0.75, green: 0.75, blue: 0.78)
        case "bronze": Color(red: 0.80, green: 0.50, blue: 0.20)
        default: DesignColors.accentWarm
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: size * 0.6))
            Text(label)
                .font(.custom("Raleway-SemiBold", size: size * 0.45))
                .foregroundStyle(DesignColors.text)
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
        .scaleEffect(animated ? scale : 1)
        .onAppear {
            guard animated else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1
            }
        }
    }
}
