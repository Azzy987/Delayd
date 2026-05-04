import SwiftUI

enum AppColors {
    // MARK: - Backgrounds
    //
    // We distinguish THREE background layers per theme:
    //   • background — outermost page fill (lightest grey / deepest purple-black)
    //   • softSurface — the recessed section behind hero-gradient areas (e.g.
    //     Home's bottom sheet, Plan's scroll bg). Slightly warmer than
    //     `background` so cards-on-top have visible edges.
    //   • surface / card — elevated cards and sheets (pure white on light;
    //     elevated navy-purple on dark).
    // This three-tier system is what gives the app depth without needing
    // shadows in dark mode (where shadows read as black rectangles).

    static let backgroundLight = rgb(250, 250, 252)
    static let softSurfaceLight = rgb(242, 241, 247)
    static let surfaceLight = rgb(255, 255, 255)
    static let cardLight = rgb(255, 255, 255)
    static let backgroundDark = rgb(14, 10, 26)
    static let softSurfaceDark = rgb(20, 15, 38)
    static let surfaceDark = rgb(26, 21, 48)
    static let cardDark = rgb(32, 26, 56)

    // Tab bar fill — matches `surface` but named explicitly so theme tuning
    // on chrome doesn't require re-auditing every card call site.
    static let tabBarLight = rgb(255, 255, 255)
    static let tabBarDark = rgb(22, 17, 42)

    // MARK: - Text

    static let textPrimaryLight = rgb(10, 10, 15)
    static let textSecondaryLight = rgb(107, 100, 120)
    static let textTertiaryLight = rgb(155, 149, 168)
    static let textPrimaryDark = rgb(248, 246, 251)
    static let textSecondaryDark = rgb(165, 160, 181)
    static let textTertiaryDark = rgb(107, 100, 120)

    // MARK: - Accent

    static let purplePrimary = rgb(124, 92, 252)
    static let heroGradientStart = rgb(139, 111, 255)
    static let heroGradientEnd = rgb(107, 71, 224)
    static let softPurpleBackground = rgb(237, 231, 254)

    // MARK: - Functional

    static let positive = rgb(45, 190, 127)
    static let warning = rgb(255, 184, 77)
    static let negative = rgb(255, 90, 107)
    static let softPositiveBackground = rgb(229, 247, 238)
    static let softWarningBackground = rgb(255, 244, 225)
    static let softNegativeBackground = rgb(254, 234, 236)

    // MARK: - Special

    static let insightBannerBackground = rgb(10, 10, 15)
    static let insightBannerText = rgb(255, 255, 255)
    static let insightBannerAccent = rgb(139, 111, 255)
    static let insightBannerGlow = rgb(139, 111, 255).opacity(0.4)

    // MARK: - Borders

    static let borderLight = rgb(239, 236, 245)
    static let borderDark = rgb(42, 36, 64)

    // MARK: - Goal Categories

    static let travelBackground = rgb(255, 228, 212)
    static let travelAccent = rgb(255, 140, 90)
    static let techBackground = rgb(224, 232, 255)
    static let techAccent = rgb(90, 140, 255)
    static let homeBackground = rgb(255, 228, 240)
    static let homeAccent = rgb(255, 90, 157)
    static let vehicleBackground = rgb(228, 245, 255)
    static let vehicleAccent = rgb(90, 184, 255)
    static let educationBackground = rgb(237, 231, 254)
    static let educationAccent = rgb(124, 92, 252)
    static let weddingBackground = rgb(252, 228, 255)
    static let weddingAccent = rgb(196, 90, 255)
    static let emergencyBackground = rgb(255, 228, 228)
    static let emergencyAccent = rgb(255, 90, 90)
    static let savingsBackground = rgb(229, 247, 238)
    static let savingsAccent = rgb(45, 190, 127)
    static let customBackground = rgb(245, 240, 255)
    static let customAccent = rgb(139, 111, 255)

    // MARK: - Adaptive Access

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundDark : backgroundLight
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? surfaceDark : surfaceLight
    }

    /// Recessed layer sitting between `background` and elevated cards.
    /// Used for the bottom-sheet area behind Home's hero, and Plan's scroll
    /// background so cards on top don't disappear into the page.
    static func softSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? softSurfaceDark : softSurfaceLight
    }

    /// Elevated card fill. Pure white on light; a lifted navy-purple on dark.
    /// Prefer this over `Color.white` for any card-style container.
    static func card(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardDark : cardLight
    }

    /// Tab-bar specific fill. Kept separate from `surface` so we can tune the
    /// bottom chrome independently (the tab bar needs to read as "floating"
    /// on both themes).
    static func tabBar(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tabBarDark : tabBarLight
    }

    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textPrimaryDark : textPrimaryLight
    }

    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textSecondaryDark : textSecondaryLight
    }

    static func textTertiary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textTertiaryDark : textTertiaryLight
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? borderDark : borderLight
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}

private struct AppColorsPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    private let colors: [(String, Color)] = [
        ("Light bg", AppColors.backgroundLight),
        ("Surface", AppColors.surfaceLight),
        ("Dark bg", AppColors.backgroundDark),
        ("Dark surface", AppColors.surfaceDark),
        ("Purple", AppColors.purplePrimary),
        ("Positive", AppColors.positive),
        ("Warning", AppColors.warning),
        ("Negative", AppColors.negative),
        ("Travel", AppColors.travelBackground),
        ("Tech", AppColors.techBackground),
        ("Home", AppColors.homeBackground),
        ("Vehicle", AppColors.vehicleBackground),
        ("Education", AppColors.educationBackground),
        ("Wedding", AppColors.weddingBackground),
        ("Emergency", AppColors.emergencyBackground),
        ("Savings", AppColors.savingsBackground),
        ("Custom", AppColors.customBackground)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(color)
                            .frame(height: 64)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(AppColors.borderLight)
                            }
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Colors Light") {
    AppColorsPreview()
        .preferredColorScheme(.light)
}

#Preview("App Colors Dark") {
    AppColorsPreview()
        .preferredColorScheme(.dark)
}
