import Foundation

public extension Calendar {
    /// Returns the first day of the month containing `date`, with time components stripped.
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
