import SwiftUI

// MARK: - Body Patterns Section Label
//
// Caps section eyebrow rendered between widget cards. Aligned
// with the rest of the surface ("LOGGED THIS WEEK", "EXPLORE")
// — free-floating tracked caps in `accentWarmText`, no pill,
// no border. The previous capsule treatment made this label
// read heavier than its sibling sections; switching to plain
// caps keeps the three eyebrows visually identical so the
// surface reads as one editorial system.

struct BodyPatternsSectionLabel: View {
    let label: String
    let count: Int

    var body: some View {
        // Title Case section title with the same diagonal
        // gradient as `AppScreenHeader` titles — pulls the
        // section labels into the same editorial system as
        // "Your body's rhythm" / "Your cycle pulse".
        Text(label)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
    }
}
