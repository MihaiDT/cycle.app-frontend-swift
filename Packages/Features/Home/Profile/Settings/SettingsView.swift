import SwiftUI

// MARK: - Settings View
//
// "Settings" — pushed onto the Profile NavigationStack. Hosts
// app-wide preferences: data export, biometric unlock, widget
// data privacy, plus personalization (theme / language / units).
//
// Persistence:
// - Biometric and widget toggles live in @AppStorage so they
//   survive launches without touching SwiftData.
// - Language opens the iOS Settings deep-link (per-app language
//   is managed by the system).
// - Theme / Units are placeholder destinations for now; the
//   tap closures stay no-op until those screens land.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.biometricUnlockEnabled)
    private var biometricUnlockEnabled: Bool = false

    @AppStorage(SettingsKeys.hideWidgetData)
    private var hideWidgetData: Bool = false

    @State private var isShowingDownloadData: Bool = false

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            scrollContent
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbarItem(dismiss: dismiss) }
        .navigationDestination(isPresented: $isShowingDownloadData) {
            DownloadDataView()
        }
    }

    // MARK: - Scroll

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: AppLayout.spacingL) {
                dataAndSecuritySection
                personalizeSection
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingS)
            .padding(.bottom, AppLayout.spacingXL)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Sections

    private var dataAndSecuritySection: some View {
        section(title: "Data & security") {
            VStack(alignment: .leading, spacing: 0) {
                navRow(title: "Download my data") { isShowingDownloadData = true }
                divider
                toggleRow(
                    title: "Face ID to unlock the app",
                    binding: $biometricUnlockEnabled
                )
                divider
                toggleRow(
                    title: "Hide data in widgets",
                    binding: $hideWidgetData
                )
            }
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        }
    }

    private var personalizeSection: some View {
        section(title: "Personalize") {
            VStack(alignment: .leading, spacing: 0) {
                navRow(title: "Theme") {}
                divider
                navRow(title: "Language", isExternal: true) {
                    openSystemSettings()
                }
                divider
                navRow(title: "Units") {}
            }
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        }
    }

    // MARK: - Row helpers

    private func navRow(
        title: String,
        isExternal: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.raleway("Medium", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Spacer(minLength: 0)
                if isExternal {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.textSecondary)
                        .frame(width: 26, height: 26)
                } else {
                    ProfileNavChip()
                }
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(title: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title)
                .font(.raleway("Medium", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)
        }
        .tint(DesignColors.accentWarm)
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, AppLayout.spacingM)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text(title.uppercased())
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppLayout.spacingXS)

            content()
        }
    }

    // MARK: - Actions

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Storage Keys

enum SettingsKeys {
    static let biometricUnlockEnabled = "cycle.app.settings.biometricUnlockEnabled"
    static let hideWidgetData = "cycle.app.settings.hideWidgetData"
}
