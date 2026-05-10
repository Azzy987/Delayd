import Foundation

enum DelayTextFormatter {
    static func daysText(_ days: Int) -> String {
        if days <= 0 { return "<1 day" }
        return "\(days) \(days == 1 ? "day" : "days")"
    }

    static func shortDaysText(_ days: Int) -> String {
        if days <= 0 { return "<1d" }
        return "\(days)d"
    }
}
