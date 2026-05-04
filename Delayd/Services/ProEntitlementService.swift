import Foundation
import RevenueCat

enum ProEntitlementService {
    static let apiKey = "test_niMDJfimwqmlQdohUQZYfcNJnZZ"
    static let entitlementID = "Delayd Pro"

    enum ProductID {
        static let lifetime = "lifetime"
        static let yearly = "yearly"
        static let monthly = "monthly"
    }

    private static let cachedEntitlementKey = "delayd.revenuecat.pro.active"
    private static var isConfigured = false

    static var isUnlocked: Bool {
        UserDefaults.standard.bool(forKey: cachedEntitlementKey)
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

    static func startCustomerInfoListener() async {
        configure()

        for await customerInfo in Purchases.shared.customerInfoStream {
            _ = await MainActor.run {
                updateEntitlementCache(customerInfo)
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
        customerInfo.entitlements[entitlementID]?.isActive == true
    }

    @discardableResult
    @MainActor
    private static func updateEntitlementCache(_ customerInfo: CustomerInfo) -> Bool {
        let isActive = isProActive(customerInfo)
        UserDefaults.standard.set(isActive, forKey: cachedEntitlementKey)
        NotificationCenter.default.post(name: .delaydProEntitlementChanged, object: isActive)
        return isActive
    }

    #if DEBUG
    static func reset() {
        UserDefaults.standard.removeObject(forKey: cachedEntitlementKey)
    }
    #endif
}

extension Notification.Name {
    static let delaydProEntitlementChanged = Notification.Name("delayd.pro.entitlementChanged")
}
