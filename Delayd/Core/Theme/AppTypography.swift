import SwiftUI

enum AppTypography {
    // MARK: - Families

    static let displayFamily = "SF Pro Display"
    static let bodyFamily = "SF Pro Text"
    static let numberFamily = "SF Mono"

    // MARK: - Hero Sizes

    static let impactNumberSize: CGFloat = 48
    static let goalNumberSize: CGFloat = 32
    static let sectionHeaderSize: CGFloat = 24

    // MARK: - Dynamic Type Fonts

    static let impactNumber = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    static let goalNumber = Font.system(.title, design: .monospaced, weight: .bold)
    static let sectionHeader = Font.system(.title2, design: .default, weight: .bold)
    static let title = Font.system(.title3, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let bodyMedium = Font.system(.body, design: .default, weight: .medium)
    static let callout = Font.system(.callout, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let captionMedium = Font.system(.caption, design: .default, weight: .medium)
}

private struct AppTypographyPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("48 days")
                    .font(AppTypography.impactNumber)
                    .foregroundStyle(AppColors.purplePrimary)
                Text("Impact number")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondaryLight)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Bali trip")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text("Section header")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            Text("Every expense is framed by the time it moves your dream.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Typography Light") {
    AppTypographyPreview()
        .preferredColorScheme(.light)
}

#Preview("App Typography Dark") {
    AppTypographyPreview()
        .preferredColorScheme(.dark)
}
