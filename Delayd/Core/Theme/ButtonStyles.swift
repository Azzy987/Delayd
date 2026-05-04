import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppGradients.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .scaleEffect(configuration.isPressed ? AppMotion.buttonPressScale : 1)
            .animation(AppMotion.pressFeedback, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? AppMotion.buttonPressScale : 1)
            .animation(AppMotion.pressFeedback, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .scaleEffect(configuration.isPressed ? AppMotion.buttonPressScale : 1)
            .animation(AppMotion.pressFeedback, value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColors.negative, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .scaleEffect(configuration.isPressed ? AppMotion.buttonPressScale : 1)
            .animation(AppMotion.pressFeedback, value: configuration.isPressed)
    }
}

struct FloatingActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let shadow = AppShadows.floatingButton(for: colorScheme)

        configuration.label
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(AppGradients.heroGradient, in: Circle())
            .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)
            .scaleEffect(configuration.isPressed ? AppMotion.floatingButtonPressScale : 1)
            .animation(AppMotion.pressFeedback, value: configuration.isPressed)
    }
}

private struct ButtonStylesPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Button Styles Light") {
    ButtonStylesPreview()
        .preferredColorScheme(.light)
}

#Preview("Button Styles Dark") {
    ButtonStylesPreview()
        .preferredColorScheme(.dark)
}
