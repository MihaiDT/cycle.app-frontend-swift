import Foundation

// MARK: - Date Extensions

extension Date {
    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    public var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    public var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    public var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: .now, toGranularity: .weekOfYear)
    }

    public var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: .now, toGranularity: .month)
    }

    public var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: .now, toGranularity: .year)
    }

    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    public var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    public func adding(_ component: Calendar.Component, value: Int) -> Date {
        Calendar.current.date(byAdding: component, value: value, to: self) ?? self
    }

    public func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    public func timeFormatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        return formatter.string(from: self)
    }

    public var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    public static let minute: TimeInterval = 60
    public static let hour: TimeInterval = 3600
    public static let day: TimeInterval = 86400
    public static let week: TimeInterval = 604_800
}
