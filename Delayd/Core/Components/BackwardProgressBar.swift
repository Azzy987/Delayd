import SwiftUI

struct BackwardProgressBar: View {
    let currentProgress: CGFloat
    let previousProgress: CGFloat
    let accentColor: Color

    @State private var displayedProgress: CGFloat
    @State private var showGhostTrail = false

    init(currentProgress: CGFloat, previousProgress: CGFloat, accentColor: Color = AppColors.purplePrimary) {
        self.currentProgress = currentProgress
        self.previousProgress = previousProgress
        self.accentColor = accentColor
        _displayedProgress = State(initialValue: previousProgress)
    }

    var body: some View {
        GeometryReader { proxy in
            let previousWidth = LayoutGuard.dimension(proxy.size.width * clampedPrevious, name: "BackwardProgressBar.previousWidth")
            let trailWidth = LayoutGuard.dimension(proxy.size.width * (clampedPrevious - clampedCurrent), name: "BackwardProgressBar.trailWidth")
            let activeWidth = LayoutGuard.dimension(
                proxy.size.width * LayoutGuard.unit(displayedProgress, name: "BackwardProgressBar.displayedProgress"),
                name: "BackwardProgressBar.activeWidth"
            )
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accentColor.opacity(0.14))

                if showGhostTrail, clampedPrevious > clampedCurrent {
                    Capsule()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: previousWidth)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(AppColors.negative.opacity(0.30))
                                .frame(width: trailWidth)
                        }
                        .opacity(showGhostTrail ? 1 : 0)
                }

                Capsule()
                    .fill(accentColor)
                    .frame(width: activeWidth)
            }
        }
        .frame(height: 10)
        .onAppear {
            displayedProgress = clampedPrevious
            showGhostTrail = clampedPrevious > clampedCurrent

            withAnimation(clampedPrevious > clampedCurrent ? AppMotion.backwardProgress : AppMotion.forwardProgress) {
                displayedProgress = clampedCurrent
            }

            if clampedPrevious > clampedCurrent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(.easeOut(duration: 0.28)) {
                        showGhostTrail = false
                    }
                }
            }
        }
        .onChange(of: currentProgress) { _, newValue in
            let next = min(max(newValue, 0), 1)
            showGhostTrail = displayedProgress > next
            withAnimation(displayedProgress > next ? AppMotion.backwardProgress : AppMotion.forwardProgress) {
                displayedProgress = next
            }
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedCurrent * 100)) percent")
    }

    private var clampedCurrent: CGFloat {
        min(max(currentProgress, 0), 1)
    }

    private var clampedPrevious: CGFloat {
        min(max(previousProgress, 0), 1)
    }
}

extension BackwardProgressBar {
    static func mock() -> BackwardProgressBar {
        BackwardProgressBar(currentProgress: 0.42, previousProgress: 0.72, accentColor: AppColors.purplePrimary)
    }

    static func mockPositive() -> BackwardProgressBar {
        BackwardProgressBar(currentProgress: 0.68, previousProgress: 0.36, accentColor: AppColors.positive)
    }
}

private struct BackwardProgressBarPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var delayed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(delayed ? "Progress slipped" : "Current progress")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            BackwardProgressBar(
                currentProgress: delayed ? 0.38 : 0.72,
                previousProgress: delayed ? 0.72 : 0.38,
                accentColor: delayed ? AppColors.negative : AppColors.positive
            )

            Button(delayed ? "Reset" : "Show delay") {
                delayed.toggle()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    BackwardProgressBarPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    VStack(spacing: AppSpacing.xl) {
        BackwardProgressBar(currentProgress: 0.02, previousProgress: 0.98, accentColor: AppColors.negative)
        BackwardProgressBar(currentProgress: 1.2, previousProgress: -0.2, accentColor: AppColors.positive)
    }
    .padding(AppSpacing.lg)
    .background(AppColors.backgroundLight)
}

#Preview("Dark") {
    BackwardProgressBarPreviewGroup()
        .preferredColorScheme(.dark)
}
