import Combine
import RevenueCat
import SwiftUI

struct DelaydProView: View {
    enum Plan: Hashable {
        case lifetime
        case yearly
        case monthly
    }

    enum EntryPoint {
        case settings
        case postReveal

        var title: String {
            switch self {
            case .settings: "Delayd Pro"
            case .postReveal: "Commit to protecting your dream"
            }
        }

        var subtitle: String {
            switch self {
            case .settings:
                "Unlock deeper dream-protection tools built around delay, not budgets."
            case .postReveal:
                "You felt the time cost. Pro helps you catch those small slips before they become weeks."
            }
        }

        var buttonTitle: String {
            switch self {
            case .settings: "Subscribe Now"
            case .postReveal: "Protect My Dream"
            }
        }
    }

    var entryPoint: EntryPoint = .settings
    var onClose: (() -> Void)?
    var onSubscribe: ((Plan) -> Void)?
    var onRestore: (() -> Void)?

    @State private var selectedPlan: Plan = .lifetime
    @State private var showMore = false
    @State private var remaining: TimeInterval = (19 * 3600) + (2 * 60) + 40
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?

    @Environment(\.colorScheme) private var colorScheme

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let primaryFeatures: [ProFeature] = [
        ProFeature(emoji: "🎯", title: "Unlimited active dreams", tint: Color(red: 0.49, green: 0.36, blue: 0.99), background: Color(red: 0.93, green: 0.91, blue: 1.0)),
        ProFeature(emoji: "🧠", title: "Delay coach for tiny spends", tint: Color(red: 0.35, green: 0.55, blue: 1.0), background: Color(red: 0.88, green: 0.92, blue: 1.0)),
        ProFeature(emoji: "🔔", title: "Smart delay reminders", tint: Color(red: 0.95, green: 0.6, blue: 0.2), background: Color(red: 1.0, green: 0.93, blue: 0.83)),
        ProFeature(emoji: "📅", title: "Weekly dream-protection recap", tint: Color(red: 0.18, green: 0.72, blue: 0.49), background: Color(red: 0.88, green: 0.96, blue: 0.91)),
        ProFeature(emoji: "🛡️", title: "Hard-mode commitment prompts", tint: Color(red: 0.85, green: 0.3, blue: 0.35), background: Color(red: 1.0, green: 0.88, blue: 0.89))
    ]

    private let extraFeatures: [ProFeature] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    header
                        .padding(.top, AppSpacing.md)

                    sparkleIcon
                        .padding(.top, AppSpacing.sm)

                    VStack(spacing: AppSpacing.xs) {
                        Text(entryPoint.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                            .multilineTextAlignment(.center)

                        Text(entryPoint.subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AppSpacing.md)
                    }

                    featureList
                        .padding(.horizontal, AppSpacing.lg)

                    Color.clear.frame(height: 360)
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            purchasePanel
        }
        .onReceive(timer) { _ in
            if remaining > 0 { remaining -= 1 }
        }
        .task {
            await ProEntitlementService.refreshCustomerInfo()
        }
        .onDisappear {
            Task {
                await ProEntitlementService.refreshCustomerInfo()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Delayd Pro")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.purplePrimary)
            Spacer()
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(AppColors.card(for: colorScheme), in: Circle())
                    .overlay(Circle().stroke(AppColors.border(for: colorScheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Sparkle icon

    private var sparkleIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.purplePrimary.opacity(0.18))
                .frame(width: 108, height: 108)
                .blur(radius: 20)

            Image("PaywallHero")
                .resizable()
                .scaledToFit()
                .frame(width: 126, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                .shadow(
                    color: AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.12 : 0.16),
                    radius: 18,
                    x: 0,
                    y: 10
                )
        }
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(visibleFeatures) { feature in
                featureRow(feature, dimmed: false)
            }

            if let previewFeature {
                featureRow(previewFeature, dimmed: true)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showMore.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Text(showMore ? "Show less" : "Show benefits")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: showMore ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppColors.purplePrimary)
                .padding(.top, AppSpacing.xs)
            }
            .buttonStyle(.plain)
        }
    }

    private var visibleFeatures: [ProFeature] {
        showMore ? primaryFeatures + extraFeatures : Array(primaryFeatures.prefix(4))
    }

    private var previewFeature: ProFeature? {
        showMore ? nil : primaryFeatures.dropFirst(4).first
    }

    private func featureRow(_ feature: ProFeature, dimmed: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(feature.background)
                    .frame(width: 32, height: 32)
                Text(feature.emoji)
                    .font(.system(size: 16))
            }
            .opacity(dimmed ? 0.45 : 1)

            Text(feature.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(dimmed ? AppColors.textTertiary(for: colorScheme) : AppColors.textPrimary(for: colorScheme))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Plan cards

    private var purchasePanel: some View {
        VStack(spacing: AppSpacing.sm) {
            planCards
            subscribeButton
            continueFreeButton
                .padding(.top, -2)
            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.negative)
                    .multilineTextAlignment(.center)
            }
            footerLinks
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background {
            AppColors.softSurface(for: colorScheme)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 16, x: 0, y: -6)
        }
    }

    private var planCards: some View {
        VStack(spacing: AppSpacing.sm) {
            lifetimeCard
            monthlyCard
        }
    }

    private var lifetimeCard: some View {
        let isSelected = selectedPlan == .lifetime

        return Button(action: { selectedPlan = .lifetime }) {
            HStack(alignment: .top, spacing: 14) {
                radio(isSelected: isSelected)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Lifetime")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                        Text(countdownText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.negative, in: Capsule())

                        Spacer(minLength: 0)
                    }

                    Text("One-time founding price")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }

                VStack(alignment: .trailing, spacing: 6) {
                    Text("$29.99")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Text("Founding")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.textPrimary(for: colorScheme), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppColors.purplePrimary : AppColors.border(for: colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var monthlyCard: some View {
        let isSelected = selectedPlan == .monthly

        return Button(action: { selectedPlan = .monthly }) {
            HStack(spacing: 14) {
                radio(isSelected: isSelected)

                Text("Monthly")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Spacer()

                Text("$3.99 ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                + Text("/Month")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppColors.purplePrimary : AppColors.border(for: colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func radio(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? AppColors.purplePrimary : AppColors.textTertiary(for: colorScheme), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(AppColors.purplePrimary)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var continueFreeButton: some View {
        Button(action: { onClose?() }) {
            Text("Continue free")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var subscribeButton: some View {
        Button(action: {
            Task { await purchaseSelectedPlan() }
        }) {
            HStack(spacing: 8) {
                Text(isPurchasing ? "Connecting..." : entryPoint.buttonTitle)
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppGradients.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: AppColors.purplePrimary.opacity(0.35), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
        .opacity(isPurchasing ? 0.72 : 1)
        .accessibilityLabel(entryPoint.buttonTitle)
    }

    private var footerLinks: some View {
        HStack(spacing: AppSpacing.lg) {
            Button(isRestoring ? "Restoring..." : "Restore Purchase") {
                Task { await restorePurchases() }
            }
            Text("·")
            Button("Terms") {}
            Text("·")
            Button("Privacy") {}
        }
        .font(.system(size: 11))
        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var countdownText: String {
        let total = Int(max(remaining, 0))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%dh %dm %ds", hours, minutes, seconds)
    }

    @MainActor
    private func purchaseSelectedPlan() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let productID = ProEntitlementService.productID(for: selectedPlan)
            let offerings = try await ProEntitlementService.offerings()
            let packages = offerings.current?.availablePackages ?? []
            guard let package = packages.first(where: { $0.storeProduct.productIdentifier == productID }) else {
                purchaseError = "This plan is not available yet. Check the RevenueCat offering configuration."
                return
            }

            if try await ProEntitlementService.purchase(package: package) {
                onSubscribe?(selectedPlan)
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    @MainActor
    private func restorePurchases() async {
        isRestoring = true
        purchaseError = nil
        defer { isRestoring = false }

        do {
            if try await ProEntitlementService.restorePurchases() {
                onRestore?()
            } else {
                purchaseError = "No active Delayd Pro purchase was found for this Apple ID."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

private struct ProFeature: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let tint: Color
    let background: Color
}

#Preview("Delayd Pro") {
    DelaydProView()
        .preferredColorScheme(.light)
}
