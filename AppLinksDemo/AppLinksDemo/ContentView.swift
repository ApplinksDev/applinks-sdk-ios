import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(NavigationState.Tab.home)
            
            ProductView()
                .tabItem {
                    Label("Product", systemImage: "tag")
                }
                .tag(NavigationState.Tab.product)
            
            PromoView()
                .tabItem {
                    Label("Promo", systemImage: "gift")
                }
                .tag(NavigationState.Tab.promo)
        }
    }
}