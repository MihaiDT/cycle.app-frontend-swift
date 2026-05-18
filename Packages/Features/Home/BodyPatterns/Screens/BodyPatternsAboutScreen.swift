import SwiftUI

/// Compact context screen pushed from the header `i` button on
/// Body Patterns. Three sections — what the feature is, where
/// the data lives, and what it isn't (medical advice).
///
/// Kept short on purpose: the deep explainers live on
/// `HowPatternsWorkScreen` and `WhenToSeeDoctorScreen`. This
/// screen only frames the surface and points at them.
struct BodyPatternsAboutScreen: View {
    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AppScreenHeader(
                        eyebrow: "About",
                        title: "Body Patterns"
                    )

                    EducationalSection(
                        eyebrow: "What this is",
                        paragraph: "Body Patterns reads the symptoms you log and surfaces the ones that keep showing up at the same point in your cycle.\n\nIt needs at least three full cycles of data to start seeing confirmed patterns. Less than that, and we'll show emerging ones – worth noticing, not yet stable."
                    )

                    EducationalSection(
                        eyebrow: "Your data stays on your device",
                        paragraph: "Symptoms, periods, and patterns live in your iPhone's encrypted health storage. They sync across your devices through your iCloud account using end-to-end encryption – we don't have keys, we don't read your data, we don't sell it. Ever."
                    )

                    EducationalSection(
                        eyebrow: "This isn't medical advice",
                        paragraph: "Patterns are observations, not diagnoses. If something concerns you, check with a clinician. The When to see a doctor page lists the signs that always deserve a conversation."
                    )

                    MedicalDeviceDisclaimer()

                    // Learn more carousel — the same cards
                    // that used to live on `BodyPatternsView`.
                    // Moved here so the main surface stays
                    // focused on detected patterns + recent
                    // logs, and the educational drill-ins live
                    // in one place (the `i` button → About).
                    // Cards use `NavigationLink` so the push is
                    // native to this screen's `NavigationStack`
                    // — no need to round-trip through reducer
                    // destination state.
                    learnMoreSection
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Body Patterns")
                    .font(AppTypography.rowTitleEmphasized)
                    .foregroundStyle(DesignColors.text)
            }
        }
    }

    // MARK: - Learn more

    private var learnMoreSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EXPLORE")
                    .font(.raleway("Bold", size: 12, relativeTo: .caption2))
                    .tracking(1.6)
                    .foregroundStyle(DesignColors.accentWarmText)

                Text("Learn more")
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title3))
                    .foregroundStyle(DesignColors.text)
            }

            HStack(spacing: 14) {
                NavigationLink {
                    HowPatternsWorkScreen()
                } label: {
                    learnCard(
                        eyebrow: "BASICS",
                        title: "How patterns work",
                        asset: "PatternsSpiral"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WhenToSeeDoctorScreen()
                } label: {
                    learnCard(
                        eyebrow: "MEDICAL",
                        title: "When to see a doctor",
                        asset: "MedicalReport"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func learnCard(
        eyebrow: String,
        title: String,
        asset: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 130, maxHeight: 130)
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.2)
                    .foregroundStyle(DesignColors.accentWarm)
                Text(title)
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(
                stops: [
                    .init(color: DesignColors.accent.opacity(0.28), location: 0.0),
                    .init(color: Color.white, location: 0.65),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(DesignColors.accentWarm.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: DesignColors.accentWarm.opacity(0.10), radius: 18, x: 0, y: 12)
    }

    // Disclaimer is now provided by the shared
    // `MedicalDeviceDisclaimer` component (see callsite
    // above) so the wording + typography stay identical
    // across every educational surface in the app.
}
