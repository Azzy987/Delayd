import SwiftUI

// MARK: - iPad content inset environment key

/// Horizontal inset (points, per side) that centres content at ~560pt on iPad.
/// Zero on iPhone. Views that want to participate add `.padding(.horizontal, iPadContentInset)`
/// to their *inner* content — backgrounds keep full-width so they extend edge-to-edge.
private struct iPadContentInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var iPadContentInset: CGFloat {
        get { self[iPadContentInsetKey.self] }
        set { self[iPadContentInsetKey.self] = newValue }
    }
}
