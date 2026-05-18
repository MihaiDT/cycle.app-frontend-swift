import SwiftUI

// MARK: - DataExportReadyView Sections
//
// Section view builders + the chrome around them (footer
// background, derived presentation helpers like the trailing icon
// name on the password card). Split out so the main file stays
// under the CLAUDE.md 500-line threshold.

extension DataExportReadyView {

    // MARK: - Hero

    var heroIcon: some View {
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

    var titleBlock: some View {
        Text(sentSummary != nil ? "Email sent" : "Your data is ready")
            .font(AppTypography.displayHeader)
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppLayout.spacingS)
    }

    @ViewBuilder
    var copyBlock: some View {
        if let sent = sentSummary {
            (
                Text("We sent a download link to ")
                + Text(sent.email)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignColors.text)
                + Text(". The link works once and expires in 72 hours. Check spam if you don't see it within a minute.")
            )
            .font(AppTypography.bodyMedium)
            .foregroundStyle(DesignColors.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppLayout.spacingS)
        } else {
            Text("Add your email and we'll send a one-shot download link. It works once and expires in 72 hours.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppLayout.spacingS)
        }
    }

    // MARK: - Reference code

    var referenceCodeRow: some View {
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
                        : "Protected by Face ID. Tap to reveal.")
                        .font(AppTypography.caption)
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

    var trailingIconName: String {
        if didCopy { return "checkmark" }
        return isCodeRevealed ? "doc.on.doc" : "faceid"
    }

    var trailingIconColor: Color {
        if didCopy { return DesignColors.accentWarm }
        return isCodeRevealed ? DesignColors.textSecondary : DesignColors.accent
    }

    static var redactedCode: String { "••••–••••–••••–••••" }

    // MARK: - Email input

    @ViewBuilder
    var emailInputRow: some View {
        if sentSummary == nil {
            VStack(alignment: .leading, spacing: 6) {
                Text("Send to")
                    .font(AppTypography.cardEyebrow)
                    .tracking(AppTypography.cardEyebrowTracking)
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.horizontal, AppLayout.spacingM)
                    .padding(.top, 14)

                TextField("you@example.com", text: $email)
                    .font(AppTypography.rowTitle)
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

    // MARK: - Privacy callout

    @ViewBuilder
    var privacyCallout: some View {
        if sentSummary == nil {
            HStack(alignment: .top, spacing: AppLayout.spacingS) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stays under your control")
                        .font(AppTypography.cardLabel)
                        .foregroundStyle(DesignColors.text)
                    Text("Your encrypted archive is held on our server for up to 72 hours so the email link can fetch it. We delete it the moment you download, or sooner if the link expires. Only your device has the password.")
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
    }

    // MARK: - Footer

    @ViewBuilder
    var footer: some View {
        if sentSummary != nil {
            WarmCapsuleButton(
                "Done",
                prominence: .primary,
                isFullWidth: true,
                action: { (onComplete ?? { dismiss() })() }
            )
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingL)
            .padding(.bottom, AppLayout.spacingS)
            .background { footerBackground }
        } else {
            VStack(spacing: AppLayout.spacingS) {
                if isInCooldown {
                    Text(cooldownText)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppLayout.spacingS)
                }

                WarmCapsuleButton(
                    emailButtonTitle,
                    prominence: .primary,
                    isFullWidth: true,
                    action: { Task { await sendViaBackend() } }
                )
                .disabled(isSending || !isEmailValid || isInCooldown)

                Button(action: shareFile) {
                    Text("Other ways to share")
                        .font(AppTypography.linkLabel)
                        .foregroundStyle(DesignColors.textSecondary)
                        .underline(true, color: DesignColors.textSecondary.opacity(0.6))
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingL)
            .padding(.bottom, AppLayout.spacingS)
            .background { footerBackground }
        }
    }

    // Frosted blur + warm peach ramp, identical to the one used
    // on DownloadDataView. Mirrors the header's AppleHealthBackground
    // tint so the two ends of the screen feel symmetric.
    var footerBackground: some View {
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

    // MARK: - Derived presentation

    var emailButtonTitle: String {
        if isSending { return "Sending…" }
        if isInCooldown { return "Wait for the previous link" }
        return "Email me a copy"
    }

    var isEmailValid: Bool {
        Self.isLikelyValidEmail(email)
    }

    var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }
}
