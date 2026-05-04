import SwiftUI

struct GoalCategoryIcon: View {
    let category: GoalCategory
    let size: CGFloat
    let style: Style

    init(category: GoalCategory, size: CGFloat = 44, style: Style = .standard) {
        self.category = category
        self.size = size
        self.style = style
    }

    var body: some View {
        Image(category.illustrationAssetName)
            .resizable()
            .scaledToFit()
            .padding(imagePadding)
            .frame(width: size, height: size)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if style == .selected {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppColors.purplePrimary, lineWidth: 2)
                }
            }
            .accessibilityLabel(category.label)
    }

    private var backgroundColor: Color {
        switch style {
        case .standard, .selected:
            category.backgroundColor
        case .hero:
            .white.opacity(0.18)
        }
    }

    private var imagePadding: CGFloat {
        switch style {
        case .hero:
            max(4, size * 0.14)
        case .standard, .selected:
            max(3, size * 0.10)
        }
    }

    private var cornerRadius: CGFloat {
        size <= 36 ? AppRadius.md : AppRadius.md
    }
}

extension GoalCategoryIcon {
    enum Style: Equatable {
        case standard
        case hero
        case selected
    }
}

private struct GoalCategoryIconPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
            ForEach(GoalCategory.pickerPresets) { category in
                VStack(spacing: AppSpacing.sm) {
                    GoalCategoryIcon(category: category)
                    Text(category.label)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    GoalCategoryIconPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    HStack(spacing: AppSpacing.lg) {
        GoalCategoryIcon(category: .travel, size: 36)
        GoalCategoryIcon(category: .education, style: .selected)
        GoalCategoryIcon(category: .savings, size: 64)
        GoalCategoryIcon(category: .custom, style: .hero)
            .background(AppGradients.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }
    .padding(AppSpacing.xl)
    .background(AppColors.backgroundLight)
}

#Preview("Dark") {
    GoalCategoryIconPreviewGroup()
        .preferredColorScheme(.dark)
}
