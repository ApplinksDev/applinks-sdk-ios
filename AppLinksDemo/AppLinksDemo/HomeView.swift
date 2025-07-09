import SwiftUI

struct HomeView: View {
    @State private var clipboardContent = ""
    @State private var showingCopiedAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("AppLinks Demo")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Test deferred deep links and link handling")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Clipboard Testing Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Test Deferred Deep Links")
                            .font(.headline)
                        
                        Text("Copy a visit ID to clipboard, then restart the app to simulate a fresh install:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Sample Visit IDs
                        VStack(spacing: 10) {
                            ClipboardButton(
                                title: "Product Link",
                                content: "applinks://product/shoes-123",
                                description: "Opens product detail page"
                            )
                            
                            ClipboardButton(
                                title: "Promo Link",
                                content: "applinks://promo/SUMMER2024",
                                description: "Opens promo page with code"
                            )
                            
                            ClipboardButton(
                                title: "Home Link",
                                content: "applinks://home",
                                description: "Opens home page"
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Direct Link Testing Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Test Direct Links")
                            .font(.headline)
                        
                        Text("Tap to test link handling directly:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 10) {
                            LinkButton(
                                title: "Product Page",
                                urlString: "https://example.onapp.link/shoes"
                            )
                            
                            LinkButton(
                                title: "Promo Page",
                                urlString: "applinks://promo/SUMMER2024"
                            )
                            
                            LinkButton(
                                title: "Universal Link",
                                urlString: "https://example.onapp.link/shoes"
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Label("How to test deferred links:", systemImage: "info.circle")
                            .font(.headline)
                        
                        Text("1. Copy a visit ID to clipboard")
                        Text("2. Delete the app from your device")
                        Text("3. Reinstall and launch the app")
                        Text("4. The SDK will read the clipboard and navigate automatically")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("AppLinks Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ClipboardButton: View {
    let title: String
    let content: String
    let description: String
    @State private var copied = false
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = content
            withAnimation {
                copied = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    copied = false
                }
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(copied ? .green : .blue)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LinkButton: View {
    let title: String
    let urlString: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: urlString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
