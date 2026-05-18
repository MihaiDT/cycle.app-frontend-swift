import SwiftUI

// MARK: - Data Export Ready View
//
// Confirmation screen after the user taps "Request data" on
// DownloadDataView. The actual export bundle is generated on
// device — there's no email round-trip — so the copy reframes
// the Clue-style "check your email" flow as "your encrypted
// file is ready, save the referenceCode, then share."
//
// Layout (top → bottom):
// - Hero icon disc
// - Title
// - Two body paragraphs explaining referenceCode + share step
// - Reference code block with copy affordance
// - Sticky CTA at the bottom that opens the share sheet
//
// The referenceCode is generated once per screen lifecycle. Today
// it's display-only; once the export logic lands, this same
// string will key the encrypted archive.

struct DataExportReadyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var referenceCode: String = DataExportReadyView.generateReferenceCode()
    @State private var didCopy: Bool = false
    @State private var shareItem: ExportShareItem?
    @State private var exportError: String?
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
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Export failed", isPresented: exportErrorBinding, presenting: exportError) { _ in
            Button("OK") { exportError = nil }
        } message: { message in
            Text(message)
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
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
            Text("We've bundled every cycle, symptom, check-in, prediction, and HBI score into a single JSON file. It stays on this device until you choose where to share it.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tap the code below to copy it — keep it alongside the file as your export receipt.")
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
                Text(referenceCode)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(DesignColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(didCopy ? DesignColors.accentWarm : DesignColors.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    // MARK: - Footer

    private var footer: some View {
        WarmCapsuleButton(
            isGenerating ? "Preparing…" : "Share file",
            prominence: .primary,
            isFullWidth: true,
            action: shareFile
        )
        .disabled(isGenerating)
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.bottom, AppLayout.spacingL)
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

    private func shareFile() {
        guard !isGenerating else { return }
        isGenerating = true

        do {
            let info = Bundle.main.infoDictionary ?? [:]
            let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "0.0.0"
            let buildNumber = (info["CFBundleVersion"] as? String) ?? "0"

            let json = try DataExporter().exportAll(
                appVersion: appVersion,
                buildNumber: buildNumber,
                preferences: ExportablePreferences.snapshot()
            )

            let fileName = Self.exportFileName()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            try json.write(to: url, options: .atomic)

            shareItem = ExportShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }

        isGenerating = false
    }

    private static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return "cycleapp-export-\(formatter.string(from: .now)).json"
    }

    // MARK: - Reference code generation

    private static func generateReferenceCode() -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<20).compactMap { _ in alphabet.randomElement() })
    }
}
