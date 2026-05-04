import SwiftUI

enum AppSpacing {
    // MARK: - Scale

    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: - Component Padding

    static let cardHorizontalPadding: CGFloat = 20
    static let cardVerticalPadding: CGFloat = 24
    static let heroCardPadding: CGFloat = 24
}

private struct AppSpacingPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    private let tokens: [(String, CGFloat)] = [
        ("xs", AppSpacing.xs),
        ("sm", AppSpacing.sm),
        ("md", AppSpacing.md),
        ("lg", AppSpacing.lg),
        ("xl", AppSpacing.xl),
        ("xxl", AppSpacing.xxl)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(tokens, id: \.0) { name, value in
                HStack(spacing: AppSpacing.md) {
                    Text(name)
                        .font(.body.monospaced())
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .frame(width: 48, alignment: .leading)

                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.purplePrimary)
                        .frame(width: value, height: 16)

                    Text("\(Int(value))pt")
                        .font(.caption.monospaced())
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Spacing Light") {
    AppSpacingPreview()
        .preferredColorScheme(.light)
}

#Preview("App Spacing Dark") {
    AppSpacingPreview()
        .preferredColorScheme(.dark)
}
