import SwiftUI
import StoreKit
import UserNotifications
import TipKit

@main
struct LumaSpaceApp: App {
    @StateObject private var store = StoreService.shared
    @StateObject private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    RootView()
                        .task { await store.loadProducts() }
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .environmentObject(appState)
            .preferredColorScheme(appState.colorScheme)
            .tint(appState.accentColor)
            .environment(\.lumaAccent, appState.accentColor)
            .onOpenURL { url in handleDeepLink(url) }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // lumaspace://project/<uuid>  — from Spotlight / share sheet
        // lumaspace://project/latest  — from widget
        guard url.scheme == "lumaspace", url.host == "project" else { return }

        let idString = url.pathComponents.dropFirst().first

        let project: Project?
        if idString == "latest" {
            project = ProjectStore.shared.projects.first
        } else {
            project = ProjectStore.shared.projects.first(where: { $0.id.uuidString == idString })
        }

        guard let project else { return }
        appState.activeProject = project
        appState.activeTab = .home
    }
}

// MARK: - App State

// MARK: - Luma Accent Palette

extension Color {
    /// All selectable accent colours (index matches AppState.accentColorIndex)
    static let lumaAccents: [(color: Color, name: String)] = [
        (Color(red: 0.102, green: 0.478, blue: 0.431), "Teal"),       // 0 default
        (Color(red: 0.416, green: 0.192, blue: 0.576), "Indigo"),     // 1
        (Color(red: 0.043, green: 0.518, blue: 1.000), "Blue"),       // 2
        (Color(red: 0.784, green: 0.659, blue: 0.298), "Gold"),       // 3
        (Color(red: 0.914, green: 0.267, blue: 0.365), "Rose"),       // 4
        (Color(red: 0.196, green: 0.667, blue: 0.392), "Green"),      // 5
        (Color(red: 1.000, green: 0.580, blue: 0.000), "Orange"),     // 6
        (Color(red: 0.580, green: 0.345, blue: 0.875), "Lavender"),   // 7
    ]
}

final class AppState: ObservableObject {
    static let shared = AppState()

    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // Appearance
    @AppStorage("preferredColorScheme") private var storedColorScheme = 0
    @AppStorage("accentColorIndex") var accentColorIndex = 0
    @AppStorage("useCompactLayout") var useCompactLayout = false

    // Feature flags / one-time prompts
    @AppStorage("hasSeenReferralBanner") var hasSeenReferralBanner = false
    @AppStorage("hasSeenFirstDesignPaywall") var hasSeenFirstDesignPaywall = false
    @AppStorage("hasSeenNotificationPrePrompt") var hasSeenNotificationPrePrompt = false

    // Furniture wishlist (cross-session)
    @AppStorage("savedFurnitureNames") private var savedFurnitureNamesJSON = ""

    // Navigation / UI state
    @Published var isShowingSubscription = false
    @Published var activeProject: Project?
    @Published var activeTab: Tab = .home
    @Published var hasNewDesignsReady = false
    @Published var shouldAutoStartScan = false
    @Published var pendingDesignStyles: Set<DesignStyle>? = nil

    // Usage tracking delegated to UsageTracker
    @MainActor var isAtRedesignLimit: Bool { UsageTracker.shared.isAtRedesignLimit }
    @MainActor func recordRedesignUsed()   { UsageTracker.shared.recordRedesignUsed() }
    @MainActor func recordScanCompleted(in windowScene: UIWindowScene?) {
        UsageTracker.shared.recordScanCompleted(in: windowScene)
    }

    var accentColor: Color {
        Color.lumaAccents[safe: accentColorIndex]?.color ?? Color.lumaAccents[0].color
    }

    var colorScheme: ColorScheme? {
        switch storedColorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    func notifyDesignsReady() {
        if activeTab != .designs { hasNewDesignsReady = true }
    }

    var savedFurnitureNames: Set<String> {
        guard let data = savedFurnitureNamesJSON.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(array)
    }

    func toggleSavedFurniture(name: String) {
        var current = savedFurnitureNames
        if current.contains(name) { current.remove(name) } else { current.insert(name) }
        if let data = try? JSONEncoder().encode(Array(current)) {
            savedFurnitureNamesJSON = String(data: data, encoding: .utf8) ?? ""
        }
    }

    func isFurnitureSaved(name: String) -> Bool {
        savedFurnitureNames.contains(name)
    }

    enum Tab: Int, Hashable {
        case home, scan, designs, ar, profile
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureAppearance()
        LumaTipsConfig.configure()
        UNUserNotificationCenter.current().delegate = self
        AnalyticsService.shared.track(.appLaunched)
        Task { @MainActor in FurnitureCatalogService.shared.checkPriceAlerts() }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationService.shared.handleAppForegrounded()
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        NotificationService.shared.handleAppBackgrounded()
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        SpotlightService.shared.handle(userActivity)
        return true
    }

    private func configureAppearance() {
        // Use the default opaque-blur material Apple recommends in HIG.
        // Transparent tab bars break contrast and readability on content-heavy screens.
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Navigation bar — use default (inlined large title support)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Deep-link from a tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let type = info["type"] as? String ?? ""

        switch type {
        case "designs":
            AppState.shared.activeTab = .designs
        case "ar":
            AppState.shared.activeTab = .ar
        case "project.continue":
            AppState.shared.activeTab = .home
            if let idString = info["projectId"] as? String,
               let project = ProjectStore.shared.projects.first(where: { $0.id.uuidString == idString }) {
                AppState.shared.activeProject = project
            }
        default:
            // Legacy: designs.ready identifier prefix
            if response.notification.request.identifier.hasPrefix("luma.designs.ready") ||
               response.notification.request.identifier.hasPrefix("designs.ready") {
                AppState.shared.activeTab = .designs
            }
        }
        completionHandler()
    }

    // Show notification banner even in foreground for continuation nudges
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Suppress "designs ready" when already in foreground — tab badge covers it.
        // Show continuation nudges as banners always (they arrive from background anyway).
        completionHandler([])
    }
}
