import SwiftUI

// MARK: - Profile Health Card
//
// Entry point for editing the user's menstrual cycle data. Mirrors
// the ProfileDetailsCard shape: a single tappable row + trailing
// dashed-gradient ProfileNavChip. The actual editor is push'd via
// the parent's delegate handling.

public struct ProfileHealthCard: View {
    public let onEdit: () -> Void

    public init(onEdit: @escaping () -> Void) {
        self.onEdit = onEdit
    }

    public var body: some View {
        Button(action: onEdit) {
            HStack {
                Text("Cycle data")
                    .font(.raleway("Medium", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Spacer()
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, AppLayout.spacingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        .overlay(alignment: .trailing) {
            ProfileNavChip()
                .padding(.trailing, AppLayout.spacingM)
                .allowsHitTesting(false)
        }
    }
}
