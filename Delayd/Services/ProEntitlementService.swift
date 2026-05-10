import Foundation
import RevenueCat

enum ProEntitlementService {
    /// Production public SDK key is injected via Info.plist (`RevenueCatAPIKey`)
    /// so we don't ship credentials in source. If the key is missing, we fail
    /// loudly in DEBUG and return an empty string in Release — the SDK will
    /// log a configuration error rather than silently using a test key.
    static var apiKey: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
            !value.isEmpty
        else {
            #if DEBUG
            assertionFailure("Missing RevenueCatAPIKey in Info.plist")
            #endif
            return ""
        }
        return value
    }
    static let entitlementID = "Delayd Pro"

    enum ProductID {
        static let lifetime = "lifetime"
        static let yearly = "delayd_yearly"
        static let monthly = "delayd_monthly"
    }

    private static let cachedEntitlementKey = "delayd.revenuecat.pro.active"
    private static let cachedProductIdentifierKey = "delayd.revenuecat.pro.productIdentifier"
    private static let cachedExpirationDateKey = "delayd.revenuecat.pro.expirationDate"
    private static var isConfigured = false
    private static var isListening = false

    static var isUnlocked: Bool {
        UserDefaults.standard.bool(forKey: cachedEntitlementKey)
    }

    static var activeProductIdentifier: String? {
        UserDefaults.standard.string(forKey: cachedProductIdentifierKey)
    }

    static var activeExpirationDate: Date? {
        let value = UserDefaults.standard.double(forKey: cachedExpirationDateKey)
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    static func configure() {
        guard !isConfigured else { return }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
    }

    @discardableResult
    static func refreshCustomerInfo() async -> Bool {
        configure()

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return await MainActor.run {
                updateEntitlementCache(customerInfo)
            }
        } catch {
            #if DEBUG
            print("RevenueCat customerInfo failed: \(error.localizedDescription)")
            #endif
            return await MainActor.run { isUnlocked }
        }
    }

    static func startCustomerInfoListener() {
        configure()
        guard !isListening else { return }
        isListening = true

        Task.detached(priority: .background) {
            for await customerInfo in Purchases.shared.customerInfoStream {
                _ = await MainActor.run {
                    updateEntitlementCache(customerInfo)
                }
            }
        }
    }

    static func offerings() async throws -> Offerings {
        configure()
        return try await Purchases.shared.offerings()
    }

    static func purchase(package: Package) async throws -> Bool {
        configure()
        let result = try await Purchases.shared.purchase(package: package)
        return await MainActor.run {
            updateEntitlementCache(result.customerInfo)
        }
    }

    static func restorePurchases() async throws -> Bool {
        configure()
        let customerInfo = try await Purchases.shared.restorePurchases()
        return await MainActor.run {
            updateEntitlementCache(customerInfo)
        }
    }

    static func productID(for plan: DelaydProView.Plan) -> String {
        switch plan {
        case .lifetime: ProductID.lifetime
        case .yearly: ProductID.yearly
        case .monthly: ProductID.monthly
        }
    }

    static func isProActive(_ customerInfo: CustomerInfo) -> Bool {
        if customerInfo.entitlements[entitlementID]?.isActive == true {
            return true
        }

        // Fallback for dashboard-entitlement-id mismatches: if any known Pro
        // product is active, treat the user as Pro to avoid false negatives.
        let knownProducts = Set([ProductID.monthly, ProductID.yearly, ProductID.lifetime])
        let hasKnownSubscription = !knownProducts.intersection(customerInfo.activeSubscriptions).isEmpty
        let hasKnownNonSub = customerInfo.nonSubscriptions.contains { knownProducts.contains($0.productIdentifier) }
        return hasKnownSubscription || hasKnownNonSub || customerInfo.entitlements.active.isEmpty == false
    }

    @discardableResult
    @MainActor
    private static func updateEntitlementCache(_ customerInfo: CustomerInfo) -> Bool {
        let isActive = isProActive(customerInfo)
        UserDefaults.standard.set(isActive, forKey: cachedEntitlementKey)
        DelaydWidgetSync.syncProState(isUnlocked: isActive)
        if let productIdentifier = activeProductIdentifier(from: customerInfo) {
            UserDefaults.standard.set(productIdentifier, forKey: cachedProductIdentifierKey)
        } else if !isActive {
            UserDefaults.standard.removeObject(forKey: cachedProductIdentifierKey)
        }

        if let expirationDate = customerInfo.entitlements[entitlementID]?.expirationDate {
            UserDefaults.standard.set(expirationDate.timeIntervalSince1970, forKey: cachedExpirationDateKey)
        } else if !isActive || activeProductIdentifier == ProductID.lifetime {
            UserDefaults.standard.removeObject(forKey: cachedExpirationDateKey)
        }

        NotificationCenter.default.post(name: .delaydProEntitlementChanged, object: isActive)
        return isActive
    }

    private static func activeProductIdentifier(from customerInfo: CustomerInfo) -> String? {
        let knownProducts = [ProductID.monthly, ProductID.yearly, ProductID.lifetime]
        if let subscription = knownProducts.first(where: { customerInfo.activeSubscriptions.contains($0) }) {
            return subscription
        }
        if let nonSubscription = customerInfo.nonSubscriptions.first(where: { purchase in
            knownProducts.contains(purchase.productIdentifier)
        }) {
            return nonSubscription.productIdentifier
        }
        return customerInfo.entitlements[entitlementID]?.productIdentifier
    }

    #if DEBUG
    static func reset() {
        UserDefaults.standard.removeObject(forKey: cachedEntitlementKey)
        UserDefaults.standard.removeObject(forKey: cachedProductIdentifierKey)
        UserDefaults.standard.removeObject(forKey: cachedExpirationDateKey)
    }
    #endif
}

extension Notification.Name {
    static let delaydProEntitlementChanged = Notification.Name("delayd.pro.entitlementChanged")
}
