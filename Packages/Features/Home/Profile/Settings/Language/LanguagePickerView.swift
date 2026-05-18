import SwiftUI

// MARK: - Language Picker View
//
// In-app language switcher pushed from Settings → Language.
// Lists the eight locales declared in CFBundleLocalizations,
// plus a "Match system" row that clears the override and falls
// back to the device language.
//
// Mechanism: iOS reads the `AppleLanguages` UserDefaults key on
// every app launch to decide which language bundle to load. We
// write the user's pick there and prompt them to re-open the
// app — SwiftUI/UIKit's localised string tables aren't hot-
// swappable at runtime, so a process restart is the only way
// to repaint every screen in the new language.

struct LanguagePickerView: View {
    @State private var selection: AppLanguage?
    @State private var showRestartPrompt: Bool = false

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            scrollContent
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { selection = AppLanguageStorage.currentOverride }
        .alert("Restart to apply", isPresented: $showRestartPrompt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Close the app from the App Switcher and reopen it to see the new language.")
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                languagesSection
                noteSection
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingS)
            .padding(.bottom, AppLayout.spacingXL)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Sections

    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            sectionLabel("Display language")
                .padding(.horizontal, AppLayout.spacingXS)

            VStack(alignment: .leading, spacing: 0) {
                matchSystemRow
                divider
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                    languageRow(language)
                    if index < AppLanguage.allCases.count - 1 {
                        divider
                    }
                }
            }
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        }
    }

    private var noteSection: some View {
        Text("Switching the language reloads the app — close it from the App Switcher and re-open to see every screen translated.")
            .font(AppTypography.bodyMedium)
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, AppLayout.spacingXS)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTypography.cardEyebrow)
            .tracking(AppTypography.cardEyebrowTracking)
            .foregroundStyle(DesignColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rows

    private var matchSystemRow: some View {
        Button(action: { pick(nil) }) {
            HStack(spacing: AppLayout.spacingS) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Match system")
                        .font(AppTypography.rowTitle)
                        .foregroundStyle(DesignColors.text)
                    Text("Follow your iOS language setting")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Spacer(minLength: 0)

                checkmark(visible: selection == nil)
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        Button(action: { pick(language) }) {
            HStack(spacing: AppLayout.spacingS) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.englishName)
                        .font(AppTypography.rowTitle)
                        .foregroundStyle(DesignColors.text)
                    Text(language.autonym)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Spacer(minLength: 0)

                checkmark(visible: selection == language)
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkmark(visible: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DesignColors.accent)
            .opacity(visible ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: visible)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, AppLayout.spacingM)
    }

    // MARK: - Actions

    private func pick(_ language: AppLanguage?) {
        guard language != selection else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selection = language
        }
        AppLanguageStorage.setOverride(language)
        showRestartPrompt = true
    }
}
