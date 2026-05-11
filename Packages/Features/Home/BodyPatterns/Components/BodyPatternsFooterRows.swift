import SwiftUI

// MARK: - Body Patterns Footer Rows
//
// Editorial "Learn" carousel below the patterns list. Two cards
// slide horizontally — one for the algorithm explainer, one for
// clinical safety guidance. Same shape language as Apple
// Health's "About Walking" carousel: illustration on top, title
// on the bottom-left, soft warm card.
//
// Title vocabulary intentionally avoids "About" to disambiguate
// from the toolbar `i` button on `BodyPatternsView`, which
// pushes `BodyPatternsAboutScreen` (privacy + feature framing —
// a meta surface, not subject content). The carousel is
// subject-matter; the toolbar is meta.

struct BodyPatternsFooterRows: View {
    let onHowItWorksTapped: () -> Void
    let onWhenToSeeDoctorTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader
            cards
        }
    }

    // MARK: - Section header

    /// Two-row header: tracked-caps eyebrow over a 22pt title.
    /// Mirrors the screen-level `AppScreenHeader` rhythm so the
    /// footer reads as a sub-section of the same surface, not a
    /// separate screen.
    private var sectionHeader: some View {
        // Single-line section title — same recipe as
        // `BodyPatternsSectionLabel`. The caps "EXPLORE"
        // eyebrow above the title was removed so all four
        // sections on the screen ("Recurring patterns",
        // "Just appearing", "Recently logged", "Learn more")
        // read as siblings of the same family.
        Text("Learn more")
            .font(.raleway("SemiBold", size: 18, relativeTo: .title3))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DesignColors.text,
                        DesignColors.textPrincipal,
                        DesignColors.text.opacity(0.85),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Cards

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                LearnCard(
                    title: "How patterns work",
                    eyebrow: "BASICS",
                    art: .asset("PatternsSpiral"),
                    onTap: onHowItWorksTapped
                )
                LearnCard(
                    title: "When to see a doctor",
                    eyebrow: "MEDICAL",
                    art: .asset("MedicalReport"),
                    onTap: onWhenToSeeDoctorTapped
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Learn card

/// One card in the Learn carousel. Top half is a warm panel
/// hosting either an SF Symbol or an asset illustration;
/// bottom half is white with an eyebrow + title. Card width is
/// fixed so the carousel paces predictably regardless of title
/// length.
///
/// Both cards share the same warm gradient panel, the same
/// centred crop, and the same `cardBackground` — so even when
/// the source illustration assets aren't from the same
/// editorial set, the *presentation* reads as one family. If
/// the illustrations themselves diverge in style (eg a glossy
/// 3D figure next to a flat icon), swap them at the asset
/// catalog level — this view stays uniform.
private struct LearnCard: View {
    enum Art: Equatable {
        case symbol(String)
        case asset(String)
    }

    let title: String
    let eyebrow: String
    let art: Art
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                illustration
                titlePanel
            }
            .frame(width: 220, height: 240)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(DesignColors.accentWarm.opacity(0.10), lineWidth: 0.5)
            }
            .shadow(color: DesignColors.accentWarm.opacity(0.10), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    /// Soft warm peach top fading to white. Same gradient on
    /// every card so the palette stays a single warm system,
    /// not a per-card decision.
    private var cardBackground: some View {
        LinearGradient(
            stops: [
                .init(color: DesignColors.accent.opacity(0.28), location: 0.0),
                .init(color: Color.white, location: 0.65),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var illustration: some View {
        ZStack {
            artwork
        }
        .frame(height: 170)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .clipped()
    }

    /// Centred crop, no rotation. The previous version tilted
    /// the asset −12° which read as casual sticker — fine for
    /// one card, inconsistent across two when each asset has a
    /// different visual mass. Centred on a uniform panel makes
    /// the carousel read as a single editorial set.
    @ViewBuilder
    private var artwork: some View {
        switch art {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(DesignColors.accentWarm)
                .shadow(color: DesignColors.accentWarm.opacity(0.20), radius: 6, x: 0, y: 3)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 130, maxHeight: 130)
        }
    }

    /// Title panel: tracked-caps eyebrow + 14pt Medium title.
    /// Title weight intentionally light — the illustration
    /// carries the visual mass, the title labels it. Heavier
    /// title competed with the artwork.
    private var titlePanel: some View {
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
}
