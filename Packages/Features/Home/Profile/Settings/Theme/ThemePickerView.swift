import SwiftUI

// MARK: - Theme Picker View
//
// "Appearance" — pushed from Settings. Lets the user pick
// between Light, Dark and (default) System modes. Each card
// renders a stylised mini-Home so the user can preview the
// surface before committing. The selection writes the new
// AppTheme rawValue into @AppStorage; AppView reads the same
// key and applies the resulting ColorScheme app-wide.

struct ThemePickerView: View {
    @AppStorage(AppThemeStorage.key) private var themeRaw: String = AppTheme.system.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .system
    }

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            scrollContent
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppLayout.spacingS) {
                sectionLabel("Appearance")
                    .padding(.horizontal, AppLayout.spacingXS)

                appearanceCard

                systemRow
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingS)
            .padding(.bottom, AppLayout.spacingXL)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Cards

    private var appearanceCard: some View {
        HStack(alignment: .top, spacing: AppLayout.spacingM) {
            ThemePreviewCard(
                theme: .light,
                isSelected: selectedTheme == .light,
                onTap: { select(.light) }
            )

            ThemePreviewCard(
                theme: .dark,
                isSelected: selectedTheme == .dark,
                onTap: { select(.dark) }
            )
        }
        .padding(AppLayout.spacingM)
        .frame(maxWidth: .infinity)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private var systemRow: some View {
        Button(action: { select(.system) }) {
            HStack(spacing: AppLayout.spacingS) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Match system")
                        .font(AppTypography.cardLabel)
                        .foregroundStyle(DesignColors.text)
                    Text("Follow iOS Settings → Display & Brightness")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Spacer(minLength: 0)

                systemCheck
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private var systemCheck: some View {
        ZStack {
            Circle()
                .stroke(DesignColors.textSecondary.opacity(0.35), lineWidth: 1.5)
                .frame(width: 22, height: 22)

            if selectedTheme == .system {
                Circle()
                    .fill(DesignColors.accent)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTheme)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTypography.cardEyebrow)
            .tracking(AppTypography.cardEyebrowTracking)
            .foregroundStyle(DesignColors.textSecondary)
    }

    // MARK: - Actions

    private func select(_ theme: AppTheme) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        themeRaw = theme.rawValue
    }
}
