import SwiftUI

// MARK: - Me Header Round Button
//
// Button used in the ME tab header. Two flavours:
//   • `.avatar` — the peach blob asset (same one used by
//     `BondsCard.youCircle`) with a profile glyph laid over it.
//     The blob's natural irregular silhouette is preserved — no
//     circular clip, no stroke, no shadow — so the avatar reads
//     as a tiny version of the user's bond, not a UI chip.
//   • `.icon(systemName:)` — classic ivory disc with a hairline
//     border + soft shadow + SF Symbol. Used for utility buttons
//     (settings gear, etc.).

public struct MeHeaderRoundButton: View {
    public enum Variant: Equatable {
        /// Profile placeholder — peach blob + person glyph.
        case avatar
        case icon(systemName: String)
    }

    public let variant: Variant
    public let size: CGFloat
    public let action: () -> Void

    public init(
        variant: Variant,
        size: CGFloat = 52,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            switch variant {
            case .avatar:
                avatarBody
            case .icon(let systemName):
                iconBody(systemName: systemName)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var avatarBody: some View {
        ZStack {
            Image("BondBlobYou")
                .resizable()
                .scaledToFit()

            Image(systemName: "person.fill")
                .font(.system(size: size * 0.385, weight: .semibold))
                .foregroundStyle(DesignColors.text)
        }
        .frame(width: size, height: size)
    }

    private func iconBody(systemName: String) -> some View {
        ZStack {
            Circle().fill(Color.white)
            Image(systemName: systemName)
                .font(.system(size: size * 0.365, weight: .medium))
                .foregroundStyle(DesignColors.text)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(DesignColors.divider.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: DesignColors.text.opacity(0.10), radius: 6, x: 0, y: 3)
    }

    private var accessibilityLabel: String {
        switch variant {
        case .avatar: "Your profile"
        case .icon: "Settings"
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        MeHeaderRoundButton(variant: .avatar, action: {})
        MeHeaderRoundButton(variant: .icon(systemName: "gearshape"), action: {})
    }
    .padding(40)
    .background(Color(hex: 0xFFCDB0))
}
