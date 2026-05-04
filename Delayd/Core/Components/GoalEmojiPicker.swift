import SwiftUI

struct GoalEmojiPicker: View {
    @Binding var selectedCategory: GoalCategory

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.md) {
            ForEach(GoalCategory.pickerPresets) { category in
                Button {
                    selectedCategory = category
                } label: {
                    VStack(spacing: AppSpacing.sm) {
                        GoalCategoryIcon(
                            category: category,
                            size: 52,
                            style: selectedCategory == category ? .selected : .standard
                        )

                        Text(category.label)
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.textSecondaryLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension GoalEmojiPicker {
    static func mock() -> GoalEmojiPicker {
        GoalEmojiPicker(selectedCategory: .constant(.travel))
    }
}

private struct GoalEmojiPickerPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: GoalCategory = .travel

    var body: some View {
        GoalEmojiPicker(selectedCategory: $selectedCategory)
            .padding(AppSpacing.lg)
            .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    GoalEmojiPickerPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    GoalEmojiPicker(selectedCategory: .constant(.custom))
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    GoalEmojiPickerPreviewGroup()
        .preferredColorScheme(.dark)
}
