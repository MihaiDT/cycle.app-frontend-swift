import SwiftUI

// MARK: - Download Data View
//
// "Download your data" — pushed onto the Settings stack. Editorial
// layout: large title, a "How it works" copy block, then a sticky
// CTA at the bottom that kicks off the export.
//
// Local-first reality: cycle.app stores every health record on the
// device (SwiftData + CloudKit encrypted sync). There's no backend
// copy to request — when the export action lands, it'll generate a
// file in-app and present a share sheet. For now the CTA fires a
// no-op closure; the data assembly logic is a follow-up.

struct DownloadDataView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingExportReady: Bool = false

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            content
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbarItem(dismiss: dismiss) }
        .navigationDestination(isPresented: $isShowingExportReady) {
            DataExportReadyView()
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                    title
                    howItWorks
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingS)
                .padding(.bottom, AppLayout.spacingXL)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            footer
        }
    }

    private var title: some View {
        Text("Download your data")
            .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
            .foregroundStyle(DesignColors.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, AppLayout.spacingL)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingM) {
            Text("How it works")
                .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            Text("Your cycle data lives only on this device. Tap below and we'll bundle every cycle, symptom, and check-in into a single file you can save or share.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nothing is sent to a server. The file stays under your control from the moment it's created.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            WarmCapsuleButton(
                "Request data",
                prominence: .primary,
                isFullWidth: true,
                action: requestData
            )
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.bottom, AppLayout.spacingL)
        }
    }

    // MARK: - Actions

    private func requestData() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isShowingExportReady = true
    }
}
