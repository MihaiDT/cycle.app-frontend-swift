import ComposableArchitecture
import LocalAuthentication
import SwiftUI

// MARK: - DataExportReadyView Actions
//
// All side-effectful logic — Face ID reveal + clipboard, send via
// backend, share-sheet fallback, export bundle assembly, cooldown
// helpers, plus the small set of static factories used by the
// view (filename, regex, reference code generator). Split out so
// the main file + sections file stay readable.

extension DataExportReadyView {

    // MARK: - Lifecycle

    func hydrateEmailIfNeeded() async {
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

    // MARK: - Reference code reveal

    func handleReferenceCodeTap() {
        if isCodeRevealed {
            copyToClipboard()
        } else {
            Task { await unlockReferenceCode() }
        }
    }

    func unlockReferenceCode() async {
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

    func copyToClipboard() {
        UIPasteboard.general.string = referenceCode
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { didCopy = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.2)) { didCopy = false }
        }
    }

    func scheduleAutoRelock() {
        relockTask?.cancel()
        relockTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                isCodeRevealed = false
            }
        }
    }

    // MARK: - Send / share

    func sendViaBackend() async {
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

            // Engage the 72h cooldown so the user can't re-send
            // while their previous link is still valid. Stored as
            // a Unix timestamp in @AppStorage so it survives
            // relaunches and view re-mounts.
            lastSentAtRaw = Date.now.timeIntervalSince1970
            startCooldownTicker()

            withAnimation(.easeInOut(duration: 0.3)) {
                sentSummary = SentSummary(email: trimmed)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            exportError = error.localizedDescription
        }
    }

    func shareFile() {
        guard !isSending else { return }
        do {
            let url = try buildExportFile()
            shareItem = ExportShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Export pipeline

    func buildExportData() throws -> Data {
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

    func buildExportFile() throws -> URL {
        let data = try buildExportData()
        let fileName = Self.exportFileName()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    func persistEmail(_ value: String) async {
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

    // MARK: - Cooldown

    static let lastSentAtKey = "cycle.app.dataExport.lastSentAt"
    static let cooldownSeconds: TimeInterval = 72 * 60 * 60

    /// Seconds remaining until a fresh export email can be sent.
    /// Zero (or negative) when no cooldown is active. Reads
    /// `cooldownTickerTrigger` so the value re-evaluates whenever
    /// the ticker fires.
    var cooldownRemaining: TimeInterval {
        _ = cooldownTickerTrigger
        guard lastSentAtRaw > 0 else { return 0 }
        let elapsed = Date.now.timeIntervalSince1970 - lastSentAtRaw
        return max(0, Self.cooldownSeconds - elapsed)
    }

    var isInCooldown: Bool { cooldownRemaining > 0 }

    var cooldownText: String {
        let remaining = cooldownRemaining
        guard remaining > 0 else { return "" }
        let hours = Int(remaining / 3600)
        if hours >= 1 {
            return "Your previous link is still active. You can send a new one in about \(hours)h."
        }
        let minutes = max(1, Int(remaining / 60))
        return "Your previous link is still active. You can send a new one in about \(minutes) min."
    }

    func startCooldownTicker() {
        cooldownTickerTrigger &+= 1
        // No timer publisher needed for now — re-evaluation is
        // driven by the view rebuilding on relevant @State changes.
        // For a precise countdown we could swap in a
        // TimelineView(.periodic), but a minute resolution is
        // overkill since the copy rounds to hours.
    }

    // MARK: - Static factories

    static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return "cycleapp-export-\(formatter.string(from: .now)).json"
    }

    static func isLikelyValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static func generateReferenceCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let raw = (0..<16).compactMap { _ in alphabet.randomElement() }
        let chunks = stride(from: 0, to: raw.count, by: 4).map { i -> String in
            String(raw[i..<min(i + 4, raw.count)])
        }
        return chunks.joined(separator: "-")
    }
}
