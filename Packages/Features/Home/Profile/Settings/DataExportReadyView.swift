import SwiftUI
import UIKit

// MARK: - Data Export Ready View
//
// Confirmation screen after the user taps "Request data" on
// DownloadDataView. The actual export bundle is generated on
// device — there's no email round-trip — so the copy reframes
// the Clue-style "check your email" flow as "your encrypted
// file is ready, save the password, then share."
//
// Layout (top → bottom):
// - Hero icon disc
// - Title
// - Two body paragraphs explaining password + share step
// - Password code block with copy affordance
// - Sticky CTA at the bottom that opens the share sheet
//
// The password is generated once per screen lifecycle. Today
// it's display-only; once the export logic lands, this same
// string will key the encrypted archive.

struct DataExportReadyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password: String = DataExportReadyView.generatePassword()
    @State private var didCopy: Bool = false

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
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppLayout.spacingL) {
                    heroIcon
                    titleBlock
                    copyBlock
                    passwordRow
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

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(DesignColors.accentWarm)
        }
        .padding(.top, AppLayout.spacingM)
    }

    // MARK: - Text

    private var titleBlock: some View {
        Text("Your encrypted file is ready")
            .font(.raleway("Bold", size: 24, relativeTo: .title2))
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppLayout.spacingS)
    }

    private var copyBlock: some View {
        VStack(spacing: AppLayout.spacingM) {
            Text("We've bundled every cycle, symptom, and check-in into a single password-protected file. Save the password somewhere safe — you'll need it to open the file later.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tap the password below to copy it, then share the file from the next sheet.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppLayout.spacingXS)
    }

    // MARK: - Password

    private var passwordRow: some View {
        Button(action: copyPassword) {
            HStack(spacing: AppLayout.spacingS) {
                Text(password)
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
            "Share file",
            prominence: .primary,
            isFullWidth: true,
            action: shareFile
        )
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.bottom, AppLayout.spacingL)
    }

    // MARK: - Actions

    private func copyPassword() {
        UIPasteboard.general.string = password
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { didCopy = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.2)) { didCopy = false }
        }
    }

    private func shareFile() {
        // TODO: present UIActivityViewController with the generated
        // encrypted export bundle once the on-device assembly lands.
    }

    // MARK: - Password generation

    private static func generatePassword() -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<20).compactMap { _ in alphabet.randomElement() })
    }
}
