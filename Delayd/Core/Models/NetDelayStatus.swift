import Foundation

struct NetDelayStatus: Equatable, Sendable {
    let delayedDays: Int
    let aheadDays: Int

    var isAhead: Bool {
        aheadDays > 0
    }

    static let onPace = NetDelayStatus(delayedDays: 0, aheadDays: 0)

    static func make(totalDelayDays: Int, recoveredDays: Int) -> NetDelayStatus {
        let delayed = max(0, totalDelayDays - recoveredDays)
        let ahead = max(0, recoveredDays - totalDelayDays)
        return NetDelayStatus(delayedDays: delayed, aheadDays: ahead)
    }
}
