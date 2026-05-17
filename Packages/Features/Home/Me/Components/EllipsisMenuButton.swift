import SwiftUI

// MARK: - Ellipsis Menu Button
//
// Small 26pt disc with three dots used as the contextual menu
// affordance in the top-right corner of the Daily Insight card.
// Renders a plain ivory disc + a glyph; no chrome competes with
// the card body.

public struct EllipsisMenuButton: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void = {}) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DesignColors.background)
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColors.textCard)
            }
            .frame(width: 26, height: 26)
            .overlay(
                Circle().strokeBorder(DesignColors.divider.opacity(0.45), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options")
    }
}

#Preview {
    EllipsisMenuButton()
        .padding(40)
        .background(DesignColors.cardWarm)
}
