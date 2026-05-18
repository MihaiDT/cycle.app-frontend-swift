import SwiftUI

// MARK: - Profile About Card
//
// App version + static ToS / Privacy links. URLs are placeholders until
// the marketing site lands — swap when the real pages are live.

public struct ProfileAboutCard: View {
    public let onOpenURL: (URL) -> Void

    private static let termsURL = URL(string: "https://cycle.app/terms")!
    private static let privacyURL = URL(string: "https://cycle.app/privacy")!

    public init(onOpenURL: @escaping (URL) -> Void) {
        self.onOpenURL = onOpenURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            linkRow(label: "Terms of service", url: Self.termsURL)

            Rectangle()
                .fill(DesignColors.textSecondary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, AppLayout.spacingM)

            linkRow(label: "Privacy policy", url: Self.privacyURL)
        }
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private func linkRow(label: String, url: URL) -> some View {
        Button(action: { onOpenURL(url) }) {
            HStack(spacing: AppLayout.spacingS) {
                Text(label)
                    .font(.raleway("Medium", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Spacer()
                ProfileNavChip()
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "v\(version)" : "v\(version) (\(build))"
    }
}
