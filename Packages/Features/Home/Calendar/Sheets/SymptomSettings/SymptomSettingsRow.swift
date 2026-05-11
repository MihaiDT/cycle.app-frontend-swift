import SwiftUI

/// One row inside `SymptomSettingsView`'s list. Owns a leading
/// icon disc, a title + subtitle stack, and a trailing accessory
/// that varies per row type — informational pill, native
/// `Toggle`, or chevron drill-in.
///
/// The toggle case takes a real `Binding<Bool>` so the row
/// drives state mutations directly. The Equatable conformance
/// on `Trailing` is hand-rolled to skip the binding (which
/// can't be Equatable on its own).
struct SymptomSettingsRow: View {
    enum Trailing {
        case comingSoon
        case toggle(Binding<Bool>)
        case chevron
    }

    let icon: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            iconDisc
            textStack
            Spacer(minLength: 0)
            trailingAccessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Pieces

    private var iconDisc: some View {
        ZStack {
            Circle()
                .fill(DesignColors.accentWarm.opacity(0.12))
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignColors.accentWarm)
        }
        .frame(width: 36, height: 36)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
            Text(subtitle)
                .font(.raleway("Regular", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch trailing {
        case .comingSoon:
            Text("Coming soon")
                .font(.raleway("Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(DesignColors.structure.opacity(0.10))
                }
        case .toggle(let binding):
            // Native SwiftUI Toggle, tinted to the brand warm so
            // the on-state matches the rest of the warm-accent
            // system on the symptom sheet. `labelsHidden()`
            // keeps the row's typography in `textStack`.
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(DesignColors.accentWarm)
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }
}
