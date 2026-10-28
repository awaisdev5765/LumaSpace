import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreService
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var aiService = AIDesignService.shared
    @StateObject private var scanManager = RoomScanManager.shared
    var body: some View {
        TabView(selection: $appState.activeTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppState.Tab.home)

            ScanView()
                .tabItem { Label("Scan", systemImage: "viewfinder.circle") }
                .tag(AppState.Tab.scan)

            DesignsView()
                .tabItem { Label("Designs", systemImage: "paintbrush") }
                .tag(AppState.Tab.designs)
                .badge(appState.hasNewDesignsReady ? 1 : 0)

            ARRoomView()
                .tabItem { Label("Furnishings", systemImage: "chair") }
                .tag(AppState.Tab.ar)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppState.Tab.profile)
        }
        .tint(appState.accentColor)
        .environmentObject(projectStore)
        .environmentObject(aiService)
        .environmentObject(scanManager)
        .onChange(of: appState.activeTab) { _, newTab in
            LumaHaptics.selection()
            if newTab == .designs {
                appState.hasNewDesignsReady = false
            }
        }
        .sheet(isPresented: $appState.isShowingSubscription) {
            SubscriptionView(context: .upgrade)
                .environmentObject(store)
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAR)) { _ in
            appState.activeTab = .ar
        }
    }
}

extension Notification.Name {
    static let launchAR = Notification.Name("lumaspace.launchAR")
    static let launchCatalogSearch = Notification.Name("lumaspace.launchCatalogSearch")
}
