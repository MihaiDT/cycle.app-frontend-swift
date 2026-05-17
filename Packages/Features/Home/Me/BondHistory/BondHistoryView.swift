import ComposableArchitecture
import SwiftUI

// MARK: - Bond History View
//
// Editorial list of every saved bond. Top bar carries the standard
// `GlassBackButton` and a title. Each row shows the bond's name (or
// "Anonymous"), the birth place, and a "created" date stamp. Tap a
// row to open its reading. An Add button at the bottom kicks off a
// fresh AddBond flow. Empty state copy + an inline add CTA shows
// when the user hasn't created any bonds yet.

public struct BondHistoryView: View {
    @Bindable var store: StoreOf<BondHistoryFeature>

    public init(store: StoreOf<BondHistoryFeature>) {
        self.store = store
    }

    private static let createdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    public var body: some View {
        // Note: we do NOT wrap this view in a `NavigationStack` even
        // though Body Patterns / Cycle Details do — those screens
        // are pushed inside an existing navigation context, while
        // this one is rendered as a sibling ZStack overlay inside
        // `HomeView`. Nesting a NavigationStack there triggered a
        // runaway layout loop (CPU 99%, frozen UI). The custom
        // header below mirrors the toolbar look (glass back button
        // on leading, centred title in Raleway SemiBold 17pt)
        // without the nav-stack machinery.
        ZStack(alignment: .topLeading) {
            AppleHealthBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navHeader

                if store.bonds.isEmpty {
                    emptyState
                        .padding(.horizontal, AppLayout.screenHorizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(store.bonds) { bond in
                                bondRow(bond)
                            }

                            addBondRow
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, AppLayout.screenHorizontal)
                        .padding(.top, AppLayout.spacingL)
                        .padding(.bottom, AppLayout.spacingXXL)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    // MARK: - Nav header
    //
    // Mirrors the iOS 17 nav bar layout used elsewhere — 44pt-ish
    // top inset (covered by the safe area), `nativeGlass` chevron
    // disc on the leading edge, title centred in Raleway SemiBold
    // 17pt. Title also lives directly in the foreground because
    // there's no system nav bar to render it for us.

    private var navHeader: some View {
        ZStack {
            Text("Your bonds")
                .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    store.send(.backTapped)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                        .frame(width: 44, height: 44)
                        .nativeGlass(in: Circle(), interactive: true)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()
            }
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Bond row

    private func bondRow(_ bond: Bond) -> some View {
        Button {
            store.send(.rowTapped(bond.id))
        } label: {
            HStack(alignment: .center, spacing: 16) {
                Image("BondBlobYou")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(bond.displayName)
                        .font(.raleway("SemiBold", size: 18, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPrincipal)

                    Text(Self.createdFormatter.string(from: bond.createdAt))
                        .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Spacer(minLength: 0)

                bondRowArrowChip
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(rowSurface)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Mirror of `BondsCard`'s arrow chip — same dashed cycle-
    /// gradient ring + `arrow.up.right`, sized down to 38pt so it
    /// sits naturally in a row's trailing column without crowding
    /// the date. Visual cue that tapping the row opens a full-
    /// screen reading, not just an inline expansion.
    private var bondRowArrowChip: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignColors.calendarPeriodGlyph,
                            DesignColors.calendarFollicularGlyph,
                            DesignColors.calendarFertileGlyph,
                            DesignColors.calendarLutealGlyph,
                            DesignColors.calendarPeriodGlyph,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 4])
                )
            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignColors.text)
        }
        .frame(width: 38, height: 38)
    }

    private var rowSurface: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        DesignColors.accentSecondary.opacity(0.25),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: DesignColors.text.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Add bond row

    private var addBondRow: some View {
        Button {
            store.send(.addBondTapped)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Text("Add another bond")
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPrincipal)

                Spacer(minLength: 0)

                // Dashed `+` chip moved from leading to trailing —
                // the "add" affordance now lives where the
                // companion bond rows show their "open" arrow chip,
                // keeping the trailing column visually consistent
                // across rows.
                ZStack {
                    Circle()
                        .stroke(
                            DesignColors.accentWarm.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.4, dash: [3, 4])
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.accentWarm)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignColors.accentWarm.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                DesignColors.accentWarm.opacity(0.35),
                                style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
                            )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                // Same hero footprint as Name / BirthDate /
                // BirthTime / BirthPlace screens (Venn 180pt,
                // blob 132pt, container 180pt) so the empty
                // state reads as part of the same visual family.
                VennCirclesWatermark(
                    strokeColor: DesignColors.textSecondary,
                    lineWidth: 1.6,
                    opacity: 0.18,
                    circleSize: 180,
                    overlap: 74
                )

                // Blob rendered in greyscale + a centred "?" mark
                // — the unknown-identity treatment for a slot
                // waiting to be filled. The blob still rotates
                // 140° to match the rest of the flow; the "?"
                // sits upright on top so it reads cleanly.
                ZStack {
                    Image("BondBlobEmpty")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 132, height: 132)
                        .rotationEffect(.degrees(140))
                        .grayscale(1.0)

                    Text("?")
                        .font(.raleway("Bold", size: 54, relativeTo: .largeTitle))
                        .foregroundStyle(DesignColors.textPrincipal.opacity(0.78))
                }
            }
            .frame(height: 180)

            VStack(spacing: 8) {
                Text("Nothing here yet")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.textPrincipal)

                Text("Add your first bond and we'll start mapping the rhythms between you.")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            WarmCapsuleButton(
                "Add a bond",
                prominence: .primary,
                isFullWidth: false
            ) {
                store.send(.addBondTapped)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("With bonds") {
    BondHistoryView(
        store: .init(
            initialState: BondHistoryFeature.State(
                bonds: IdentifiedArrayOf(uniqueElements: [
                    Bond.mock(seed: 0),
                    Bond.mock(seed: 1),
                    Bond.mock(seed: 2),
                ])
            )
        ) {
            BondHistoryFeature()
        }
    )
}

#Preview("Empty") {
    BondHistoryView(
        store: .init(initialState: BondHistoryFeature.State()) {
            BondHistoryFeature()
        }
    )
}
