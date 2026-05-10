import SwiftUI

/// A larger, illustration-based goal category picker that replaces the
/// small emoji grid. Each category shows a scenic illustration on a
/// colored background with a label beneath it.
///
/// Used in both onboarding (ChooseDreamScreen) and the CreateGoalSheet.
struct GoalCategoryIllustrationPicker: View {
    enum Style {
        /// Original look — colored rounded-square tile behind each illustration.
        case tile
        /// Onboarding look — raw illustration on a transparent background, no
        /// colored container, with a soft selection halo.
        case bare
        /// Onboarding dream choice — soft card with the 3D icon breaking out
        /// above the container and the label anchored inside the card.
        case raisedCard
    }

    @Binding var selectedCategory: GoalCategory?
    var imageSize: CGFloat = 80
    var style: Style = .tile
    var columnCount: Int = 3
    var rowSpacing: CGFloat = AppSpacing.md
    var columnSpacing: CGFloat = AppSpacing.sm
    var categories: [GoalCategory] = GoalCategory.pickerPresets

    @Environment(\.colorScheme) private var colorScheme

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: columnSpacing),
            count: columnCount
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(categories) { category in
                Button {
                    withAnimation(AppMotion.forwardProgress) {
                        selectedCategory = category
                    }
                } label: {
                    categoryCell(category)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func categoryCell(_ category: GoalCategory) -> some View {
        let isSelected = selectedCategory == category

        Group {
            switch style {
            case .raisedCard:
                raisedCardCell(category, isSelected: isSelected)
            case .tile, .bare:
                VStack(spacing: AppSpacing.xs) {
                    illustration(for: category, isSelected: isSelected)

                    Text(category.label)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(
                            isSelected
                                ? AppColors.purplePrimary
                                : AppColors.textSecondary(for: colorScheme)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func illustration(for category: GoalCategory, isSelected: Bool) -> some View {
        switch style {
        case .tile:
            Image(category.illustrationAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: imageSize, height: imageSize)
                .colorMultiply(category.backgroundColor)
                .background(category.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: imageSize * 0.26))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: imageSize * 0.26)
                            .stroke(AppColors.purplePrimary, lineWidth: 3)
                    }
                }
                .scaleEffect(isSelected ? 1.06 : 1)
                .animation(AppMotion.forwardProgress, value: isSelected)
                .shadow(
                    color: isSelected
                        ? AppColors.purplePrimary.opacity(0.25)
                        : .black.opacity(0.06),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )

        case .bare:
            // 3D transparent illustrations — no clip shape so the full
            // artwork renders. Soft purple halo signals selection.
            Image(category.illustrationAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .background {
                    RoundedRectangle(cornerRadius: imageSize * 0.22, style: .continuous)
                        .fill(AppColors.purplePrimary.opacity(isSelected ? 0.14 : 0))
                        .frame(width: imageSize * 1.08, height: imageSize * 1.08)
                        .blur(radius: 6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: imageSize * 0.22, style: .continuous)
                        .stroke(AppColors.purplePrimary, lineWidth: isSelected ? 2.5 : 0)
                        .frame(width: imageSize * 1.04, height: imageSize * 1.04)
                }
                .scaleEffect(isSelected ? 1.06 : 1)
                .animation(.spring(response: 0.36, dampingFraction: 0.72), value: isSelected)
                .shadow(
                    color: isSelected
                        ? AppColors.purplePrimary.opacity(0.25)
                        : .black.opacity(0.06),
                    radius: isSelected ? 8 : 3,
                    x: 0,
                    y: isSelected ? 4 : 1
                )
        case .raisedCard:
            EmptyView()
        }
    }

    private func raisedCardCell(_ category: GoalCategory, isSelected: Bool) -> some View {
        let cardHeight = imageSize * 0.94
        let totalHeight = imageSize * 1.38
        let cardOffset = imageSize * 0.36
        let cornerRadius = AppRadius.xl

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(raisedCardFill(isSelected: isSelected))
                .frame(height: cardHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            isSelected
                                ? AppColors.purplePrimary.opacity(0.72)
                                : AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.22 : 0.10),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.26 : 0.22)
                        : .black.opacity(colorScheme == .dark ? 0.18 : 0.06),
                    radius: isSelected ? 14 : 8,
                    x: 0,
                    y: isSelected ? 8 : 4
                )
                .offset(y: cardOffset)

            Image(category.illustrationAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .offset(y: isSelected ? -8 : -2)
                .scaleEffect(isSelected ? 1.05 : 1)

            Text(category.label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? AppColors.purplePrimary : AppColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, AppSpacing.xs)
                .frame(maxWidth: .infinity)
                .offset(y: imageSize * 1.06)
        }
        .frame(height: totalHeight)
        .animation(.spring(response: 0.36, dampingFraction: 0.74), value: isSelected)
    }

    private func raisedCardFill(isSelected: Bool) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    AppColors.surfaceDark,
                    AppColors.purplePrimary.opacity(isSelected ? 0.38 : 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                AppColors.softPurpleBackground.opacity(isSelected ? 1.0 : 0.76),
                AppColors.surfaceLight
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Same picker but using a non-optional binding for CreateGoalSheet.
struct GoalCategoryIllustrationPickerRequired: View {
    @Binding var selectedCategory: GoalCategory
    var imageSize: CGFloat = 80

    var body: some View {
        GoalCategoryIllustrationPicker(
            selectedCategory: Binding(
                get: { selectedCategory },
                set: { if let cat = $0 { selectedCategory = cat } }
            ),
            imageSize: imageSize
        )
    }
}

// MARK: - GoalCategory illustration asset name

extension GoalCategory {
    /// The asset catalog name for this category's circular illustration.
    nonisolated var illustrationAssetName: String {
        switch self {
        case .travel: "CategoryTravel"
        case .vacation: "CategoryVacation"
        case .tech: "CategoryTech"
        case .gaming: "CategoryGaming"
        case .home: "CategoryHome"
        case .vehicle: "CategoryVehicle"
        case .education: "CategoryEducation"
        case .wedding: "CategoryWedding"
        case .emergency: "CategoryEmergency"
        case .savings: "CategorySavings"
        case .custom: "CategoryCustom"
        }
    }
}

// MARK: - Previews

private struct PickerPreviewHost: View {
    @State private var selected: GoalCategory? = .travel

    var body: some View {
        ScrollView {
            GoalCategoryIllustrationPicker(selectedCategory: $selected)
                .padding(AppSpacing.lg)
        }
        .background(AppColors.backgroundLight)
    }
}

#Preview("Light") {
    PickerPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PickerPreviewHost()
        .preferredColorScheme(.dark)
}
