import ComposableArchitecture
import MessageUI
import SwiftUI

// MARK: - Data Export Ready View
//
// Confirmation screen after the user taps "Request data" on
// DownloadDataView. The export bundle is generated on-device
// (DataExporter) and delivered to the user via:
// - Primary: MFMailComposeViewController (user emails it to themselves)
// - Secondary: UIActivityViewController (AirDrop / Files / Gmail / …)
//
// Email flow is local-first by design: the To field is pre-filled
// from a cached `email` on `UserProfileRecord` (E2E encrypted via
// CloudKit). First export captures the email, subsequent exports
// auto-fill. The user always sees and approves the message in the
// system Mail composer before it sends — Apple's "Privacy & Data
// Use" guidance treats that composer as the consent surface.
//
// Layout (top → bottom):
// - Hero icon disc
// - Title + descriptive copy
// - Reference code block (tap to copy; also embedded in the JSON
//   manifest so the file is traceable to the on-screen receipt)
// - Email-to row (TextField with cached value, persisted on send)
// - Primary CTA "Email me a copy" + secondary text "Other ways to share"

struct DataExportReadyView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.userProfileLocal) private var userProfileLocal

    @State private var referenceCode: String = DataExportReadyView.generateReferenceCode()
    @State private var didCopy: Bool = false

    @State private var email: String = ""
    @State private var didHydrateEmail: Bool = false

    @State private var shareItem: ExportShareItem?
    @State private var mailDraft: MailDraft?
    @State private var exportError: String?
    @State private var showMailFallbackAlert: Bool = false
    @State private var pendingMailURL: URL?
    @State private var isGenerating: Bool = false

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
        .task { await hydrateEmailIfNeeded() }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(item: $mailDraft) { draft in
            MailComposeView(draft: draft) { _, _ in }
                .ignoresSafeArea()
        }
        .alert("Export failed", isPresented: exportErrorBinding, presenting: exportError) { _ in
            Button("OK") { exportError = nil }
        } message: { message in
            Text(message)
        }
        .alert(
            "iOS Mail isn't set up",
            isPresented: $showMailFallbackAlert
        ) {
            Button("Use share sheet") { presentShareSheetFallback() }
            Button("Cancel", role: .cancel) { pendingMailURL = nil }
        } message: {
            Text("Add a Mail account in Settings or use the share sheet to send your export via another app.")
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppLayout.spacingL) {
                    heroIcon
                    titleBlock
                    copyBlock
                    referenceCodeRow
                    emailInputRow
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingL)
                .padding(.bottom, AppLayout.spacingXL)
            }
            .scrollIndicators(.hidden)

            footer
        }
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
    }

    // MARK: - Text

    private var titleBlock: some View {
        Text("Your data is ready")
            .font(.raleway("Bold", size: 24, relativeTo: .title2))
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppLayout.spacingS)
    }

    private var copyBlock: some View {
        VStack(spacing: AppLayout.spacingM) {
            Text("We've bundled every cycle, symptom, check-in, prediction, and HBI score into a single JSON file. It stays on this device until you choose where to send it.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Type the address where you want it delivered, then tap Email me a copy. The system Mail composer opens with everything pre-filled so you can review before sending.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppLayout.spacingXS)
    }

    // MARK: - Reference code

    private var referenceCodeRow: some View {
        Button(action: copyReferenceCode) {
            HStack(spacing: AppLayout.spacingS) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reference code")
                        .font(AppTypography.cardEyebrow)
                        .tracking(AppTypography.cardEyebrowTracking)
                        .foregroundStyle(DesignColors.textSecondary)
                    Text(referenceCode)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(DesignColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(didCopy ? DesignColors.accentWarm : DesignColors.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    // MARK: - Email input

    private var emailInputRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Send to")
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.horizontal, AppLayout.spacingM)
                .padding(.top, 14)

            TextField("you@example.com", text: $email)
                .font(.raleway("Medium", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .padding(.horizontal, AppLayout.spacingM)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: AppLayout.spacingS) {
            WarmCapsuleButton(
                isGenerating ? "Preparing…" : "Email me a copy",
                prominence: .primary,
                isFullWidth: true,
                action: sendViaEmail
            )
            .disabled(isGenerating || !isEmailValid)

            Button(action: shareFile) {
                Text("Other ways to share")
                    .font(.raleway("Medium", size: 14, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.textSecondary)
                    .underline(true, color: DesignColors.textSecondary.opacity(0.6))
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.bottom, AppLayout.spacingL)
    }

    // MARK: - Derived

    private var isEmailValid: Bool {
        Self.isLikelyValidEmail(email)
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    // MARK: - Lifecycle

    private func hydrateEmailIfNeeded() async {
        guard !didHydrateEmail else { return }
        didHydrateEmail = true

        do {
            if let snapshot = try await userProfileLocal.getProfile(),
               let cached = snapshot.email, !cached.isEmpty {
                email = cached
            }
        } catch {
            // Non-fatal — the user can still type the email manually.
        }
    }

    // MARK: - Actions

    private func copyReferenceCode() {
        UIPasteboard.general.string = referenceCode
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { didCopy = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.2)) { didCopy = false }
        }
    }

    private func sendViaEmail() {
        guard !isGenerating, isEmailValid else { return }
        isGenerating = true

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = trimmed

        do {
            let url = try buildExportFile()
            persistEmail(trimmed)

            if MFMailComposeViewController.canSendMail() {
                let data = try Data(contentsOf: url)
                mailDraft = MailDraft(
                    subject: "Your cycle.app data export – \(Self.humanDate())",
                    body: emailBody(),
                    toRecipients: [trimmed],
                    attachmentData: data,
                    attachmentMime: "application/json",
                    attachmentFilename: url.lastPathComponent
                )
            } else {
                pendingMailURL = url
                showMailFallbackAlert = true
            }
        } catch {
            exportError = error.localizedDescription
        }

        isGenerating = false
    }

    private func shareFile() {
        guard !isGenerating else { return }
        isGenerating = true

        do {
            let url = try buildExportFile()
            shareItem = ExportShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }

        isGenerating = false
    }

    private func presentShareSheetFallback() {
        guard let url = pendingMailURL else { return }
        shareItem = ExportShareItem(url: url)
        pendingMailURL = nil
    }

    // MARK: - Export pipeline

    private func buildExportFile() throws -> URL {
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        let buildNumber = (info["CFBundleVersion"] as? String) ?? "0"

        let json = try DataExporter().exportAll(
            appVersion: appVersion,
            buildNumber: buildNumber,
            preferences: ExportablePreferences.snapshot(),
            referenceCode: referenceCode
        )

        let fileName = Self.exportFileName()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try json.write(to: url, options: .atomic)
        return url
    }

    private func persistEmail(_ value: String) {
        let userProfileLocal = userProfileLocal
        Task.detached {
            do {
                guard var snapshot = try await userProfileLocal.getProfile(),
                      snapshot.email != value else { return }
                snapshot.email = value
                try await userProfileLocal.saveProfile(snapshot)
            } catch {
                // Best-effort cache — silent if it can't write. Guest
                // users (no profile yet) simply re-type next time.
            }
        }
    }

    private func emailBody() -> String {
        """
        Your cycle.app data export is attached as a JSON file.

        It includes every cycle, symptom, check-in, prediction, and HBI score logged on this device, plus your in-app preferences. The data stays under your control from this point on.

        Reference code: \(referenceCode)
        """
    }

    // MARK: - Helpers

    private static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return "cycleapp-export-\(formatter.string(from: .now)).json"
    }

    private static func humanDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: .now)
    }

    private static func isLikelyValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Lightweight RFC-5322-ish check — the system Mail composer
        // does the authoritative validation when the user hits Send.
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Reference code generation

    private static func generateReferenceCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let raw = (0..<16).compactMap { _ in alphabet.randomElement() }
        let chunks = stride(from: 0, to: raw.count, by: 4).map { i -> String in
            String(raw[i..<min(i + 4, raw.count)])
        }
        return chunks.joined(separator: "-")
    }
}
