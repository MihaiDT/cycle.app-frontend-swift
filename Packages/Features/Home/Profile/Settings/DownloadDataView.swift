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
    @Environment(\.dismiss) private var dismiss
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
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbarItem(dismiss: dismiss) }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .navigationDestination(isPresented: $isShowingExportReady) {
            DataExportReadyView()
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
                .font(.raleway("Bold", size: 28, relativeTo: .title))
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
                Circle().fill(tint.opacity(0.16))
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(tint)
            }
            .frame(width: 48, height: 48)

            Text(text)
                .font(.raleway("Medium", size: 15, relativeTo: .subheadline))
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
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
                Text("If you choose to email a copy, the archive transits our server only to compose the message. Nothing is stored on our end.")
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
        ZStack(alignment: .bottom) {
            // 1. Frosted blur layer, masked so it fades in
            //    vertically rather than appearing as a hard band.
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6), .black, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .allowsHitTesting(false)

            // 2. Warm peach tint — same accent as the header's
            //    AppleHealthBackground, faded the same way so the
            //    two ends of the screen feel symmetric.
            LinearGradient(
                colors: [
                    .clear,
                    DesignColors.accentWarm.opacity(0.08),
                    DesignColors.accentWarm.opacity(0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // 3. Button — pushed off the bottom safe area so it
            //    sits in the strongest part of the gradient.
            WarmCapsuleButton(
                "Continue",
                prominence: .primary,
                isFullWidth: true,
                action: requestData
            )
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.bottom, AppLayout.spacingS)
        }
        .frame(height: 132)
    }

    // MARK: - Actions

    private func requestData() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isShowingExportReady = true
    }
}
