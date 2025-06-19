//
//  SubscriptionView.swift
//  EmberNote
//

import SwiftUI
import StoreKit

// Helper function to convert subscription period unit to string
private func periodUnitString(_ unit: Product.SubscriptionPeriod.Unit) -> String {
    switch unit {
    case .day: return "day"
    case .week: return "week"
    case .month: return "month"
    case .year: return "year"
    @unknown default: return "period"
    }
}

// Header component
private struct SubscriptionHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.themeAccent)
            
            Text("Upgrade to Premium")
                .font(.title.bold())
            
            Text("Unlock the full power of AI insights")
                .font(.title3)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 32)
    }
}

// Feature list component
private struct FeatureList: View {
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(tier.rawValue)
                    .font(.title2.bold())
                
                if isCurrentTier {
                    Text("(Current)")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if tier == .premium {
                    Text("$2.99/month")
                        .font(.title2.bold())
                        .foregroundColor(.themeAccent)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.body)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.5))
        )
    }
}

// Main view
struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    SubscriptionHeader()
                    
                    // Feature comparison
                    VStack(spacing: 20) {
                        ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                            FeatureList(
                                tier: tier,
                                isCurrentTier: tier == subscriptionManager.currentSubscriptionTier
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 32)
                    
                    // Subscribe button section
                    if subscriptionManager.currentSubscriptionTier == .free {
                        VStack(spacing: 24) {
                            ForEach(subscriptionManager.subscriptions) { subscription in
                                VStack(spacing: 16) {
                                    // Subscribe button with integrated pricing
                                Button(action: {
                                    Task {
                                        do {
                                            try await subscriptionManager.purchase(subscription)
                                            dismiss()
                                        } catch {
                                            // Error handling is done in SubscriptionManager
                                        }
                                    }
                                }) {
                                        VStack(spacing: 8) {
                                            // Check if there's an introductory offer AND user is eligible for it
                                            if let introOffer = subscription.subscription?.introductoryOffer,
                                               introOffer.paymentMode == .freeTrial,
                                               subscriptionManager.isEligibleForIntroOffer(subscription) {
                                                Text("Try It Free")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                
                                                let trialPeriod = introOffer.period
                                                let trialText = "\(trialPeriod.value) \(periodUnitString(trialPeriod.unit))\(trialPeriod.value > 1 ? "s" : "") free, then \(subscription.displayPrice)/month"
                                                Text(trialText)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.9))
                                            } else {
                                                Text("Subscribe Now")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                
                                                Text("\(subscription.displayPrice)/month")
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.themeAccent)
                                        )
                                        .padding(.horizontal)
                                }
                                
                                    // Simple disclaimer
                                    Text("Cancel anytime")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        #if DEBUG
                        // Debug button to simulate premium subscription
                        Button(action: {
                            subscriptionManager.debugSubscribe()
                        }) {
                            Text("Debug: Simulate Premium")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                                .padding(.horizontal)
                        }
                        #endif
                    } else {
                        VStack(spacing: 16) {
                            // Show different icons based on subscription status
                            if subscriptionManager.isSubscriptionCanceled {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.orange)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.green)
                            }
                            
                            // Show different titles based on subscription status
                            if subscriptionManager.isSubscriptionCanceled {
                                Text("Subscription Canceled")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            } else {
                                Text("You're a Premium Member")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                            
                            // Show expiration information
                            if let expirationText = subscriptionManager.subscriptionExpirationText {
                                if subscriptionManager.isSubscriptionCanceled {
                                    VStack(spacing: 4) {
                                        Text("Your premium access \(expirationText)")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                            .multilineTextAlignment(.center)
                                        
                                        Text("Resubscribe to continue enjoying premium features")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                    }
                                } else {
                                    VStack(spacing: 4) {
                                        Text("Thank you for your support!")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        Text("Your subscription \(expirationText)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Text("Thank you for your support!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // Show different buttons based on subscription status
                            if subscriptionManager.isSubscriptionCanceled {
                                VStack(spacing: 12) {
                                    // Resubscribe button for canceled subscriptions
                                    ForEach(subscriptionManager.subscriptions) { subscription in
                                        Button(action: {
                                            Task {
                                                do {
                                                    try await subscriptionManager.purchase(subscription)
                                                    dismiss()
                                                } catch {
                                                    // Error handling is done in SubscriptionManager
                                                }
                                            }
                                        }) {
                                            Text("Resubscribe for \(subscription.displayPrice)/month")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.themeAccent)
                                                )
                                                .padding(.horizontal)
                                        }
                                    }
                                    
                                    // Secondary manage button
                                    Button(action: {
                                        Task {
                                            await subscriptionManager.manageSubscriptions()
                                        }
                                    }) {
                                        Text("Manage Subscription")
                                            .font(.subheadline)
                                            .foregroundColor(.themeAccent)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.themeAccent, lineWidth: 1)
                                            )
                                            .padding(.horizontal)
                                    }
                                }
                            } else {
                                Button(action: {
                                    Task {
                                        await subscriptionManager.manageSubscriptions()
                                    }
                                }) {
                                    Text("Manage Subscription")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.themeAccent)
                                        )
                                        .padding(.horizontal)
                                }
                            }
                            
                            #if DEBUG
                            Button(action: {
                                subscriptionManager.debugUnsubscribe()
                            }) {
                                Text("Debug: Unsubscribe")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                            }
                            #endif
                        }
                        .padding()
                    }
                    
                    // Restore and Terms
                    VStack(spacing: 16) {
                        if subscriptionManager.currentSubscriptionTier == .free {
                            Button(action: {
                                Task {
                                    try? await AppStore.sync()
                                    await subscriptionManager.updateSubscriptionStatus()
                                }
                            }) {
                                Text("Restore Purchases")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text("Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack(spacing: 4) {
                            Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Text("•")
                            Link("Privacy Policy", destination: URL(string: "https://www.privacypolicies.com/live/e7b6b6d6-ae8d-4d02-be69-f8c2eca02440")!)
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding(.bottom)
                }
            }
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $subscriptionManager.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(subscriptionManager.errorMessage ?? "An error occurred")
            }
        }
    }
} 