import StoreKit
import SwiftUI
import UIKit

enum SubscriptionTier: String, CaseIterable {
    case free = "Free"
    case premium = "Premium"
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "Basic mood tracking",
                "Mood statistics and insights",
                "Custom moods and tags",
                "Journal entries"
            ]
        case .premium:
            return [
                "All Free features",
                "AI-powered mood analysis",
                "Personalized suggestions",
                "AI reflection insights",
                "Unlimited AI responses"
            ]
        }
    }
}

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var currentSubscriptionTier: SubscriptionTier = .free
    @Published var errorMessage: String?
    @Published var showError = false
    @Published private(set) var activeSubscriptions: [StoreKit.Transaction] = []
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<StoreKit.Transaction>) async {
        let transaction = try? result.payloadValue
        await transaction?.finish()
        await self.updateSubscriptionStatus()
    }
    
    func requestProducts() async {
        do {
            let productID = "mindvacation.com.Embernote.subscription.premium.monthly"
            let storeProducts = try await Product.products(for: [productID])
            
            DispatchQueue.main.async {
                self.subscriptions = storeProducts
                if storeProducts.isEmpty {
                    self.errorMessage = """
                        No products available. Please verify:
                        1. StoreKit configuration is selected in scheme settings
                        2. Bundle ID matches configuration
                        3. Product ID matches configuration
                        4. Clean build folder and rebuild
                        5. Check Xcode > Product > Scheme > Edit Scheme > Run > Options
                        """
                    self.showError = true
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = """
                    Failed to load products. Please verify your configuration settings.
                    """
                self.showError = true
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            
        case .userCancelled:
            break
            
        case .pending:
            self.errorMessage = "Transaction pending user action"
            self.showError = true
            
        @unknown default:
            break
        }
    }
    
    func updateSubscriptionStatus() async {
        var currentSubscriptions: [StoreKit.Transaction] = []
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                // Check if the subscription is still valid
                if transaction.revocationDate == nil {
                    currentSubscriptions.append(transaction)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.activeSubscriptions = currentSubscriptions
            self.currentSubscriptionTier = currentSubscriptions.isEmpty ? .free : .premium
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    #if DEBUG
    func debugUnsubscribe() {
        DispatchQueue.main.async {
            self.activeSubscriptions = []
            self.currentSubscriptionTier = .free
        }
    }
    #endif
    
    func canAccessAIFeatures() -> Bool {
        return currentSubscriptionTier == .premium
    }
    
    func manageSubscriptions() async {
        do {
            // Get the active window scene
            guard let windowScene = await UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                throw StoreError.noWindowScene
            }
            try await AppStore.showManageSubscriptions(in: windowScene)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Could not open subscription management. Please check your settings app."
                self.showError = true
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
    case noWindowScene
} 
 