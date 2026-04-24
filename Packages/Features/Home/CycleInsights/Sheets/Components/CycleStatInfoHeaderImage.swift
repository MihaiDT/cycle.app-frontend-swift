import SwiftUI

// MARK: - Cycle Stat Info Header Image
//
// Full-bleed illustration at the top of each stat info screen. The
// image is a bespoke editorial asset (one per kind) shipped in the
// Asset Catalog — this view owns the layout and VoiceOver label so
// the parent screen can stay focused on copy.

struct CycleStatInfoHeaderImage: View {
    let kind: CycleStatInfoKind

    var body: some View {
        Image(kind.headerAsset)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(kind.headerAccessibilityLabel)
    }
}

// MARK: - Kind → header asset metadata

extension CycleStatInfoKind {
    var headerAsset: String {
        switch self {
        case .cycleLength:    return "CycleLengthInfoHeader"
        case .periodLength:   return "PeriodLengthInfoHeader"
        case .cycleVariation: return "CycleVariationInfoHeader"
        }
    }

    var headerAccessibilityLabel: String {
        switch self {
        case .cycleLength:
            return "Menstrual cycle length diagram: four phases (menstrual, follicular, ovulation, luteal) across a typical 21 to 35 day cycle."
        case .periodLength:
            return "Period length diagram: typical bleed runs 2 to 7 days, with flow shifting from onset through peak to tail."
        case .cycleVariation:
            return "Cycle length variation diagram: how much your cycle length shifts from month to month."
        }
    }
}
