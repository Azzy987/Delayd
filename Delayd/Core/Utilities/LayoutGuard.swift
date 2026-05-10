import CoreGraphics

enum LayoutGuard {
    /// Guards dimensions used in frame modifiers.
    /// Clamps invalid values to a safe fallback and triggers a debug assertion.
    static func dimension(
        _ rawValue: CGFloat,
        name: String,
        fallback: CGFloat = 0,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> CGFloat {
        if rawValue.isFinite, rawValue >= 0 {
            return rawValue
        }
        #if DEBUG
        assertionFailure("Invalid layout dimension for \(name): \(rawValue)", file: file, line: line)
        #endif
        return max(fallback, 0)
    }

    /// Guards progress / ratio values used for widths and offsets.
    /// Forces finite values and clamps into the 0...1 interval.
    static func unit(
        _ rawValue: CGFloat,
        name: String,
        fallback: CGFloat = 0,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> CGFloat {
        guard rawValue.isFinite else {
            #if DEBUG
            assertionFailure("Non-finite unit value for \(name): \(rawValue)", file: file, line: line)
            #endif
            return min(max(fallback, 0), 1)
        }

        let clamped = min(max(rawValue, 0), 1)
        if clamped != rawValue {
            #if DEBUG
            assertionFailure("Out-of-range unit value for \(name): \(rawValue)", file: file, line: line)
            #endif
        }
        return clamped
    }

    /// Guards finite scalar values that may be negative (e.g. offsets).
    static func scalar(
        _ rawValue: CGFloat,
        name: String,
        fallback: CGFloat = 0,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> CGFloat {
        guard rawValue.isFinite else {
            #if DEBUG
            assertionFailure("Non-finite scalar value for \(name): \(rawValue)", file: file, line: line)
            #endif
            return fallback
        }
        return rawValue
    }
}
