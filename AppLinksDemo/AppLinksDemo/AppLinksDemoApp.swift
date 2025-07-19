import SwiftUI
import AppLinksSDK

@main
struct AppLinksDemoApp: App {
    @StateObject private var navigationState = NavigationState()
    @StateObject private var applinksSDK: AppLinksSDK
    
    init() {
        // Initialize AppLinks SDK without callback first
        AppLinksSDK.initialize(
            apiKey: "pk_thund3Qt1SAqvUtJtPzFBYg7aVMJ9BPD",
            supportedDomains: ["example.onapp.link"],
            supportedSchemes: ["applinks", "com.applinks.applinksdemo"],
            logLevel: .debug
        )
        
        _applinksSDK = StateObject(wrappedValue: AppLinksSDK.shared)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationState)
                .onOpenURL { url in
                    AppLinksSDK.shared.handleLink(url)
                }
                .onReceive(applinksSDK.linkPublisher, perform: { linkResult in
                    if (linkResult.handled) {
                        navigateFromPath(linkResult.path, metadata: linkResult.metadata)
                    }
                })
        }
    }
    
    private func navigateFromPath(_ path: String, metadata: [String: Any]) {
        let pathComponents = path
            .split(separator: "/")
            .map { String($0).lowercased() }
        
        guard let firstComponent = pathComponents.first else {
            navigationState.selectedTab = .home
            return
        }
        
        switch firstComponent {
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
        case create
    }
    
    static let shared = NavigationState()
    
    func handleLinkResult(_ result: LinkHandlingResult) {
        guard result.handled else { return }
        
        let url = result.originalUrl
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if pathComponents.isEmpty {
            selectedTab = .home
            return
        }
        
        switch pathComponents[0].lowercased() {
        case "product":
            selectedTab = .product
            if pathComponents.count > 1 {
                productId = pathComponents[1]
            }
            
        case "promo":
            selectedTab = .promo
            if pathComponents.count > 1 {
                promoCode = pathComponents[1]
            }
            
        default:
            selectedTab = .home
        }
    }
}
