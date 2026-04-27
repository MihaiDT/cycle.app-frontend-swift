import SwiftUI

// MARK: - Empty Chart State
//
// Slot-in replacement for a chart when the underlying metric has
// no usable samples yet. Softer than an empty Chart{} — gives the
// user a hint about what to do to populate it.

struct BodySignalsEmptyChart: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "applewatch")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
            Text(message)
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
    }
}
