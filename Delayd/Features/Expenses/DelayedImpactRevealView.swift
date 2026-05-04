import SwiftUI
import SwiftData

struct DelayedImpactRevealView: View {
    @State private var viewModel: DelayedImpactRevealViewModel

    let onDismiss: () -> Void
    let onUndo: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @ScaledMetric(relativeTo: .largeTitle) private var amountFontSize: CGFloat = 56
    @ScaledMetric(relativeTo: .largeTitle) private var delayFontSize: CGFloat = 48

    @MainActor
    init(
        viewModel: DelayedImpactRevealViewModel? = nil,
        impact: DelayImpact? = nil,
        onDismiss: @escaping () -> Void = {},
        onUndo: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel ?? DelayedImpactRevealViewModel(impact: impact ?? .mockMedium))
        self.onDismiss = onDismiss
        self.onUndo = onUndo
    }

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            AppGradients.heroGradient
                .opacity(viewModel.showBackground ? 0.08 : 0)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    amountSection
                        .padding(.top, 80)

                    impactLine
                        .padding(.top, AppSpacing.md)

                    delaySection
                        .padding(.top, AppSpacing.lg)

                    progressSection
                        .padding(.top, AppSpacing.xxl)
                }

                Spacer(minLength: AppSpacing.lg)

                suggestionCard
                    .padding(.bottom, AppSpacing.lg)

                actionSection
                    .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .task {
            await viewModel.startReveal(modelContainer: modelContext.container)
        }
        .accessibilityElement(children: .contain)
    }

    private var amountSection: some View {
        Text(viewModel.amountText)
            .font(.system(size: amountFontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.54)
            .opacity(viewModel.showAmount ? 1 : 0)
            .offset(y: viewModel.showAmount ? 0 : 12)
    }

    private var impactLine: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(viewModel.impactLeadText)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Text(viewModel.impact.affectedGoal.name.delaydGoalTitleCased)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.76)

            Text("by")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .padding(.top, AppSpacing.lg)
        }
        .opacity(viewModel.showImpactLine ? 1 : 0)
        .offset(y: viewModel.showImpactLine ? 0 : 8)
    }

    private var delaySection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(viewModel.delayText)
                .font(.system(size: delayFontSize, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .gradientText()

            if let timelineShiftText = viewModel.timelineShiftText {
                Text(timelineShiftText)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
        .opacity(viewModel.showDays ? 1 : 0)
        .offset(y: viewModel.showDays ? 0 : 8)
    }

    private var progressSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Group {
                if viewModel.showProgress {
                    if viewModel.hasProgressMovement {
                        BackwardProgressBar(
                            currentProgress: CGFloat(viewModel.impact.newProgress),
                            previousProgress: CGFloat(viewModel.impact.previousProgress),
                            accentColor: AppColors.negative
                        )
                    } else {
                        DelayImpactMeter(
                            progress: CGFloat(viewModel.delayMeterProgress),
                            accentColor: AppColors.negative
                        )
                    }
                } else {
                    Capsule()
                        .fill(AppColors.negative.opacity(0.14))
                        .frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity)

            Text(viewModel.amountShiftText)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .opacity(viewModel.showProgress ? 1 : 0)
    }

    private var suggestionCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.softPurpleBackground, in: Circle())

            Text(viewModel.toneMessage)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.18 : 1), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .opacity(viewModel.showSuggestion ? 1 : 0)
        .offset(y: viewModel.showSuggestion ? 0 : 8)
    }

    private var actionSection: some View {
        VStack(spacing: AppSpacing.sm) {
            PrimaryButton("Got it", action: onDismiss)

            if viewModel.isUndoVisible {
                Button {
                    onUndo()
                } label: {
                    Text("Undo (\(viewModel.undoCountdown)s)")
                        .frame(maxWidth: 180)
                }
                .buttonStyle(GhostButtonStyle())
                .transition(.opacity)
            }
        }
        .opacity(viewModel.showActions ? 1 : 0)
        .offset(y: viewModel.showActions ? 0 : 8)
    }
}

private struct DelayImpactMeter: View {
    let progress: CGFloat
    let accentColor: Color

    @State private var displayedProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accentColor.opacity(0.14))

                Capsule()
                    .fill(accentColor)
                    .frame(width: proxy.size.width * min(max(displayedProgress, 0), 1))
            }
        }
        .frame(height: 10)
        .onAppear {
            displayedProgress = 0
            withAnimation(AppMotion.backwardProgress) {
                displayedProgress = progress
            }
        }
    }
}

#Preview("Small - ₹150") {
    DelayedImpactRevealView(impact: .mockSmall)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Medium - ₹500") {
    DelayedImpactRevealView(impact: .mockMedium)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Large - ₹2,500") {
    DelayedImpactRevealView(impact: .mockLarge)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Emergency - ₹50,000") {
    DelayedImpactRevealView(impact: .mockEmergency)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Dark - ₹500") {
    DelayedImpactRevealView(impact: .mockMedium)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
