import SwiftUI

// MARK: - Glass Button (Reusable)

public struct GlassButton: View {
    public let title: String
    public let showArrow: Bool
    public let width: CGFloat
    public let height: CGFloat
    public let accessibilityLabelOverride: String?
    public let action: () -> Void

    public init(
        _ title: String,
        showArrow: Bool = false,
        width: CGFloat = 203,
        height: CGFloat = 55,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.showArrow = showArrow
        self.width = width
        self.height = height
        self.accessibilityLabelOverride = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignColors.text)

                if showArrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignColors.text)
                        .accessibilityHidden(true)
                }
            }
            .frame(minWidth: width, minHeight: height)
            .glassEffectCapsule()
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelOverride ?? title)
    }
}

// MARK: - Convenience Factories

extension GlassButton {
    /// Creates a "Begin" button with arrow icon
    public static func begin(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Begin", showArrow: true, action: action)
    }

    /// Creates a "Continue" button with arrow icon
    public static func `continue`(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Continue", showArrow: true, action: action)
    }

    /// Creates a "Next" button without arrow
    public static func next(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Next", showArrow: false, action: action)
    }

    /// Creates a "Done" button without arrow
    public static func done(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Done", showArrow: false, action: action)
    }
}

// MARK: - Glass Back Button (Round)

public struct GlassBackButton: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityHint("Returns to the previous screen")
    }
}

// MARK: - Previews

#Preview("Begin Button") {
    ZStack {
        LinearGradient(
            colors: [.white, Color(red: 0.85, green: 0.75, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassButton.begin {}
            GlassButton.continue {}
            GlassButton.next {}
            GlassButton.done {}
            GlassButton("Custom", showArrow: true) {}
        }
    }
}
