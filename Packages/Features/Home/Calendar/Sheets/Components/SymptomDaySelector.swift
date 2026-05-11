import SwiftUI

/// Horizontal scroller that lets the user pick which day they're
/// logging symptoms for. Renders today + the previous five days
/// with **Today anchored on the leading edge**, so the user
/// always lands on today and scrolls back into history.
///
/// Layout intent:
///   * The ScrollView is allowed to extend edge-to-edge (the
///     caller is expected to drop the surrounding 24pt
///     gutter so the row reaches the sheet's full width).
///     The pills carry their own leading inset on the inner
///     HStack — when the user scrolls, pills can travel all
///     the way to the sheet's natural margin and look like
///     they're bleeding past the editorial column.
///   * Default ScrollView clip is kept on so the row's
///     content does NOT paint past the sheet's frame. Earlier
///     we ran with `scrollClipDisabled()` for an extra-wide
///     bleed, but the trailing pills were drawn in Home's
///     layer and stayed visible after the dismiss slide-out.
///     Edge-to-edge scrolling gives the same visual rhythm
///     without leaving a trail.
///   * The header places this row on its own line below the
///     close + save discs, so there's no overlap risk that
///     would justify clipping or masking.
struct SymptomDaySelector: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void

    /// Leading inset that the inner HStack carries so pills
    /// start at the editorial column rather than the sheet's
    /// hard edge — and can scroll past it once the user
    /// drags the row.
    private static let contentInset: CGFloat = 24

    /// Today + the previous five days, ordered NEWEST → OLDEST.
    /// Today sits first so it appears on the leading edge.
    private var dayOptions: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0...5).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: today)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dayOptions, id: \.self) { date in
                        SymptomDayPill(
                            label: Self.label(for: date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            onTap: {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                onSelect(date)
                            }
                        )
                        .id(date)
                    }
                }
                .padding(.horizontal, Self.contentInset)
                .padding(.vertical, 2)
            }
            // Soft trailing fade so the edge pill (1st May, 30
            // Apr, …) doesn't read as hard-clipped — gives the
            // row an Apple-Music-style visual cue that there's
            // more content beyond the visible window. The
            // leading edge stays opaque so Today / Yesterday
            // never look faded out at rest.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.10),
                        .init(color: .black, location: 0.90),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                if let first = dayOptions.first {
                    proxy.scrollTo(first, anchor: .leading)
                }
            }
        }
    }

    // MARK: - Label formatting

    /// "Today" / "Yesterday" for the most recent two; ordinal day +
    /// short month for the rest ("2nd May", "1st May", "30th Apr").
    private static func label(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let day = calendar.component(.day, from: date)
        let month = shortMonthFormatter.string(from: date)
        return "\(day)\(ordinalSuffix(for: day)) \(month)"
    }

    private static func ordinalSuffix(for day: Int) -> String {
        let mod100 = day % 100
        if (11...13).contains(mod100) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private static let shortMonthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt
    }()
}
