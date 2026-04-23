import SwiftUI

// MARK: - Glass Selection Card

public struct GlassSelectionCard<Icon: View>: View {
    public let title: String
    public let description: String?
    public let isSelected: Bool
    public let action: () -> Void
    @ViewBuilder public let icon: () -> Icon

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        description: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.action = action
        self.icon = icon
    }

    private var accessibilityText: String {
        if let description, !description.isEmpty {
            return "\(title). \(description)"
        }
        return title
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: isSelected
                                        ? [DesignColors.accentWarm, DesignColors.accentSecondary.opacity(0.6)]
                                        : [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .shadow(
                        color: isSelected
                            ? DesignColors.accentWarm.opacity(0.3)
                            : Color.black.opacity(0.08),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnboardingBackground()

        VStack(spacing: 16) {
            HStack(spacing: 16) {
                GlassSelectionCard(
                    title: "Separated",
                    isSelected: false,
                    action: {}
                ) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(DesignColors.text)
                }

                GlassSelectionCard(
                    title: "Single",
                    isSelected: true,
                    action: {}
                ) {
                    Image(systemName: "person")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(DesignColors.text)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
