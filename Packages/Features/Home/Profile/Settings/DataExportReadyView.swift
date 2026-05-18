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
// Layout (top → bottom):
// - Hero icon disc + status (loading / success / idle)
// - Title + descriptive copy
// - Reference code block (tap to copy; embedded in
//   manifest.referenceCode of the JSON file)
// - Email TextField with cached value (persisted on send)
// - Primary CTA "Email me a copy" + secondary "Other ways to share"

struct DataExportReadyView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.apiClient) private var apiClient
    @Dependency(\.userProfileLocal) private var userProfileLocal

    @State private var referenceCode: String = DataExportReadyView.generateReferenceCode()
    @State private var isCodeRevealed: Bool = false
    @State private var didCopy: Bool = false
    @State private var relockTask: Task<Void, Never>?

    @State private var email: String = ""
    @State private var didHydrateEmail: Bool = false

    @State private var shareItem: ExportShareItem?
    @State private var exportError: String?
    @State private var isSending: Bool = false
    @State private var sentSummary: SentSummary?

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

            if sentSummary != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(DesignColors.accentWarm)
                    .transition(.opacity)
            } else if isSending {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(DesignColors.accentWarm)
                    .controlSize(.large)
            } else {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(DesignColors.accentWarm)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sentSummary?.email)
        .animation(.easeInOut(duration: 0.25), value: isSending)
        .padding(.top, AppLayout.spacingM)
    }

    // MARK: - Text

    private var titleBlock: some View {
        Text(sentSummary != nil ? "Email sent" : "Your data is ready")
            .font(.raleway("Bold", size: 24, relativeTo: .title2))
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppLayout.spacingS)
    }

    @ViewBuilder
    private var copyBlock: some View {
        if let sent = sentSummary {
            VStack(spacing: AppLayout.spacingM) {
                Text("Your export is on its way to \(sent.email). It may take a minute to arrive — check spam if you don't see it.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppLayout.spacingXS)
        } else {
            VStack(spacing: AppLayout.spacingM) {
                Text("We've bundled every cycle, symptom, check-in, prediction, and HBI score into a single JSON file. It stays on this device until you send it.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Enter your email below and we'll send it as an attachment. Your data passes through our server only to compose the message — we don't store it.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppLayout.spacingXS)
        }
    }

    // MARK: - Reference code

    private var referenceCodeRow: some View {
        Button(action: handleReferenceCodeTap) {
            HStack(spacing: AppLayout.spacingS) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Archive password")
                        .font(AppTypography.cardEyebrow)
                        .tracking(AppTypography.cardEyebrowTracking)
                        .foregroundStyle(DesignColors.textSecondary)
                    Text(isCodeRevealed ? referenceCode : Self.redactedCode)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(DesignColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.opacity)
                    Text(isCodeRevealed
                        ? "Auto-locks in a few seconds. Tap to copy."
                        : "Protected by Face ID — tap to reveal.")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: trailingIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(trailingIconColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private var trailingIconName: String {
        if didCopy { return "checkmark" }
        return isCodeRevealed ? "doc.on.doc" : "faceid"
    }

    private var trailingIconColor: Color {
        if didCopy { return DesignColors.accentWarm }
        return isCodeRevealed ? DesignColors.textSecondary : DesignColors.accent
    }

    private static let redactedCode = "••••–••••–••••–••••"

    // MARK: - Email input

    @ViewBuilder
    private var emailInputRow: some View {
        if sentSummary == nil {
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
                    .disabled(isSending)
                    .padding(.horizontal, AppLayout.spacingM)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if sentSummary != nil {
            VStack(spacing: AppLayout.spacingS) {
                WarmCapsuleButton(
                    "Done",
                    prominence: .primary,
                    isFullWidth: true,
                    action: { dismiss() }
                )
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.bottom, AppLayout.spacingL)
        } else {
            VStack(spacing: AppLayout.spacingS) {
                WarmCapsuleButton(
                    isSending ? "Sending…" : "Email me a copy",
                    prominence: .primary,
                    isFullWidth: true,
                    action: { Task { await sendViaBackend() } }
                )
                .disabled(isSending || !isEmailValid)

                Button(action: shareFile) {
                    Text("Other ways to share")
                        .font(.raleway("Medium", size: 14, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                        .underline(true, color: DesignColors.textSecondary.opacity(0.6))
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.bottom, AppLayout.spacingL)
        }
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
            // Non-fatal — the user can still type it manually.
        }
    }

    // MARK: - Actions

    private func handleReferenceCodeTap() {
        if isCodeRevealed {
            copyToClipboard()
        } else {
            Task { await unlockReferenceCode() }
        }
    }

    private func unlockReferenceCode() async {
        // `.deviceOwnerAuthentication` allows passcode fallback when
        // biometrics fail or aren't enrolled (simulator, older device).
        // `.deviceOwnerAuthenticationWithBiometrics` is stricter but
        // can lock the user out if they can't enroll Face ID.
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            // No biometrics + no passcode set. Fall back to revealing
            // without auth — the device itself has no lock surface.
            withAnimation(.easeInOut(duration: 0.25)) {
                isCodeRevealed = true
            }
            scheduleAutoRelock()
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Reveal the password that unlocks your encrypted export."
            )
            guard success else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                isCodeRevealed = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            copyToClipboard()
            scheduleAutoRelock()
        } catch {
            // User cancelled or auth failed — leave code locked.
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = referenceCode
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { didCopy = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.2)) { didCopy = false }
        }
    }

    private func scheduleAutoRelock() {
        relockTask?.cancel()
        relockTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                isCodeRevealed = false
            }
        }
    }

    private func sendViaBackend() async {
        guard !isSending, isEmailValid else { return }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = trimmed
        isSending = true

        defer { isSending = false }

        do {
            let payload = try buildExportData()
            let fileName = Self.exportFileName()
            let request = DataExportEmailRequest(
                to: trimmed,
                referenceCode: referenceCode,
                payloadB64: payload.base64EncodedString(),
                filename: fileName
            )
            let endpoint = try Endpoint.sendDataExportEmail(body: request)
            let _: DataExportEmailResponse = try await apiClient.send(endpoint)

            await persistEmail(trimmed)

            withAnimation(.easeInOut(duration: 0.3)) {
                sentSummary = SentSummary(email: trimmed)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func shareFile() {
        guard !isSending else { return }
        do {
            let url = try buildExportFile()
            shareItem = ExportShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Export pipeline

    private func buildExportData() throws -> Data {
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        let buildNumber = (info["CFBundleVersion"] as? String) ?? "0"

        return try DataExporter().exportAll(
            appVersion: appVersion,
            buildNumber: buildNumber,
            preferences: ExportablePreferences.snapshot(),
            referenceCode: referenceCode
        )
    }

    private func buildExportFile() throws -> URL {
        let data = try buildExportData()
        let fileName = Self.exportFileName()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func persistEmail(_ value: String) async {
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

    // MARK: - Helpers

    private static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return "cycleapp-export-\(formatter.string(from: .now)).json"
    }

    private static func isLikelyValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
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

// MARK: - Sent Summary

private struct SentSummary: Equatable {
    let email: String
}
