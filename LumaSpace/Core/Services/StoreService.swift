import StoreKit
import SwiftUI
import Combine

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    // MARK: Product IDs

    enum ProductID {
        static let proMonthly   = "com.lumaspace.pro.monthly"
        static let proAnnual    = "com.lumaspace.pro.annual"
        static let premMonthly  = "com.lumaspace.premium.monthly"
        static let premAnnual   = "com.lumaspace.premium.annual"
        static let lifetime     = "com.lumaspace.lifetime"

        static var all: [String] { [proMonthly, proAnnual, premMonthly, premAnnual, lifetime] }
    }

    // MARK: Published State

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var currentTier: SubscriptionTier = .free

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        // Silently read existing entitlements — no sign-in prompt.
        // AppStore.sync() is only called when the user explicitly taps Restore Purchases.
        Task { await updatePurchasedProducts() }
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all)
            products.sort { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: Purchase

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            LumaHaptics.notification(.success)
        case .pending:
            break
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    // MARK: Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    // Verification failed — ignore
                }
            }
        }
    }

    // MARK: Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    // MARK: Update State

    @MainActor
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
        currentTier = resolveTier(from: purchased)
    }

    private func resolveTier(from ids: Set<String>) -> SubscriptionTier {
        if ids.contains(ProductID.lifetime)    { return .lifetime }
        if ids.contains(ProductID.premAnnual)  { return .premium }
        if ids.contains(ProductID.premMonthly) { return .premium }
        if ids.contains(ProductID.proAnnual)   { return .pro }
        if ids.contains(ProductID.proMonthly)  { return .pro }
        return .free
    }

    // MARK: Convenience

    func product(for id: String) -> Product? { products.first { $0.id == id } }

    var proMonthly:  Product? { product(for: ProductID.proMonthly) }
    var proAnnual:   Product? { product(for: ProductID.proAnnual) }
    var premMonthly: Product? { product(for: ProductID.premMonthly) }
    var premAnnual:  Product? { product(for: ProductID.premAnnual) }
    var lifetime:    Product? { product(for: ProductID.lifetime) }

    func canAccessFeature(requiring tier: SubscriptionTier) -> Bool {
        switch (currentTier, tier) {
        case (.lifetime, _):       return true
        case (.premium, .premium): return true
        case (.premium, .pro):     return true
        case (.pro, .pro):         return true
        case (_, .free):           return true
        default:                   return false
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "Purchase verification failed. Please contact support."
        }
    }
}
