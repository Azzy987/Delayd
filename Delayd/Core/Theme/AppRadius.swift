import SwiftUI

enum AppRadius {
    // MARK: - Scale

    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}

private struct AppRadiusPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    private let tokens: [(String, CGFloat)] = [
        ("sm", AppRadius.sm),
        ("md", AppRadius.md),
        ("lg", AppRadius.lg),
        ("xl", AppRadius.xl),
        ("pill", AppRadius.pill)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(tokens, id: \.0) { name, value in
                HStack(spacing: AppSpacing.md) {
                    RoundedRectangle(cornerRadius: value)
                        .fill(AppColors.surfaceLight)
                        .frame(width: 96, height: 56)
                        .overlay {
                            RoundedRectangle(cornerRadius: value)
                                .stroke(AppColors.borderLight)
                        }

                    Text("\(name): \(Int(value))")
                        .font(.body.monospaced())
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Radius Light") {
    AppRadiusPreview()
        .preferredColorScheme(.light)
}

#Preview("App Radius Dark") {
    AppRadiusPreview()
        .preferredColorScheme(.dark)
}
