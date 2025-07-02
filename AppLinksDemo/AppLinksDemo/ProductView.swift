import SwiftUI

struct ProductView: View {
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Product Image
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.orange)
                        .padding(.top, 40)
                    
                    // Product Info
                    VStack(spacing: 10) {
                        Text("Product Details")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let productId = navigationState.productId {
                            Text("Product ID: \(productId)")
                                .font(.headline)
                                .foregroundColor(.orange)
                        } else {
                            Text("No product selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Product Description
                    VStack(alignment: .leading, spacing: 15) {
                        Text("About This Product")
                            .font(.headline)
                        
                        Text("This view demonstrates how AppLinks can deep link directly to specific products in your app. When a user clicks on a product link, they're brought directly here.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if navigationState.productId != nil {
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
                    
                    // Sample Product Links
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Try These Product Links")
                            .font(.headline)
                        
                        ForEach(["shoes-123", "watch-456", "bag-789"], id: \.self) { productId in
                            Button(action: {
                                navigationState.productId = productId
                            }) {
                                HStack {
                                    Text("Product: \(productId)")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.orange)
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
            .navigationTitle("Product")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}