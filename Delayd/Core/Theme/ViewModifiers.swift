import SwiftUI

private struct PressFeedbackModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? AppMotion.buttonPressScale : 1)
            .animation(AppMotion.pressFeedback, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

private struct DelaydShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadow = AppShadows.card(for: colorScheme)

        content
            .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)
    }
}

private struct DelaydHeroShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadow = AppShadows.heroCard(for: colorScheme)

        content
            .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)
    }
}

private struct GradientTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.clear)
            .overlay {
                AppGradients.heroGradient
                    .mask(content)
            }
    }
}

private struct SoftBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.sm)
            .background(color, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

/// Springy slide-up + fade-in for content blocks. Re-fires when `trigger`
/// changes, so each new onboarding page replays the entrance.
private struct StaggeredAppearModifier: ViewModifier {
    let delay: Double
    let trigger: AnyHashable
    let yOffset: CGFloat
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : yOffset)
            .blur(radius: visible ? 0 : 4)
            .onAppear { schedule() }
            .onChange(of: trigger) { _, _ in
                visible = false
                schedule()
            }
    }

    private func schedule() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                visible = true
            }
        }
    }
}

extension View {
    @ViewBuilder
    func delaydPageSheet(detents: Set<PresentationDetent> = [.large]) -> some View {
        if #available(iOS 18.0, *) {
            self
                .presentationDetents(detents)
                .presentationSizing(.page)
                .presentationDragIndicator(.visible)
        } else {
            self
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
        }
    }

    func pressFeedback() -> some View {
        modifier(PressFeedbackModifier())
    }

    func delaydShadow() -> some View {
        modifier(DelaydShadowModifier())
    }

    func delaydHeroShadow() -> some View {
        modifier(DelaydHeroShadowModifier())
    }

    func gradientText() -> some View {
        modifier(GradientTextModifier())
    }

    func softBackground(color: Color) -> some View {
        modifier(SoftBackgroundModifier(color: color))
    }

    /// Replays a springy slide-up + fade entrance whenever `trigger` changes.
    /// Use with a per-screen identifier (e.g. the onboarding step index) to
    /// stagger title → subtitle → CTA reveals. Default `yOffset` is 16pt.
    func staggeredAppear(
        delay: Double = 0,
        trigger: AnyHashable,
        yOffset: CGFloat = 16
    ) -> some View {
        modifier(StaggeredAppearModifier(delay: delay, trigger: trigger, yOffset: yOffset))
    }
}

private struct ViewModifiersPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("7 days")
                .font(AppTypography.impactNumber)
                .gradientText()

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "sparkle")
                    .foregroundStyle(AppColors.purplePrimary)
                    .softBackground(color: AppColors.softPurpleBackground)

                Text("Press this row")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .delaydShadow()
            .pressFeedback()

            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(AppGradients.heroGradient)
                .frame(height: 96)
                .delaydHeroShadow()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("View Modifiers Light") {
    ViewModifiersPreview()
        .preferredColorScheme(.light)
}

#Preview("View Modifiers Dark") {
    ViewModifiersPreview()
        .preferredColorScheme(.dark)
}
