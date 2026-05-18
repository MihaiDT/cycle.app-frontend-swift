import SwiftUI

// MARK: - Profile Identity Header
//
// Top card on the Profile screen. Whole card is tappable — taps push
// EditProfile. The blob avatar matches the one on MeHeaderView; the
// exact shape lives in MeHeaderView so we render a simple gradient
// disk here rather than reaching in. Visual parity, not pixel parity.

public struct ProfileIdentityHeader: View {
    public let name: String
    public let email: String?
    public let memberSince: Date
    public let onEdit: () -> Void

    private static let memberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    public init(
        name: String,
        email: String?,
        memberSince: Date,
        onEdit: @escaping () -> Void
    ) {
        self.name = name
        self.email = email
        self.memberSince = memberSince
        self.onEdit = onEdit
    }

    public var body: some View {
        Button(action: onEdit) {
            HStack(spacing: AppLayout.spacingM) {
                avatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(AppTypography.cardTitleSecondary)
                        .foregroundStyle(DesignColors.text)
                        .lineLimit(1)
                    if let email {
                        Text(email)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(DesignColors.textSecondary)
                            .lineLimit(1)
                    }
                    Text("Member since \(Self.memberFormatter.string(from: memberSince))")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
            }
            .padding(AppLayout.spacingM)
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit your details")
    }

    private var avatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        DesignColors.accentWarm,
                        DesignColors.accentWarm.opacity(0.65)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
