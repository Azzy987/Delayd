import SwiftUI

struct AppShadowToken {
    let color: Color
    let blur: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppShadows {
    // MARK: - Light

    static let cardLight = AppShadowToken(color: .black.opacity(0.06), blur: 16, x: 0, y: 4)
    static let heroCardLight = AppShadowToken(color: AppColors.purplePrimary.opacity(0.12), blur: 24, x: 0, y: 8)
    static let floatingButtonLight = AppShadowToken(color: AppColors.purplePrimary.opacity(0.30), blur: 20, x: 0, y: 8)

    // MARK: - Dark

    static let cardDark = AppShadowToken(color: .black.opacity(0.03), blur: 16, x: 0, y: 4)
    static let heroCardDark = AppShadowToken(color: AppColors.purplePrimary.opacity(0.06), blur: 24, x: 0, y: 8)
    static let floatingButtonDark = AppShadowToken(color: AppColors.purplePrimary.opacity(0.15), blur: 20, x: 0, y: 8)

    // MARK: - Adaptive Access

    static func card(for colorScheme: ColorScheme) -> AppShadowToken {
        colorScheme == .dark ? cardDark : cardLight
    }

    static func heroCard(for colorScheme: ColorScheme) -> AppShadowToken {
        colorScheme == .dark ? heroCardDark : heroCardLight
    }

    static func floatingButton(for colorScheme: ColorScheme) -> AppShadowToken {
        colorScheme == .dark ? floatingButtonDark : floatingButtonLight
    }
}

private struct AppShadowsPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    private let tokens: [(String, AppShadowToken)] = [
        ("Card", AppShadows.cardLight),
        ("Hero", AppShadows.heroCardLight),
        ("Floating", AppShadows.floatingButtonLight)
    ]

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ForEach(tokens, id: \.0) { name, shadow in
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(name == "Hero" ? AnyShapeStyle(AppGradients.heroGradient) : AnyShapeStyle(AppColors.surfaceLight))
                    .frame(height: 96)
                    .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)
                    .overlay {
                        Text(name)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(name == "Hero" ? .white : AppColors.textPrimary(for: colorScheme))
                    }
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Shadows Light") {
    AppShadowsPreview()
        .preferredColorScheme(.light)
}

#Preview("App Shadows Dark") {
    AppShadowsPreview()
        .preferredColorScheme(.dark)
}
