import SwiftUI

struct ValueDeltaChip: View {
    let text: String
    let systemImage: String?

    @Environment(\.colorScheme) private var colorScheme

    init(_ text: String, systemImage: String? = nil) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }

            Text(text)
                .font(AppTypography.captionMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(backgroundColor, in: Capsule())
        .accessibilityLabel(text)
    }

    private var tone: Tone {
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("-") {
            .negative
        } else if text.trimmingCharacters(in: .whitespaces).hasPrefix("+") {
            .positive
        } else {
            .neutral
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .positive: AppColors.positive
        case .negative: AppColors.negative
        case .neutral: AppColors.textSecondary(for: colorScheme)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .positive: AppColors.softPositiveBackground
        case .negative: AppColors.softNegativeBackground
        case .neutral: AppColors.border(for: colorScheme)
        }
    }

    private enum Tone {
        case positive
        case negative
        case neutral
    }
}

extension ValueDeltaChip {
    static func mock() -> ValueDeltaChip {
        ValueDeltaChip("+₹200", systemImage: "arrow.up")
    }

    static func mockNegative() -> ValueDeltaChip {
        ValueDeltaChip("-2 days", systemImage: "arrow.down")
    }
}

private struct ValueDeltaChipPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ValueDeltaChip.mock()
            ValueDeltaChip.mockNegative()
            ValueDeltaChip("+5%")
            ValueDeltaChip("On pace")
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    ValueDeltaChipPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    ValueDeltaChip("-123 days moved away", systemImage: "arrow.down")
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    ValueDeltaChipPreviewGroup()
        .preferredColorScheme(.dark)
}
