//
//  SubscriptionManager.swift
//  EmberNote
//

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
    @Published private(set) var introOfferEligibility: [String: Bool] = [:]
    @Published private(set) var subscriptionStatus: Product.SubscriptionInfo.Status?
    @Published private(set) var subscriptionExpirationDate: Date?
    @Published private(set) var willAutoRenew: Bool = false
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateSubscriptionStatus()
        }
        
        // Listen for app becoming active to refresh subscription status
        // This helps catch subscription changes made outside the app
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.updateSubscriptionStatus()
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
        NotificationCenter.default.removeObserver(self)
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
            
            // Check intro offer eligibility for each product
            await checkIntroOfferEligibility(for: storeProducts)
            
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
    
    private func checkIntroOfferEligibility(for products: [Product]) async {
        var eligibility: [String: Bool] = [:]
        
        for product in products {
            // Check if user has ever purchased this product by looking at transaction history
            var hasUsedProduct = false
            
            for await result in Transaction.all {
                if let transaction = try? result.payloadValue,
                   transaction.productID == product.id {
                    hasUsedProduct = true
                    break
                }
            }
            
            eligibility[product.id] = !hasUsedProduct
        }
        
        DispatchQueue.main.async {
            self.introOfferEligibility = eligibility
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            // Note: updateSubscriptionStatus() now includes eligibility refresh
            
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
        var latestStatus: Product.SubscriptionInfo.Status?
        var expirationDate: Date?
        var autoRenewStatus = false
        
        // First, get all current entitlements (this includes active trials)
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                // Check if the subscription is still valid (not revoked)
                if transaction.revocationDate == nil {
                    currentSubscriptions.append(transaction)
                    
                    // Use transaction expiration date as fallback
                    if expirationDate == nil {
                        expirationDate = transaction.expirationDate
                    }
                }
            }
        }
        
        // Get detailed subscription status for auto-renewal info
        if let firstProduct = subscriptions.first,
           let subscription = firstProduct.subscription {
            
            do {
                let statuses = try await subscription.status
                if let firstStatus = statuses.first {
                    let status = firstStatus
                    latestStatus = status
                    
                    // Get auto-renewal information
                    if let renewalInfo = try? status.renewalInfo.payloadValue {
                        autoRenewStatus = renewalInfo.willAutoRenew
                    }
                    
                    // Get expiration date from the transaction (preferred over fallback)
                    if let transaction = try? status.transaction.payloadValue {
                        expirationDate = transaction.expirationDate
                    }
                }
            } catch {
                // If we can't get detailed status, we'll use the fallback values
                print("Could not fetch subscription status: \(error)")
            }
        }
        
        // Update intro offer eligibility whenever subscription status changes
        await checkIntroOfferEligibility(for: subscriptions)
        
        DispatchQueue.main.async {
            self.activeSubscriptions = currentSubscriptions
            // Key fix: User has premium access if they have any current entitlements (including canceled trials)
            self.currentSubscriptionTier = currentSubscriptions.isEmpty ? .free : .premium
            self.subscriptionStatus = latestStatus
            self.subscriptionExpirationDate = expirationDate
            self.willAutoRenew = autoRenewStatus
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
    
    func debugSubscribe() {
        DispatchQueue.main.async {
            self.currentSubscriptionTier = .premium
        }
    }
    #endif
    
    func canAccessAIFeatures() -> Bool {
        return currentSubscriptionTier == .premium
    }
    
    func isEligibleForIntroOffer(_ product: Product) -> Bool {
        return introOfferEligibility[product.id] ?? true
    }
    
    var isSubscriptionCanceled: Bool {
        // A subscription is considered canceled if:
        // 1. User has premium tier (meaning they have active entitlements)
        // 2. But auto-renewal is turned off (they canceled but still have access)
        
        if currentSubscriptionTier != .premium {
            return false // No active subscription
        }
        
        // If we have active entitlements but auto-renewal is off, it's canceled
        if !activeSubscriptions.isEmpty {
            return !willAutoRenew
        }
        
        return false
    }
    
    var subscriptionExpirationText: String? {
        guard let expirationDate = subscriptionExpirationDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let now = Date()
        let calendar = Calendar.current
        
        // Choose verb based on auto-renewal status
        let verb = willAutoRenew ? "renews" : "expires"
        let pastVerb = willAutoRenew ? "renewed" : "expired"
        
        if calendar.isDate(expirationDate, inSameDayAs: now) {
            return "\(verb) today"
        } else if expirationDate > now {
            let components = calendar.dateComponents([.day], from: now, to: expirationDate)
            if let days = components.day {
                if days == 1 {
                    return "\(verb) tomorrow"
                } else if days <= 7 {
                    return "\(verb) in \(days) days"
                } else {
                    return "\(verb) on \(formatter.string(from: expirationDate))"
                }
            }
        }
        
        return "\(pastVerb) on \(formatter.string(from: expirationDate))"
    }
    
    func manageSubscriptions() async {
        do {
            // Get the active window scene
            guard let windowScene = await UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                throw StoreError.noWindowScene
            }
            try await AppStore.showManageSubscriptions(in: windowScene)
            
            // Refresh subscription status after user returns from managing subscriptions
            // This will catch any cancellations or changes made in the subscription management UI
            await updateSubscriptionStatus()
            
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
 