import SwiftUI

struct PromoView: View {
    @EnvironmentObject var navigationState: NavigationState
    @State private var appliedPromo: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Promo Image
                    Image(systemName: "gift.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.purple)
                        .padding(.top, 40)
                    
                    // Promo Info
                    VStack(spacing: 10) {
                        Text("Special Offers")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let promoCode = navigationState.promoCode {
                            VStack(spacing: 5) {
                                Text("Active Promo Code")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(promoCode)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        } else {
                            Text("No active promo code")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Apply Promo Button
                    if let promoCode = navigationState.promoCode {
                        Button(action: {
                            withAnimation {
                                appliedPromo = promoCode
                            }
                        }) {
                            HStack {
                                Image(systemName: appliedPromo != nil ? "checkmark.circle.fill" : "tag.fill")
                                Text(appliedPromo != nil ? "Promo Applied!" : "Apply Promo Code")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(appliedPromo != nil ? Color.green : Color.purple)
                            .cornerRadius(10)
                        }
                        .disabled(appliedPromo != nil)
                    }
                    
                    // Promo Description
                    VStack(alignment: .leading, spacing: 15) {
                        Text("How Promo Links Work")
                            .font(.headline)
                        
                        Text("AppLinks can direct users to specific promotions with pre-filled promo codes. This is perfect for email campaigns, social media, or partner websites.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if navigationState.promoCode != nil {
                            Label("Linked from AppLinks", systemImage: "link")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Sample Promo Links
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Try These Promo Codes")
                            .font(.headline)
                        
                        ForEach(["SUMMER2024", "SAVE20", "WELCOME10"], id: \.self) { promoCode in
                            Button(action: {
                                navigationState.promoCode = promoCode
                                appliedPromo = nil
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(promoCode)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(getPromoDescription(promoCode))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.purple)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Promotions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func getPromoDescription(_ code: String) -> String {
        switch code {
        case "SUMMER2024":
            return "Summer sale - 25% off"
        case "SAVE20":
            return "Save 20% on your order"
        case "WELCOME10":
            return "New customer - 10% off"
        default:
            return "Special offer"
        }
    }
}