import SwiftUI

// MARK: - Profile Details Card
//
// Read-only birth data block. Tappable "Edit" footer row pushes
// EditProfile via the same delegate as the header.

public struct ProfileDetailsCard: View {
    public let birthDate: Date?
    public let birthTime: Date?
    public let birthPlace: String?
    public let onEdit: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    public init(
        birthDate: Date?,
        birthTime: Date?,
        birthPlace: String?,
        onEdit: @escaping () -> Void
    ) {
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.birthPlace = birthPlace
        self.onEdit = onEdit
    }

    public var body: some View {
        row(label: "Birth details")
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
            .overlay(alignment: .trailing) {
                editChip
                    .padding(.trailing, AppLayout.spacingM)
            }
    }

    private var editChip: some View {
        Button(action: onEdit) {
            ProfileNavChip()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit details")
    }

    private func row(label: String) -> some View {
        Button(action: onEdit) {
            HStack {
                Text(label)
                    .font(.raleway("Medium", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Spacer()
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, AppLayout.spacingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
