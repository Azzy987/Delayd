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
    var onManageSubscription: (() -> Void)?

    @State private var selectedPlan: Plan = .lifetime
    @State private var showMore = false
    @State private var remaining: TimeInterval = (19 * 3600) + (2 * 60) + 40
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseCompleted = false
    @State private var purchaseError: String?
    @State private var planPackages: [Plan: Package] = [:]
    @State private var isProUnlocked = ProEntitlementService.isUnlocked

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

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
        Group {
            if isProUnlocked || purchaseCompleted {
                activeMembershipView
            } else {
                purchaseView
            }
        }
        .task {
            isProUnlocked = await ProEntitlementService.refreshCustomerInfo()
            if !isProUnlocked {
                await loadOfferings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .delaydProEntitlementChanged)) { note in
            if let unlocked = note.object as? Bool {
                isProUnlocked = unlocked
            } else {
                isProUnlocked = ProEntitlementService.isUnlocked
            }
        }
        .onDisappear {
            Task {
                _ = await ProEntitlementService.refreshCustomerInfo()
            }
        }
    }

    private var purchaseView: some View {
        ZStack(alignment: .bottom) {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    header
                        .padding(.top, AppSpacing.xs)

                    sparkleIcon

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
    }

    private var activeMembershipView: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    header
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)

                    Image("PaywallHero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                        .shadow(
                            color: AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.14 : 0.18),
                            radius: 20,
                            x: 0,
                            y: 12
                        )
                        .padding(.top, AppSpacing.xs)

                    VStack(spacing: AppSpacing.xs) {
                        Text("Delayd Pro Active")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        Text("Your premium dream-protection tools are unlocked.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    activeFeatureCard
                        .padding(.horizontal, AppSpacing.lg)

                    activePlanDetailsCard
                        .padding(.horizontal, AppSpacing.lg)

                    Button(role: .destructive) {
                        openSubscriptionManagement()
                    } label: {
                        Text("Cancel My Subscription")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppColors.negative, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.lg)

                    Text("Subscriptions are managed through your Apple ID. Lifetime purchases do not renew.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)

                    footerLinks
                        .padding(.bottom, AppSpacing.xl)
                }
            }
        }
    }

    private var activeFeatureCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Included with Delayd Pro")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            VStack(spacing: AppSpacing.sm) {
                ForEach(primaryFeatures) { feature in
                    featureRow(feature, dimmed: false)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var activePlanDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.positive)
                Text("Plan details")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            }

            planDetailRow(title: "Plan", value: activePlanTitle)
            planDetailRow(title: "Status", value: "Active")
            planDetailRow(title: activePlanTitle == "Lifetime" ? "Access" : "Renews", value: activeRenewalText)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.positive.opacity(colorScheme == .dark ? 0.30 : 0.22), lineWidth: 1)
        }
    }

    private func planDetailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            Spacer(minLength: AppSpacing.md)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: title == "Plan" ? .default : .monospaced))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .multilineTextAlignment(.trailing)
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

    @ViewBuilder
    private var planCards: some View {
        if purchaseCompleted || ProEntitlementService.isUnlocked {
            VStack(spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: 12) {
                    Image("PaywallHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.positive)
                            Text("Delayd Pro Active")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        }

                        Text("Plan: \(activePlanTitle)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                        Text(validityText)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 6) {
                    successFeatureRow("Unlimited active dreams")
                    successFeatureRow("Smart delay reminders and weekly recap")
                    successFeatureRow("Hard-mode commitment prompts")
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.positive.opacity(0.28), lineWidth: 1)
            }
            .background(
                AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.22 : 1),
                in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
            )
        } else {
            VStack(spacing: AppSpacing.sm) {
                lifetimeCard
                yearlyCard
                monthlyCard
            }
        }
    }

    private func successFeatureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.positive)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            Spacer(minLength: 0)
        }
    }

    private var activePlanTitle: String {
        switch ProEntitlementService.activeProductIdentifier {
        case ProEntitlementService.ProductID.lifetime: return "Lifetime"
        case ProEntitlementService.ProductID.yearly: return "Yearly"
        case ProEntitlementService.ProductID.monthly: return "Monthly"
        default:
            switch selectedPlan {
            case .lifetime: return "Lifetime"
            case .yearly: return "Yearly"
            case .monthly: return "Monthly"
            }
        }
    }

    private var activeRenewalText: String {
        if activePlanTitle == "Lifetime" {
            return "Lifetime access"
        }
        guard let expiration = ProEntitlementService.activeExpirationDate else {
            return "Renews automatically"
        }
        return expiration.formatted(date: .abbreviated, time: .omitted)
    }

    private var validityText: String {
        switch selectedPlan {
        case .lifetime:
            return "Validity: Lifetime access (one-time purchase)."
        case .yearly:
            return "Validity: Active for 1 year. Renews yearly until cancelled."
        case .monthly:
            return "Validity: Active for 1 month. Renews monthly until cancelled."
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
                    Text(priceText(for: .lifetime, fallback: "$29.99"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Text(lifetimeSavingsText)
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

    private var yearlyCard: some View {
        let isSelected = selectedPlan == .yearly

        return Button(action: { selectedPlan = .yearly }) {
            HStack(spacing: 14) {
                radio(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Yearly")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Text("Best value for consistent protection")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    (
                        Text(priceText(for: .yearly, fallback: "$19.99 "))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        + Text("/Year")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    )
                    if let yearlySavingsText {
                        Text(yearlySavingsText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.positive)
                    }
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

                (
                    Text(priceText(for: .monthly, fallback: "$2.99 "))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    + Text("/Month")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                )
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
            if purchaseCompleted || ProEntitlementService.isUnlocked {
                onSubscribe?(selectedPlan)
                return
            }
            Task { await purchaseSelectedPlan() }
        }) {
            HStack(spacing: 8) {
                Text(isPurchasing ? "Connecting..." : (purchaseCompleted ? "Continue" : entryPoint.buttonTitle))
                    .font(.system(size: 16, weight: .semibold))
                if !isPurchasing {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
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
        HStack(spacing: 16) {
            Spacer(minLength: 0)

            Button(isRestoring ? "Restoring..." : "Restore") {
                Task { await restorePurchases() }
            }

            Text("·")

            Link("Terms", destination: URL(string: "https://www.droidates.com/p/terms-of-use-delayd.html")!)

            Text("·")

            Link("Privacy", destination: URL(string: "https://www.droidates.com/p/privacy-policy-delayd.html")!)

            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
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
            if planPackages.isEmpty {
                await loadOfferings()
            }
            guard let package = planPackages[selectedPlan] else {
                purchaseError = "This plan is not available yet. Check the RevenueCat offering configuration."
                return
            }

            if try await ProEntitlementService.purchase(package: package) {
                purchaseCompleted = true
                isProUnlocked = true
            } else {
                purchaseError = "Purchase completed, but Pro entitlement was not detected yet. Tap Restore."
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
                purchaseCompleted = true
                isProUnlocked = true
                onRestore?()
            } else {
                purchaseError = "No active Delayd Pro purchase was found for this Apple ID."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    @MainActor
    private func loadOfferings() async {
        do {
            let offerings = try await ProEntitlementService.offerings()
            let packages = offerings.current?.availablePackages ?? []
            var map: [Plan: Package] = [:]
            for plan in [Plan.lifetime, .yearly, .monthly] {
                let productID = ProEntitlementService.productID(for: plan)
                if let pkg = packages.first(where: { $0.storeProduct.productIdentifier == productID }) {
                    map[plan] = pkg
                }
            }
            planPackages = map
        } catch {
            // Keep fallback price labels and surface purchase-time errors only.
        }
    }

    private func priceText(for plan: Plan, fallback: String) -> String {
        if let pkg = planPackages[plan] {
            return pkg.storeProduct.localizedPriceString
        }
        return fallback
    }

    private var monthlyPriceValue: Decimal? {
        planPackages[.monthly]?.storeProduct.price as Decimal?
    }

    private var yearlyPriceValue: Decimal? {
        planPackages[.yearly]?.storeProduct.price as Decimal?
    }

    private var lifetimePriceValue: Decimal? {
        planPackages[.lifetime]?.storeProduct.price as Decimal?
    }

    private var yearlySavingsText: String? {
        guard let monthly = monthlyPriceValue, let yearly = yearlyPriceValue, monthly > 0 else { return nil }
        let yearlyFromMonthly = monthly * 12
        guard yearlyFromMonthly > yearly else { return nil }
        let discount = NSDecimalNumber(decimal: ((yearlyFromMonthly - yearly) / yearlyFromMonthly) * 100).doubleValue
        return "\(Int(discount.rounded()))% off vs monthly"
    }

    private var lifetimeSavingsText: String {
        guard let monthly = monthlyPriceValue, let lifetime = lifetimePriceValue, monthly > 0 else { return "Founding" }
        let fromMonthlyYear = monthly * 12
        guard fromMonthlyYear > lifetime else { return "Founding" }
        let discount = NSDecimalNumber(decimal: ((fromMonthlyYear - lifetime) / fromMonthlyYear) * 100).doubleValue
        return "\(Int(discount.rounded()))% off"
    }

    private func openSubscriptionManagement() {
        if let onManageSubscription {
            onManageSubscription()
            return
        }
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(url)
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
