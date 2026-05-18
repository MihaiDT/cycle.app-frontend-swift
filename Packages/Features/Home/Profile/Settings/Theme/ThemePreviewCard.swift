import SwiftUI

// MARK: - Theme Preview Card
//
// Stylised mini-phone used inside ThemePickerView. Renders a
// shrunk facsimile of the Home shell — peach lens at the top
// fading to the base surface, calendar strip dots, a body card,
// and a palette row — flipped between light and dark base
// colours so the user can preview either side without leaving
// the picker.
//
// Drawn from SwiftUI primitives (no screenshots) so it stays
// crisp at any scale and follows the live design tokens.

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    private var isDark: Bool { theme == .dark }
    private var base: Color { isDark ? Color(white: 0.07) : .white }
    private var inkPrimary: Color { isDark ? Color.white.opacity(0.85) : Color.black.opacity(0.55) }
    private var inkMuted: Color { isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.10) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                phonePreview
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)

                Text(theme.title)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(DesignColors.text)

                selectionIndicator
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phone preview

    private var phonePreview: some View {
        let phoneShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return ZStack {
            phoneShape
                .fill(base)
                .overlay(phoneShape.stroke(inkMuted, lineWidth: 0.5))

            VStack(spacing: 0) {
                peachHeader
                    .frame(maxHeight: .infinity)
                bottomChrome
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
            }
        }
        .clipShape(phoneShape)
    }

    private var peachHeader: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: isDark
                    ? [
                        .init(color: Color(red: 0.65, green: 0.35, blue: 0.42), location: 0.00),
                        .init(color: Color(red: 0.55, green: 0.25, blue: 0.32), location: 0.45),
                        .init(color: base, location: 1.00),
                    ]
                    : [
                        .init(color: Color(red: 1.00, green: 0.82, blue: 0.83), location: 0.00),
                        .init(color: Color(red: 1.00, green: 0.90, blue: 0.91), location: 0.55),
                        .init(color: base, location: 1.00),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                statusBarDots
                    .padding(.top, 14)

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    bar(width: 50)
                    bar(width: 72)
                    bar(width: 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)

                Spacer()

                Capsule()
                    .fill(base)
                    .frame(width: 56, height: 12)
                    .padding(.bottom, 22)
            }
        }
    }

    private var statusBarDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { _ in
                Circle()
                    .fill(inkPrimary.opacity(0.45))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func bar(width: CGFloat) -> some View {
        Capsule()
            .fill(inkPrimary.opacity(0.45))
            .frame(width: width, height: 4)
    }

    // MARK: - Bottom chrome (palette + card)

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            paletteRow
            bottomCard
        }
    }

    private var paletteRow: some View {
        HStack(spacing: 5) {
            paletteSwatch(color: DesignColors.accent, dot: true)
            paletteSwatch(color: Color(red: 0.85, green: 0.74, blue: 0.92))
            paletteSwatch(color: Color(red: 1.00, green: 0.80, blue: 0.84))
            paletteSwatch(color: Color(red: 0.60, green: 0.78, blue: 0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        }
        .frame(height: 38)
    }

    private func paletteSwatch(color: Color, dot: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .overlay(alignment: .bottomLeading) {
                if dot {
                    Circle()
                        .fill(DesignColors.accent)
                        .frame(width: 7, height: 7)
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(inkMuted, lineWidth: 0.5)
            )
    }

    private var bottomCard: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(inkMuted)
            .frame(height: 14)
    }

    // MARK: - Selection

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(DesignColors.textSecondary.opacity(0.35), lineWidth: 1.5)
                .frame(width: 26, height: 26)

            if isSelected {
                Circle()
                    .fill(DesignColors.accent)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
