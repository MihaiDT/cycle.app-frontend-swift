import SwiftUI

// MARK: - Bond Blob Pair
//
// The signature "two-circle" mark used wherever Bonds appears (Card
// hero, AddBond intro, BondDetail hero). Two rotated blob assets
// overlapping horizontally — the asymmetric silhouette catches light
// differently at each angle so the pair reads as intentional, not
// duplicated. Optional breathing animation gives the mark a calm,
// alive presence; defaults off so cards stay cheap to render.

public struct BondBlobPair: View {
    public let leftAsset: String
    public let rightAsset: String
    public let leftRotation: Double
    public let rightRotation: Double
    public let size: CGFloat
    public let overlap: CGFloat
    public let breathing: Bool

    @State private var breath: CGFloat = 0

    public init(
        leftAsset: String = "BondBlobYou",
        rightAsset: String = "BondBlobEmpty",
        leftRotation: Double = -12,
        rightRotation: Double = 140,
        size: CGFloat = 180,
        overlap: CGFloat = 28,
        breathing: Bool = false
    ) {
        self.leftAsset = leftAsset
        self.rightAsset = rightAsset
        self.leftRotation = leftRotation
        self.rightRotation = rightRotation
        self.size = size
        self.overlap = overlap
        self.breathing = breathing
    }

    public var body: some View {
        HStack(spacing: -overlap) {
            blob(asset: leftAsset, rotation: leftRotation, phase: breath)
            blob(asset: rightAsset, rotation: rightRotation, phase: -breath)
        }
        .onAppear {
            guard breathing else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                breath = 1
            }
        }
    }

    private func blob(asset: String, rotation: Double, phase: CGFloat) -> some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .rotationEffect(.degrees(rotation))
            .frame(width: size, height: size)
            // Each blob breathes ±1.5% with opposite phase so the
            // pair feels like two beings exhaling against each other.
            .scaleEffect(1 + (phase * 0.015))
    }
}

#Preview {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        BondBlobPair(breathing: true)
    }
}
