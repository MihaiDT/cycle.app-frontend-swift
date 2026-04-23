import ComposableArchitecture
import SwiftUI

// MARK: - Month Section Header

struct MonthSectionHeader: View {
    let date: Date

    private static let monthOnly: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM"
        return fmt
    }()

    private static let monthYear: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt
    }()

    private var isCurrentYear: Bool {
        Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DesignColors.divider)
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            Text(isCurrentYear ? Self.monthOnly.string(from: date) : Self.monthYear.string(from: date))
                .font(.raleway("Bold", size: 16, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Blur Modifier

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

// MARK: - Weekday Labels

struct WeekdayLabelsRow: View {
    private let labels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.raleway("Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Calendar Empty State

/// Shown when the calendar grid has no period data yet. Sits centered on the
/// grid with a subtle warm card inviting the user to log their first period.
struct CalendarEmptyStateCard: View {
    var onLogTapped: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(DesignColors.accentWarm.opacity(0.7))
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("No cycle data yet")
                        .font(.raleway("Bold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                        .multilineTextAlignment(.center)

                    Text("Log your first period to see predictions,\nfertile windows and your phase today.")
                        .font(.raleway("Regular", size: 13, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Button {
                    onLogTapped()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Log my first period")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: DesignColors.accentWarm.opacity(0.35), radius: 10, x: 0, y: 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens edit-period mode to mark your first period days")
                .padding(.top, 2)
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(DesignColors.accent.opacity(0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(DesignColors.accentWarm.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
            }
            .padding(.horizontal, 28)

            Spacer()
            // Leave room for the floating "Log Symptoms / Edit Period" bar
            // so the empty-state card doesn't collide with it.
            Color.clear.frame(height: 80)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cycle data yet. Log your first period to see predictions, fertile windows, and your phase today.")
    }
}

