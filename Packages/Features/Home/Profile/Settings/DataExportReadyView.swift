import ComposableArchitecture
import LocalAuthentication
import SwiftUI

// MARK: - Data Export Ready View
//
// Confirmation screen after the user taps "Request data" on
// DownloadDataView. The export bundle is generated on-device by
// DataExporter and delivered to the user via:
// - Primary: backend transactional email relay (POST
//   /api/data-export/email → Resend). The Go backend never
//   persists the payload; it's a pure pass-through.
// - Secondary: UIActivityViewController (AirDrop / Files / Gmail /
//   any sharing extension).
//
// The cached email lives on UserProfileRecord with
// @Attribute(.allowsCloudEncryption). First export captures it,
// subsequent exports pre-fill the TextField.
//
// File split (per CLAUDE.md §7, under 500-line threshold):
// - This file:               struct + state + body shell + content.
// - +Sections.swift:         section view builders + footer chrome
//                            + derived presentation helpers.
// - +Actions.swift:          send / share / reveal pipelines + static
//                            factories + cooldown helpers.
// State properties are declared without `private` so the extensions
// in sibling files can read them; nothing inside the module should
// touch them anyway — the convention is enforced by SwiftUI itself.

struct DataExportReadyView: View {
    /// Closure fired when the user taps "Done" on the success state.
    /// Set by the presenting view to pop all the way back to a
    /// stable anchor (Settings) instead of dismissing one level
    /// at a time. When nil, falls back to a plain `dismiss()`.
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.userProfileLocal) var userProfileLocal

    @State var referenceCode: String = DataExportReadyView.generateReferenceCode()
    @State var isCodeRevealed: Bool = false
    @State var didCopy: Bool = false
    @State var relockTask: Task<Void, Never>?

    @State var email: String = ""
    @State var didHydrateEmail: Bool = false

    @State var shareItem: ExportShareItem?
    @State var exportError: String?
    @State var isSending: Bool = false
    @State var sentSummary: SentSummary?

    /// Wall-clock timestamp (Unix epoch) of the most recent
    /// successful email send. Compared against
    /// `Self.cooldownSeconds` (72h) to gate the "Email me a copy"
    /// button so a user can't spam the backend (and the recipient)
    /// while their previous link is still valid. Lives in
    /// `@AppStorage` so the cooldown survives app relaunches.
    @AppStorage(DataExportReadyView.lastSentAtKey) var lastSentAtRaw: Double = 0

    /// Re-drives the cooldown copy ("expires in 41h") at minute
    /// granularity. Lighter than a 1s timer; the countdown text
    /// rounds to hours anyway.
    @State var cooldownTickerTrigger: Int = 0

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
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .task { await hydrateEmailIfNeeded() }
        .onDisappear { relockTask?.cancel() }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Couldn't send email", isPresented: exportErrorBinding, presenting: exportError) { _ in
            Button("Try again") {
                exportError = nil
                Task { await sendViaBackend() }
            }
            Button("Cancel", role: .cancel) { exportError = nil }
        } message: { message in
            Text(message)
        }
    }

    var content: some View {
        ScrollView {
            VStack(spacing: AppLayout.spacingL) {
                heroIcon
                titleBlock
                copyBlock
                referenceCodeRow
                emailInputRow
                privacyCallout
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingM)
            .padding(.bottom, AppLayout.spacingXL)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Sent Summary

struct SentSummary: Equatable {
    let email: String
}
