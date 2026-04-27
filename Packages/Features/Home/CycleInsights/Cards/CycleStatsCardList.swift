import SwiftUI
import UIKit

// MARK: - UIKit-backed scroll container for Cycle Stats cards
//
// SwiftUI's `ScrollView + VStack` and `List` both ran into iOS 26
// scroll overhead: `AG::Graph::value_set` + `ViewGraph.beginNextUpdate`
// dominated the Time Profiler even for plain-text rows, and Apple
// Health's equivalent feed doesn't use native SwiftUI scroll — it
// uses UIKit's UICollectionView. This component matches that
// architecture.
//
// Each SwiftUI card gets wrapped in `UIHostingConfiguration` inside
// a UICollectionViewCell. Scrolling is 100% UIKit (UIScrollView
// under the hood), and only the visible cells evaluate their
// SwiftUI body. The outer SwiftUI view graph does no work while
// scrolling.

struct CycleStatsCardList<CardID: Hashable & Sendable>: UIViewRepresentable {
    let cards: [CardID]
    let contentInsets: UIEdgeInsets
    let interItemSpacing: CGFloat
    let cardContent: (CardID) -> AnyView
    let trailingContent: () -> AnyView
    /// Optional header cell rendered above the first card, scrolling
    /// with the rest of the list.
    let leadingContent: (() -> AnyView)?
    /// Called on every scroll tick with the current contentOffset.y.
    /// Used by callers that want to parallax a header element.
    let onScroll: ((CGFloat) -> Void)?
    /// Bump this when downstream data that any card renders has
    /// changed but the card identities haven't. UICollectionView
    /// caches its cells, so without a reconfigure signal the cell's
    /// hosted SwiftUI view stays on the old closure values.
    let reconfigureToken: AnyHashable?

    init(
        cards: [CardID],
        contentInsets: UIEdgeInsets,
        interItemSpacing: CGFloat,
        cardContent: @escaping (CardID) -> AnyView,
        trailingContent: @escaping () -> AnyView,
        leadingContent: (() -> AnyView)? = nil,
        onScroll: ((CGFloat) -> Void)? = nil,
        reconfigureToken: AnyHashable? = nil
    ) {
        self.cards = cards
        self.contentInsets = contentInsets
        self.interItemSpacing = interItemSpacing
        self.cardContent = cardContent
        self.trailingContent = trailingContent
        self.leadingContent = leadingContent
        self.onScroll = onScroll
        self.reconfigureToken = reconfigureToken
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = Self.makeLayout(
            insets: contentInsets,
            interItemSpacing: interItemSpacing
        )
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.alwaysBounceVertical = true
        cv.contentInsetAdjustmentBehavior = .automatic
        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator
        cv.register(HostingCell.self, forCellWithReuseIdentifier: "card")
        context.coordinator.parent = self
        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        // `updateUIView` fires whenever the parent SwiftUI body
        // re-evaluates — which happens on every observed store
        // mutation, not just layout changes. Data-only updates
        // (stats loaded, loading flag flipped, detail sheet toggled)
        // propagate naturally through each hosted card's SwiftUI
        // observation, so `reloadData()` is wasted work in those
        // cases — it evicts cell content and forces every visible
        // cell to re-host its `UIHostingConfiguration`, which is
        // the single biggest cause of scroll hitches on this screen.
        //
        // We only reload when the card *identity* or *order* actually
        // changed (customize layout edit, card added/removed), or
        // when the cell count shifts. Otherwise we just refresh the
        // coordinator's `parent` reference so the next natural
        // `cellForItemAt` call (on reuse) sees the latest closures.
        let coord = context.coordinator
        let newCards = cards.map { AnyHashable($0) }
        let needsReload = coord.lastCards != newCards
        let tokenChanged = coord.lastReconfigureToken != reconfigureToken
        coord.parent = self
        coord.lastCards = newCards
        coord.lastReconfigureToken = reconfigureToken
        if needsReload {
            cv.reloadData()
        } else if tokenChanged {
            // Re-host every visible cell against the latest closures
            // without evicting layout. Cheaper than `reloadData()`:
            // no cell removal, no flash, scroll position preserved.
            let visible = cv.indexPathsForVisibleItems
            if !visible.isEmpty {
                cv.reconfigureItems(at: visible)
            }
        }
    }

    private static func makeLayout(
        insets: UIEdgeInsets,
        interItemSpacing: CGFloat
    ) -> UICollectionViewCompositionalLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(220)
                    )
                )
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(220)
                    ),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: insets.top,
                    leading: insets.left,
                    bottom: insets.bottom,
                    trailing: insets.right
                )
                section.interGroupSpacing = interItemSpacing
                return section
            },
            configuration: config
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        var parent: CycleStatsCardList?
        /// Last-seen card identities, used by `updateUIView` to
        /// decide whether `reloadData` is actually needed.
        var lastCards: [AnyHashable] = []
        /// Last-seen reconfigure token. Triggers `reconfigureItems`
        /// (not `reloadData`) when downstream card data changes.
        var lastReconfigureToken: AnyHashable?

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            guard let parent else { return 0 }
            let leading = parent.leadingContent != nil ? 1 : 0
            // cards + leading header (if any) + trailing "Customize" button row
            return parent.cards.count + 1 + leading
        }

        func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = cv.dequeueReusableCell(
                withReuseIdentifier: "card",
                for: indexPath
            ) as! HostingCell

            guard let parent else { return cell }

            let hasLeading = parent.leadingContent != nil
            let leadingCount = hasLeading ? 1 : 0

            // Index 0 is the leading header, if present.
            if hasLeading, indexPath.item == 0 {
                cell.host(parent.leadingContent!())
                return cell
            }

            // Cards occupy [leadingCount, leadingCount + cards.count).
            let cardIndex = indexPath.item - leadingCount
            if cardIndex < parent.cards.count {
                let card = parent.cards[cardIndex]
                cell.host(parent.cardContent(card))
            } else {
                cell.host(parent.trailingContent())
            }
            return cell
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent?.onScroll?(scrollView.contentOffset.y)
        }
    }

    // MARK: - Hosting Cell

    final class HostingCell: UICollectionViewCell {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            // `contentConfiguration = UIHostingConfiguration(...)` is
            // Apple's recommended path for SwiftUI-in-UIKit cell
            // content (iOS 16+). Auto-sizes the cell from the
            // SwiftUI view's intrinsic content size, and reuses the
            // underlying UIHostingController across cell recycling,
            // which is the whole point — no per-cell SwiftUI render
            // tree bootstrap cost during scroll.
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

        func host<Content: View>(_ content: Content) {
            contentConfiguration = UIHostingConfiguration {
                content
            }
            .margins(.all, 0)
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            // Leave `contentConfiguration` alone — the next
            // `cellForItemAt` call reassigns it with the correct
            // content for the new position. Clearing it here would
            // force a flash of empty space on reuse.
        }
    }
}
