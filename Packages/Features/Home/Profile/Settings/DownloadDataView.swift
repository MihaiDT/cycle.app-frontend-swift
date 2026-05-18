import SwiftUI

// MARK: - Download Data View
//
// "Download your data" — pushed onto the Settings stack. Editorial
// layout: hero peach disc anchors the screen (visual sibling of
// DataExportReadyView), then a "What's included" bullet list,
// then a privacy callout, then a sticky Continue CTA.
//
// Local-first reality: every health record lives on the device
// (SwiftData + CloudKit encrypted sync). The export bundle is
// assembled on-device; when the user emails a copy, the encrypted
// archive transits cycle.app's backend solely to compose the
// message — we don't store the contents.

struct DownloadDataView: View {
    /// Closure fired when DataExportReadyView reports it's finished
    /// (user tapped "Done" on the success state). The parent uses
    /// this to pop both this view and DataExportReadyView in a
    /// single animation, landing the user back on Settings.
    var onExportComplete: (() -> Void)? = nil

    @State private var isShowingExportReady: Bool = false

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            scrollContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .navigationDestination(isPresented: $isShowingExportReady) {
            DataExportReadyView(onComplete: { onExportComplete?() })
        }
    }

    // MARK: - Scroll body

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: AppLayout.spacingL) {
                heroIcon
                titleBlock
                includedList
                privacyCallout
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingM)
            .padding(.bottom, AppLayout.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(DesignColors.accentWarm.opacity(0.14))
                .frame(width: 132, height: 132)

            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(DesignColors.accentWarm)
        }
        .padding(.top, AppLayout.spacingM)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: AppLayout.spacingS) {
            Text("Download your data")
                .font(AppTypography.displayHeader)
                .foregroundStyle(DesignColors.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("A snapshot of everything you've logged in cycle.app, packaged into a single encrypted archive.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppLayout.spacingS)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - What's included

    private var includedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("What's included")
                .padding(.horizontal, AppLayout.spacingM)
                .padding(.top, 14)
                .padding(.bottom, AppLayout.spacingS)

            includedRow(asset: "CycleLogged",
                        tint: DesignColors.accent,
                        text: "Every logged cycle and bleeding day")
            divider
            includedRow(asset: "SymptomCheckIn",
                        tint: DesignColors.roseTaupe,
                        text: "Every symptom and daily check-in")
            divider
            includedRow(asset: "PredictionAccuracy",
                        tint: DesignColors.accentSecondary,
                        text: "Cycle predictions and accuracy history")
            divider
            includedRow(asset: "WellnessTrends",
                        tint: DesignColors.accentWarm,
                        text: "Your wellness scores and trends")
            divider
            includedRow(asset: "AppPreferences",
                        tint: DesignColors.textCard,
                        text: "In-app preferences")
        }
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTypography.cardEyebrow)
            .tracking(AppTypography.cardEyebrowTracking)
            .foregroundStyle(DesignColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func includedRow(asset: String, tint: Color, text: String) -> some View {
        HStack(spacing: AppLayout.spacingM) {
            ZStack {
                Circle().fill(tint.opacity(0.22))
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(tint)
            }
            .frame(width: 48, height: 48)

            Text(text)
                .font(AppTypography.rowTitle)
                .foregroundStyle(DesignColors.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.10))
            .frame(height: 0.5)
            .padding(.leading, AppLayout.spacingM + 48 + AppLayout.spacingM)
    }

    // MARK: - Privacy

    private var privacyCallout: some View {
        HStack(alignment: .top, spacing: AppLayout.spacingS) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DesignColors.accentWarm)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Stays under your control")
                    .font(AppTypography.cardLabel)
                    .foregroundStyle(DesignColors.text)
                Text("If you choose to email a copy, your encrypted archive is held on our server for up to 72 hours so the download link can fetch it. We delete it the moment you download, or sooner if the link expires.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    // MARK: - Footer
    //
    // Mirrors the top peach header: a frosted blur + warm tint that
    // fades from transparent at the top into a full surface at the
    // bottom edge. Content scrolls underneath so the last card
    // softly diffuses through the blur. The button sits on the
    // solid bottom of the gradient where readability is highest.

    private var footer: some View {
        WarmCapsuleButton(
            "Continue",
            prominence: .primary,
            isFullWidth: true,
            action: requestData
        )
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.top, AppLayout.spacingL)
        .padding(.bottom, AppLayout.spacingS)
        .background {
            // Background bleeds through the bottom safe area so the
            // warm gradient + frosted blur reach all the way to the
            // home indicator. The button itself stays above the
            // safe area thanks to the `.padding(.bottom)` above.
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6), .black, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                LinearGradient(
                    colors: [
                        .clear,
                        DesignColors.accentWarm.opacity(0.08),
                        DesignColors.accentWarm.opacity(0.16),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Actions

    private func requestData() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isShowingExportReady = true
    }
}
