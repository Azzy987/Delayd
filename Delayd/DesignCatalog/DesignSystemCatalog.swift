import SwiftUI

struct DesignSystemCatalog: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    ColorCatalogSection()
                    GradientCatalogSection()
                    TypographyCatalogSection()
                    SpacingCatalogSection()
                    RadiusCatalogSection()
                    ShadowCatalogSection()
                    MotionCatalogSection()
                    ButtonCatalogSection()
                    CardCatalogSection()
                    ComponentCatalogSection()
                    GoalCategoryCatalogSection()
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background(for: colorScheme))
            .navigationTitle("Design System")
        }
    }
}

private struct CatalogGroup<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
            }

            content
        }
        .delaydSection()
    }
}

// MARK: - Colors

private struct ColorCatalogSection: View {
    private let backgroundColors: [(String, Color)] = [
        ("Light bg", AppColors.backgroundLight),
        ("Surface", AppColors.surfaceLight),
        ("Dark bg", AppColors.backgroundDark),
        ("Dark surface", AppColors.surfaceDark)
    ]

    private let textColors: [(String, Color)] = [
        ("Primary light", AppColors.textPrimaryLight),
        ("Secondary light", AppColors.textSecondaryLight),
        ("Tertiary light", AppColors.textTertiaryLight),
        ("Primary dark", AppColors.textPrimaryDark),
        ("Secondary dark", AppColors.textSecondaryDark),
        ("Tertiary dark", AppColors.textTertiaryDark)
    ]

    private let accentColors: [(String, Color)] = [
        ("Purple", AppColors.purplePrimary),
        ("Hero start", AppColors.heroGradientStart),
        ("Hero end", AppColors.heroGradientEnd),
        ("Soft purple", AppColors.softPurpleBackground)
    ]

    private let functionalColors: [(String, Color)] = [
        ("Positive", AppColors.positive),
        ("Warning", AppColors.warning),
        ("Negative", AppColors.negative),
        ("Positive bg", AppColors.softPositiveBackground),
        ("Warning bg", AppColors.softWarningBackground),
        ("Negative bg", AppColors.softNegativeBackground)
    ]

    var body: some View {
        CatalogGroup(title: "Colors", subtitle: "Locked tokens only") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ColorSwatchGrid(title: "Backgrounds", colors: backgroundColors)
                ColorSwatchGrid(title: "Text", colors: textColors)
                ColorSwatchGrid(title: "Accent", colors: accentColors)
                ColorSwatchGrid(title: "Functional", colors: functionalColors)
            }
        }
    }
}

private struct ColorSwatchGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let colors: [(String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(color)
                            .frame(height: 56)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                            }

                        Text(name)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

// MARK: - Gradients

private struct GradientCatalogSection: View {
    var body: some View {
        CatalogGroup(title: "Gradients", subtitle: "Purple is reserved for hero and decisive moments") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(AppGradients.heroGradient)
                    .frame(height: 140)
                    .delaydHeroShadow()
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Hero gradient")
                                .font(AppTypography.sectionHeader)
                            Text("#8B6FFF → #6B47E0")
                                .font(AppTypography.bodyMedium)
                                .opacity(0.72)
                        }
                        .foregroundStyle(.white)
                        .padding(AppSpacing.heroCardPadding)
                    }

                Text("Gradient text")
                    .font(AppTypography.impactNumber)
                    .gradientText()
            }
        }
    }
}

// MARK: - Typography

private struct TypographyCatalogSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CatalogGroup(title: "Typography", subtitle: "System SF styles with Dynamic Type") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                TypeSample(name: "Impact number", sample: "48 days", font: AppTypography.impactNumber, color: AppColors.purplePrimary)
                TypeSample(name: "Goal number", sample: "₹42,000", font: AppTypography.goalNumber, color: AppColors.textPrimary(for: colorScheme))
                TypeSample(name: "Section header", sample: "Recent impacts", font: AppTypography.sectionHeader, color: AppColors.textPrimary(for: colorScheme))
                TypeSample(name: "Title", sample: "Bali trip", font: AppTypography.title, color: AppColors.textPrimary(for: colorScheme))
                TypeSample(name: "Body", sample: "Every expense moves the goal date.", font: AppTypography.body, color: AppColors.textPrimary(for: colorScheme))
                TypeSample(name: "Callout", sample: "Delayed by 2 days", font: AppTypography.callout, color: AppColors.textSecondary(for: colorScheme))
                TypeSample(name: "Caption", sample: "On pace", font: AppTypography.captionMedium, color: AppColors.textTertiary(for: colorScheme))
            }
            .delaydCard()
        }
    }
}

private struct TypeSample: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let sample: String
    let font: Font
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(sample)
                .font(font)
                .foregroundStyle(color)
                .minimumScaleFactor(0.8)

            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
    }
}

// MARK: - Spacing

private struct SpacingCatalogSection: View {
    private let rows: [(String, CGFloat)] = [
        ("xs", AppSpacing.xs),
        ("sm", AppSpacing.sm),
        ("md", AppSpacing.md),
        ("lg", AppSpacing.lg),
        ("xl", AppSpacing.xl),
        ("xxl", AppSpacing.xxl)
    ]

    var body: some View {
        CatalogGroup(title: "Spacing", subtitle: "Generous, quiet rhythm") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(rows, id: \.0) { name, value in
                    SpacingRow(name: name, value: value)
                }
            }
            .delaydCard()
        }
    }
}

private struct SpacingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let value: CGFloat

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(name)
                .font(.body.monospaced())
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .frame(width: 44, alignment: .leading)

            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(AppColors.purplePrimary)
                .frame(width: value, height: 16)

            Text("\(Int(value))pt")
                .font(.caption.monospaced())
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
    }
}

// MARK: - Radius

private struct RadiusCatalogSection: View {
    private let rows: [(String, CGFloat)] = [
        ("sm", AppRadius.sm),
        ("md", AppRadius.md),
        ("lg", AppRadius.lg),
        ("xl", AppRadius.xl),
        ("pill", AppRadius.pill)
    ]

    var body: some View {
        CatalogGroup(title: "Radius", subtitle: "Rounded but controlled") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                ForEach(rows, id: \.0) { name, radius in
                    RadiusSample(name: name, radius: radius)
                }
            }
        }
    }
}

private struct RadiusSample: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let radius: CGFloat

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: radius)
                .fill(AppColors.surface(for: colorScheme))
                .frame(height: 72)
                .overlay {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                }
                .delaydShadow()

            Text("\(name) • \(Int(radius))")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
    }
}

// MARK: - Shadows

private struct ShadowCatalogSection: View {
    var body: some View {
        CatalogGroup(title: "Shadows", subtitle: "Soft elevation, never neumorphic") {
            VStack(spacing: AppSpacing.lg) {
                ShadowSample(title: "Card shadow", subtitle: "black @ 6%, y:4, blur:16", style: .card)
                ShadowSample(title: "Hero card shadow", subtitle: "purple @ 12%, y:8, blur:24", style: .hero)
                ShadowSample(title: "Floating button shadow", subtitle: "purple @ 30%, y:8, blur:20", style: .floating)
            }
        }
    }
}

private enum ShadowSampleStyle {
    case card
    case hero
    case floating
}

private struct ShadowSample: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let style: ShadowSampleStyle

    var body: some View {
        let shadow = shadowToken

        HStack(spacing: AppSpacing.md) {
            ZStack {
                if style == .floating {
                    Circle()
                        .fill(AppGradients.heroGradient)
                } else {
                    RoundedRectangle(cornerRadius: style == .hero ? AppRadius.xl : AppRadius.lg)
                        .fill(style == .hero ? AnyShapeStyle(AppGradients.heroGradient) : AnyShapeStyle(AppColors.surface(for: colorScheme)))
                }
            }
            .frame(width: 72, height: 72)
            .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .delaydCard()
    }

    private var shadowToken: AppShadowToken {
        switch style {
        case .card: AppShadows.card(for: colorScheme)
        case .hero: AppShadows.heroCard(for: colorScheme)
        case .floating: AppShadows.floatingButton(for: colorScheme)
        }
    }
}

// MARK: - Motion

private struct MotionCatalogSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var progress: CGFloat = 0.76
    @State private var delayed = false

    var body: some View {
        CatalogGroup(title: "Motion", subtitle: "Forward is quick; delay moves slower") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(delayed ? "Backward progress" : "Forward progress")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.softPurpleBackground)
                            Capsule()
                                .fill(delayed ? AppColors.negative : AppColors.positive)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 12)

                    Text(delayed ? "Delay impact uses 600ms ease-in-out." : "Positive movement uses 280ms ease-out.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }

                Button(delayed ? "Recover progress" : "Show delay") {
                    delayed.toggle()
                    withAnimation(delayed ? AppMotion.backwardProgress : AppMotion.forwardProgress) {
                        progress = delayed ? 0.42 : 0.76
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .delaydCard()
        }
    }
}

// MARK: - Buttons

private struct ButtonCatalogSection: View {
    var body: some View {
        CatalogGroup(title: "Buttons", subtitle: "Standard actions with restrained press feedback") {
            VStack(spacing: AppSpacing.md) {
                Button("Protect dream") {
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Review impact") {
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Maybe later") {
                }
                .buttonStyle(GhostButtonStyle())

                Button("Delete impact") {
                }
                .buttonStyle(DestructiveButtonStyle())

                Button {
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(FloatingActionButtonStyle())
            }
        }
    }
}

// MARK: - Cards

private struct CardCatalogSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CatalogGroup(title: "Cards", subtitle: "Floating cards, hero cards, and insight banners") {
            VStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Bali trip")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Text("₹500 delayed this dream by 2 days")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .delaydCard()

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("₹42,000")
                        .font(AppTypography.goalNumber)
                    Text("of ₹1,20,000 saved")
                        .font(AppTypography.bodyMedium)
                        .opacity(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .delaydHeroCard()

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sparkle")
                        .foregroundStyle(AppColors.insightBannerAccent)
                    Text("Skipping this 4x/month puts Bali 8 days closer")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .opacity(0.7)
                }
                .delaydInsightBanner()
            }
        }
    }
}

// MARK: - Components

private struct ComponentCatalogSection: View {
    @State private var selectedCategory: GoalCategory = .vacation

    var body: some View {
        CatalogGroup(title: "Components", subtitle: "Reusable Delayd building blocks") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ComponentExample(title: "BrandLogoView") {
                    HStack(spacing: AppSpacing.lg) {
                        BrandLogoView(size: .small)
                        BrandLogoView(size: .medium)
                        BrandLogoView(size: .large)
                    }
                }

                ComponentExample(title: "GoalCategoryIcon") {
                    HStack(spacing: AppSpacing.md) {
                        GoalCategoryIcon(category: .travel)
                        GoalCategoryIcon(category: .education)
                        GoalCategoryIcon(category: .savings)
                        GoalCategoryIcon(category: .custom, style: .selected)
                    }
                }

                ComponentExample(title: "GoalHeroCard") {
                    GoalHeroCard.mockOnPace()
                }

                ComponentExample(title: "GoalCard") {
                    GoalCard.mockBehindSchedule()
                }

                ComponentExample(title: "DelayedImpactCard") {
                    DelayedImpactCard.mock()
                }

                ComponentExample(title: "ExpenseRow") {
                    VStack(spacing: AppSpacing.md) {
                        ExpenseRow.mock()
                        Divider()
                        ExpenseRow(category: .savings, merchantName: "Movie night", goalName: "Emergency fund", delayText: "6 hours", amountText: "-₹249")
                    }
                    .delaydCard()
                }

                ComponentExample(title: "SmartInsightCard") {
                    SmartInsightCard.mock()
                }

                ComponentExample(title: "BackwardProgressBar") {
                    BackwardProgressBar.mock()
                }

                ComponentExample(title: "ValueDeltaChip") {
                    HStack(spacing: AppSpacing.sm) {
                        ValueDeltaChip.mock()
                        ValueDeltaChip.mockNegative()
                        ValueDeltaChip("On pace")
                    }
                }

                ComponentExample(title: "TagChip") {
                    HStack(spacing: AppSpacing.sm) {
                        TagChip("Vacation", variant: .purple)
                        TagChip("Behind", variant: .warning)
                        TagChip("On pace", variant: .positive)
                    }
                }

                ComponentExample(title: "EmptyStateCard") {
                    EmptyStateCard.mockNoExpenses()
                }

                ComponentExample(title: "SectionHeader") {
                    SectionHeader.mock()
                        .delaydCard()
                }

                ComponentExample(title: "GoalEmojiPicker") {
                    GoalEmojiPicker(selectedCategory: $selectedCategory)
                        .delaydCard()
                }

                ComponentExample(title: "PrimaryButton / SecondaryButton / FloatingActionButton") {
                    VStack(spacing: AppSpacing.md) {
                        PrimaryButton.mock()
                        SecondaryButton.mock()
                        FloatingActionButton.mock()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct ComponentExample<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            content
        }
    }
}

// MARK: - Goal Categories

private struct GoalCategoryCatalogSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CatalogGroup(title: "Goal Category Colors", subtitle: "Nine locked color groups; Vacation and Gaming reuse Travel and Tech") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                ForEach(GoalCategory.colorGroups) { category in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(category.emoji)
                                .font(.system(size: 24))
                                .frame(width: 48, height: 48)
                                .background(category.backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.md))

                            Circle()
                                .fill(category.accentColor)
                                .frame(width: 16, height: 16)
                        }

                        Text(category.label)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .delaydCard()
                }
            }
        }
    }
}

#Preview("Light") {
    DesignSystemCatalog()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignSystemCatalog()
        .preferredColorScheme(.dark)
}
