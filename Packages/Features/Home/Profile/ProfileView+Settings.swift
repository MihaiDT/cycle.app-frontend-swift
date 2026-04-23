import ComposableArchitecture
import SwiftUI

// MARK: - ProfileView › Settings + About + Privacy
//
// Lower-half of the profile screen — extracted so ProfileView.swift
// keeps header + hero cards (identity, glow, cycle overview, wellness).

extension ProfileView {
    // MARK: - Settings Section

    var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Settings", icon: "gearshape")
                .padding(.bottom, AppLayout.spacingS)

            settingsRow(icon: "bell", title: "Notifications", subtitle: "Reminders & alerts")
            settingsDivider
            settingsRow(icon: "person.text.rectangle", title: "Account", subtitle: "Email & password")
            settingsDivider
            settingsRow(icon: "lock.shield", title: "Privacy", subtitle: "Data & permissions")
            settingsDivider
            settingsRow(icon: "apple.logo", title: "HealthKit", subtitle: "Connected data sources")
        }
        .padding(AppLayout.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { glassCard(cornerRadius: AppLayout.cornerRadiusL) }
    }

    // MARK: - About Section

    var aboutSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: nil)
            settingsDivider
            settingsRow(icon: "doc.text", title: "Terms of Service", subtitle: nil)
            settingsDivider
            settingsRow(icon: "hand.raised", title: "Privacy Policy", subtitle: nil)
            settingsDivider

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(DesignColors.textSecondary)
                    .frame(width: 28)

                Text("Version")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundColor(DesignColors.text)

                Spacer()

                Text(appVersion)
                    .font(.raleway("Regular", size: 14, relativeTo: .body))
                    .foregroundColor(DesignColors.textPlaceholder)
            }
            .padding(.vertical, 14)
        }
        .padding(AppLayout.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { glassCard(cornerRadius: AppLayout.cornerRadiusL) }
    }

    // MARK: - Privacy Actions

    var privacyActionsSection: some View {
        VStack(spacing: 12) {
            profileActionButton(
                icon: "trash",
                title: "Delete Chat History",
                subtitle: "Remove all Aria conversations from server",
                action: { store.send(.deleteChatDataTapped) }
            )

            profileActionButton(
                icon: "arrow.triangle.2.circlepath",
                title: "Reset Anonymous ID",
                subtitle: "Old conversations become unlinkable",
                action: { store.send(.resetAnonymousIDTapped) }
            )

            profileActionButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Reset App",
                subtitle: "Delete all local data and start fresh",
                action: { store.send(.logoutTapped) },
                isDestructive: true
            )
        }
    }

    func profileActionButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                    Text(subtitle)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textSecondary)
                }
                Spacer()
            }
            .foregroundColor(isDestructive ? .red.opacity(0.8) : DesignColors.accentWarm)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                            .strokeBorder(
                                (isDestructive ? Color.red : DesignColors.accentWarm).opacity(0.3),
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Components

    func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignColors.accentSecondary)
            Text(title)
                .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                .foregroundColor(DesignColors.text)
            Spacer()
        }
    }

    func statPill(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.raleway("Bold", size: 18, relativeTo: .headline))
                    .foregroundColor(DesignColors.text)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                        .foregroundColor(DesignColors.textSecondary)
                }
            }
            Text(label)
                .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                .foregroundColor(DesignColors.textPlaceholder)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusS)
                .fill(Color.white.opacity(0.3))
        }
    }

    func settingsRow(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DesignColors.accentSecondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundColor(DesignColors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textPlaceholder)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignColors.textPlaceholder)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    var settingsDivider: some View {
        Rectangle()
            .fill(DesignColors.divider.opacity(0.4))
            .frame(height: 0.5)
            .padding(.leading, 40)
    }

    func weekSparkline(scores: [Int]) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 32
            let maxScore = max(scores.max() ?? 100, 1)
            let minScore = max(scores.min() ?? 0, 0)
            let range = max(CGFloat(maxScore - minScore), 1)

            Path { path in
                for (index, score) in scores.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(max(scores.count - 1, 1))
                    let y = height - (CGFloat(score - minScore) / range) * height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [DesignColors.accent, DesignColors.accentWarm],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 32)
    }

    func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
