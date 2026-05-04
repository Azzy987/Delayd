import SwiftUI

struct GoalCategoryColorPair {
    let backgroundColor: Color
    let accentColor: Color
}

enum GoalCategory: String, CaseIterable, Identifiable {
    case travel
    case vacation
    case tech
    case gaming
    case home
    case vehicle
    case education
    case wedding
    case emergency
    case savings
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .travel: "Travel"
        case .vacation: "Vacation"
        case .tech: "Tech"
        case .gaming: "Gaming"
        case .home: "Home"
        case .vehicle: "Vehicle"
        case .education: "Education"
        case .wedding: "Wedding"
        case .emergency: "Emergency"
        case .savings: "Savings"
        case .custom: "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .travel: "✈️"
        case .vacation: "🏖️"
        case .tech: "📱"
        case .gaming: "🎮"
        case .home: "🏠"
        case .vehicle: "🚗"
        case .education: "🎓"
        case .wedding: "💍"
        case .emergency: "⚡"
        case .savings: "💰"
        case .custom: "⭐"
        }
    }

    var backgroundColor: Color {
        colorPair.backgroundColor
    }

    var accentColor: Color {
        colorPair.accentColor
    }

    var colorPair: GoalCategoryColorPair {
        switch self {
        case .travel, .vacation:
            GoalCategoryColorPair(backgroundColor: AppColors.travelBackground, accentColor: AppColors.travelAccent)
        case .tech, .gaming:
            GoalCategoryColorPair(backgroundColor: AppColors.techBackground, accentColor: AppColors.techAccent)
        case .home:
            GoalCategoryColorPair(backgroundColor: AppColors.homeBackground, accentColor: AppColors.homeAccent)
        case .vehicle:
            GoalCategoryColorPair(backgroundColor: AppColors.vehicleBackground, accentColor: AppColors.vehicleAccent)
        case .education:
            GoalCategoryColorPair(backgroundColor: AppColors.educationBackground, accentColor: AppColors.educationAccent)
        case .wedding:
            GoalCategoryColorPair(backgroundColor: AppColors.weddingBackground, accentColor: AppColors.weddingAccent)
        case .emergency:
            GoalCategoryColorPair(backgroundColor: AppColors.emergencyBackground, accentColor: AppColors.emergencyAccent)
        case .savings:
            GoalCategoryColorPair(backgroundColor: AppColors.savingsBackground, accentColor: AppColors.savingsAccent)
        case .custom:
            GoalCategoryColorPair(backgroundColor: AppColors.customBackground, accentColor: AppColors.customAccent)
        }
    }

    static let colorGroups: [GoalCategory] = [
        .travel,
        .tech,
        .home,
        .vehicle,
        .education,
        .wedding,
        .emergency,
        .savings,
        .custom
    ]

    static let pickerPresets: [GoalCategory] = [
        .vacation,
        .tech,
        .gaming,
        .home,
        .vehicle,
        .education,
        .travel,
        .wedding,
        .emergency,
        .savings,
        .custom
    ]
}

private struct GoalCategoryColorsPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
            ForEach(GoalCategory.pickerPresets) { category in
                VStack(spacing: AppSpacing.sm) {
                    Text(category.emoji)
                        .font(.system(size: 28))
                        .frame(width: 56, height: 56)
                        .background(category.backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(category.accentColor.opacity(0.4), lineWidth: 1)
                        }

                    Text(category.label)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Goal Categories Light") {
    GoalCategoryColorsPreview()
        .preferredColorScheme(.light)
}

#Preview("Goal Categories Dark") {
    GoalCategoryColorsPreview()
        .preferredColorScheme(.dark)
}
