import SwiftUI
import UserNotifications

struct PermissionsScreen: View {
    @Binding var notificationsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    let showsSkipButton: Bool
    let onSkip: () -> Void
    let onContinue: () -> Void

    static let stepIndex = 7

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()

    init(
        notificationsEnabled: Binding<Bool>,
        hapticsEnabled: Binding<Bool>,
        showsSkipButton: Bool = true,
        onSkip: @escaping () -> Void = {},
        onContinue: @escaping () -> Void = {}
    ) {
        _notificationsEnabled = notificationsEnabled
        _hapticsEnabled = hapticsEnabled
        self.showsSkipButton = showsSkipButton
        self.onSkip = onSkip
        self.onContinue = onContinue
    }

    var body: some View {
        OnboardingPageLayout(lottie: "LottiePermissions", lottieSize: 260) {
            VStack(spacing: AppSpacing.sm) {
                Text("A couple of\nquick things")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text("Tell Delayd how to keep you in check.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .staggeredAppear(delay: 0.05, trigger: appearToken)

            VStack(spacing: AppSpacing.md) {
                preferenceRow(
                    symbol: "bell.badge.fill",
                    title: "Notifications",
                    subtitle: "Get nudged when delays add up",
                    isOn: notificationToggleBinding
                )

                preferenceRow(
                    symbol: "waveform.path",
                    title: "Haptics",
                    subtitle: "Feel the impact",
                    isOn: $hapticsEnabled
                )
            }
            .staggeredAppear(delay: 0.16, trigger: appearToken)

            pageIndicator(current: Self.stepIndex, total: OnboardingViewModel.totalSteps)
                .padding(.top, AppSpacing.sm)
                .staggeredAppear(delay: 0.26, trigger: appearToken)

            PrimaryButton("Continue", action: onContinue)
                .staggeredAppear(delay: 0.32, trigger: appearToken)
        }
        .onAppear {
            if dragProgress.activeIndex == Self.stepIndex {
                appearToken = UUID()
            }
        }
        .onChange(of: dragProgress.activeIndex) { _, newValue in
            if newValue == Self.stepIndex {
                appearToken = UUID()
            }
        }
    }

    private var notificationToggleBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { newValue in
                if newValue {
                    Task { await requestNotificationPermissionAndPreview() }
                } else {
                    notificationsEnabled = false
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: [Self.previewNotificationId])
                }
            }
        )
    }

    @MainActor
    private func requestNotificationPermissionAndPreview() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notificationsEnabled = granted

        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Delayd"
        content.body = "Notifications are ready. Future spends will show their time cost."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.previewNotificationId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private static let previewNotificationId = "delayd.onboarding.preview-notification"

    private func preferenceRow(symbol: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        let isActive = isOn.wrappedValue

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(
                    isActive ? AnyShapeStyle(AppGradients.heroGradient) : AnyShapeStyle(AppColors.purplePrimary)
                )
                .frame(width: 56, height: 56)
                .background(
                    AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1),
                    in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(AppColors.purplePrimary.opacity(isActive ? 0.32 : 0.0), lineWidth: 1)
                )
                .scaleEffect(isActive ? 1.04 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.74), value: isActive)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer(minLength: AppSpacing.sm)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppColors.purplePrimary)
        }
        .padding(AppSpacing.md)
        .background(
            AppColors.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .stroke(
                    isActive ? AppColors.purplePrimary.opacity(0.35) : AppColors.border(for: colorScheme),
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.04), radius: 6, x: 0, y: 2)
    }
}

private struct PermissionsPreviewHost: View {
    @State private var notificationsEnabled = false
    @State private var hapticsEnabled = true

    var body: some View {
        PermissionsScreen(
            notificationsEnabled: $notificationsEnabled,
            hapticsEnabled: $hapticsEnabled
        )
    }
}

#Preview("Light") {
    PermissionsPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PermissionsPreviewHost()
        .preferredColorScheme(.dark)
}
