import SwiftUI

/// The user's preferred colour-scheme override.
/// Stored as a `String` rawValue in `UserSettings` and `UserDefaults`
/// so the choice survives app updates without a SwiftData migration issue.
enum AppTheme: String, CaseIterable, Identifiable {
    case system  = "system"
    case light   = "light"
    case dark    = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System Default"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }

    /// The `ColorScheme?` to pass to `.preferredColorScheme()`.
    /// `nil` means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    static let defaultsKey = "delayd.appTheme"
}

extension Notification.Name {
    static let delaydThemeChanged = Notification.Name("delayd.themeChanged")
}
