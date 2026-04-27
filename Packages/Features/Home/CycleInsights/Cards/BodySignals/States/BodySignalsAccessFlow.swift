import SwiftUI

// MARK: - Body Signals Access Flow
//
// Two-screen wizard surfaced from the BodySignals card. The flow is
// always sequential — connect explainer first, manage instructions
// after. We deliberately avoid `NavigationStack` here: profiling
// showed the stack's first-init cost added a perceptible hitch on
// sheet present, and the flow has exactly two screens with no
// dynamic destinations, so a single state-driven view switch with a
// horizontal slide transition is both cheaper and smoother. The
// chevron in the top-left handles both "go back" and "close" — pop
// to Screen 1 when on Screen 2, dismiss the whole sheet on Screen 1.

public enum BodySignalsAccessFlowMode: String, Identifiable, Equatable, Sendable {
    case prompt
    case denied

    public var id: String { rawValue }
}

public struct BodySignalsAccessFlow: View {
    public let mode: BodySignalsAccessFlowMode
    public let onSync: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingManage: Bool = false

    public init(
        mode: BodySignalsAccessFlowMode,
        onSync: @escaping () -> Void
    ) {
        self.mode = mode
        self.onSync = onSync
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()

            Group {
                if showingManage {
                    manageScreen
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                } else {
                    connectScreen
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
            }
            .animation(.easeInOut(duration: 0.28), value: showingManage)
        }
        .overlay(alignment: .topLeading) {
            backButton
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, 12)
        }
    }

    // MARK: - Back / close button

    private var backButton: some View {
        GlassBackButton {
            if showingManage {
                showingManage = false
            } else {
                dismiss()
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel(showingManage ? "Back" : "Close")
    }

    // MARK: - Screen 1 — Connect explainer

    private var connectScreen: some View {
        screenScaffold(footer: {
            HeroGlassCapsuleButton("Sync with Apple", layout: .large) {
                onSync()
                showingManage = true
            }
        }) {
            VStack(alignment: .center, spacing: 22) {
                iconBadge

                Text("Connect cycle.app with Apple Health")
                    .font(.raleway("Bold", size: 24, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 22) {
                    section(
                        heading: "How the link works",
                        body: "Apple Health asks which signals you'd like to share. cycle.app reads wrist temperature, HRV, and resting heart rate from today onward – nothing retroactive, only what you opt in to."
                    )
                    section(
                        heading: "Your data, your call",
                        body: "What you share stays yours. You can adjust your selection any time inside Apple Health settings, and cycle.app only ever reads the signals you've explicitly enabled."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var iconBadge: some View {
        Image("HealthIcon", bundle: .main)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
            )
            .accessibilityHidden(true)
    }

    private func section(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
            Text(body)
                .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Screen 2 — Manage instructions

    private var manageScreen: some View {
        screenScaffold(footer: {
            HeroGlassCapsuleButton("Go to Settings", layout: .large) {
                openSettings()
                dismiss()
            }
        }) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Apple Health")
                    .font(.raleway("Bold", size: 26, relativeTo: .title))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .padding(.top, 4)

                Text("To change which signals cycle.app receives from Apple Health, follow these steps:")
                    .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 18) {
                    step(systemIcon: "gearshape.fill", text: "Open the device's Settings.")
                    step(
                        systemIcon: "heart.fill",
                        text: "Scroll down and tap Health.",
                        iconTint: DesignColors.calendarPeriodGlyph
                    )
                    step(systemIcon: "hand.raised.fill", text: "Tap Data Access & Devices.")
                    step(systemIcon: "sparkles", text: "Tap cycle.app and tune your preferences.")
                }
                .padding(.top, 4)
            }
        }
    }

    private func step(
        systemIcon: String,
        text: String,
        iconTint: Color = DesignColors.text
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconTint)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(DesignColors.text.opacity(0.10), lineWidth: 0.6)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )

            Text(text)
                .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Scaffold

    @ViewBuilder
    private func screenScaffold<Content: View, Footer: View>(
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Reserve room for the back chevron overlay plus breathing
            // space so headings on Screen 2 don't crowd the button.
            Color.clear.frame(height: 64)

            ScrollView {
                content()
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }

            footer()
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.bottom, 24)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSettings() {
        guard let url = URL(string: "app-settings:") else { return }
        openURL(url)
    }
}
