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
        coord.parent = self
        coord.lastCards = newCards
        if needsReload {
            cv.reloadData()
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

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            guard let parent else { return 0 }
            return parent.cards.count + 1 // +1 for trailing "Customize" button row
        }

        func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = cv.dequeueReusableCell(
                withReuseIdentifier: "card",
                for: indexPath
            ) as! HostingCell

            guard let parent else { return cell }

            if indexPath.item < parent.cards.count {
                let card = parent.cards[indexPath.item]
                cell.host(parent.cardContent(card))
            } else {
                cell.host(parent.trailingContent())
            }
            return cell
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
