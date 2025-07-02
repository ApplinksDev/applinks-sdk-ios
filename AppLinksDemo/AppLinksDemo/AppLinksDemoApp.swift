import SwiftUI
import AppLinksSDK

@main
struct AppLinksDemoApp: App {
    @StateObject private var navigationState = NavigationState()
    
    init() {
        // Initialize AppLinks SDK
        AppLinksSDK.initialize(
          apiKey: "pk_thund3Qt1SAqvUtJtPzFBYg7aVMJ9BPD",
          supportedDomains: ["example.onapp.link"],
          supportedSchemes: ["applinks"]
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    setupNotifications()
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("App received URL: \(url)")
        
        AppLinksSDK.shared.handleLink(url) { link, metadata in
            print("Successfully handled link: \(link)")
            print("Metadata: \(metadata)")
            
            // Navigate based on the URL
            navigateFromURL(url, metadata: metadata)
        } onError: { error in
            print("Failed to handle link: \(error)")
        }
    }
    
    private func navigateFromURL(_ url: URL, metadata: [String: String]) {
        // Parse URL and navigate accordingly
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if pathComponents.isEmpty {
            navigationState.selectedTab = .home
            return
        }
        
        switch pathComponents[0].lowercased() {
        case "product":
            navigationState.selectedTab = .product
            if pathComponents.count > 1 {
                navigationState.productId = pathComponents[1]
            }
            
        case "promo":
            navigationState.selectedTab = .promo
            if pathComponents.count > 1 {
                navigationState.promoCode = pathComponents[1]
            }
            
        default:
            navigationState.selectedTab = .home
        }
    }
    
    private func setupNotifications() {
        // Listen for custom scheme notifications from SDK
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AppLinksCustomSchemeHandled"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let url = userInfo["url"] as? URL,
               let metadata = userInfo["metadata"] as? [String: String] {
                navigateFromURL(url, metadata: metadata)
            }
        }
    }
}

// Navigation state for the app
class NavigationState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var productId: String?
    @Published var promoCode: String?
    
    enum Tab {
        case home
        case product
        case promo
    }
}
