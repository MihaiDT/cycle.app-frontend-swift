import SwiftUI

// MARK: - Sheet Header
//
// Global header for full-screen sheets and destination views. Xmark
// dismiss button pinned left, centered title (optional eyebrow meta
// above). Mirrors the `DayDetailView` header treatment so every
// destination-style screen in the app reads as part of the same system.

public struct SheetHeader: View {
    public let title: String
    public let eyebrow: String?
    public let onDismiss: () -> Void

    public init(title: String, eyebrow: String? = nil, onDismiss: @escaping () -> Void) {
        self.title = title
        self.eyebrow = eyebrow
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .center) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 44, height: 44)
                    .background {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.9), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .padding(2)
                                .offset(y: -2)
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                        .tracking(1.2)
                        .foregroundStyle(DesignColors.textSecondary)
                }
                Text(title)
                    .font(.raleway("Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
            }
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, AppLayout.spacingS)
        .padding(.bottom, AppLayout.spacingM)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        VStack {
            SheetHeader(title: "Cycle Stats", eyebrow: "Averages", onDismiss: {})
            Spacer()
        }
    }
}
