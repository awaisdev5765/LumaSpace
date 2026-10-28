import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Keys
    private enum ID {
        static let continuationPrefix = "luma.continue."
        static let postScan           = "luma.postscan"
        static let postDesign         = "luma.postdesign"
        static let weeklyInspiration  = "luma.weekly"
        static let designsReady       = "luma.designs.ready"
    }

    // MARK: - Permission

    /// Call after the user sees their first AI design result — they've seen value, prime moment.
    func requestPermissionIfNeeded() async {
        let status = await center.notificationSettings()
        guard status.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    @discardableResult
    func requestPermission() async -> Bool {
        do { return try await center.requestAuthorization(options: [.alert, .badge, .sound]) }
        catch { return false }
    }

    // MARK: - App Lifecycle Hooks

    /// Call on sceneDidBecomeActive / applicationDidBecomeActive — cancel "come back" notification.
    @MainActor func handleAppForegrounded() {
        cancelContinuationNotifications()
    }

    /// Call on sceneWillResignActive / applicationWillResignActive — schedule "come back" nudge.
    @MainActor func handleAppBackgrounded() {
        scheduleContinuationIfNeeded()
    }

    // MARK: - Project Continuation (2-day re-engagement)

    @MainActor private func scheduleContinuationIfNeeded() {
        let projects = ProjectStore.shared.projects
        guard let latest = projects.sorted(by: { $0.updatedAt > $1.updatedAt }).first else { return }

        Task {
            guard await isAuthorized() else { return }
            cancelContinuationNotifications()

            let content = UNMutableNotificationContent()
            content.title = "Your space is waiting ✦"
            content.body  = "\"\(latest.name)\" is ready for its next design update."
            content.sound = .default
            content.userInfo = [
                "type"      : "project.continue",
                "projectId" : latest.id.uuidString
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)
            let request  = UNNotificationRequest(
                identifier : ID.continuationPrefix + latest.id.uuidString,
                content    : content,
                trigger    : trigger
            )
            try? await center.add(request)
        }
    }

    func cancelContinuationNotifications() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(NotificationService.ID.continuationPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Post-Scan Nudge (4 hours — "generate your designs")

    func schedulePostScanNudge(projectName: String) {
        Task {
            guard await isAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Room scanned!"
            content.body  = "Ready to see what AI can design for \"\(projectName)\"? Tap to generate."
            content.sound = .default
            content.userInfo = ["type": "designs"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4 * 3600, repeats: false)
            let request  = UNNotificationRequest(identifier: ID.postScan, content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [ID.postScan])
            try? await center.add(request)
        }
    }

    // MARK: - Post-Design Nudge (24 hours — "try AR placement")

    func schedulePostDesignNudge() {
        Task {
            guard await isAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = "See it in your room"
            content.body  = "Your AI designs are ready. Place furniture in AR to see how it all fits."
            content.sound = .default
            content.userInfo = ["type": "ar"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 3600, repeats: false)
            let request  = UNNotificationRequest(identifier: ID.postDesign, content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [ID.postDesign])
            try? await center.add(request)
        }
    }

    // MARK: - Weekly Inspiration (Sunday 10 AM)

    func scheduleWeeklyInspiration() {
        Task {
            guard await isAuthorized() else { return }
            var components    = DateComponents()
            components.weekday = 1
            components.hour    = 10

            let content = UNMutableNotificationContent()
            content.title = "Weekend design inspiration"
            content.body  = "Start fresh — scan a new room or refine an existing design."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request  = UNNotificationRequest(identifier: ID.weeklyInspiration, content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [ID.weeklyInspiration])
            try? await center.add(request)
        }
    }

    // MARK: - Designs Ready (instant, suppressed in foreground)

    func scheduleDesignsReadyNotification(styleCount: Int) {
        Task {
            guard await isAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your designs are ready"
            content.body  = styleCount == 1
                ? "Your AI concept is ready to view."
                : "\(styleCount) AI concepts have been created for your room."
            content.sound = .default
            content.categoryIdentifier = "DESIGNS_READY"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request  = UNNotificationRequest(
                identifier : ID.designsReady + ".\(UUID().uuidString)",
                content    : content,
                trigger    : trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Price Drop Alert

    func schedulePriceDropAlert(product: CatalogProduct, currentPrice: Double) {
        Task {
            guard await isAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Price Drop: \(product.name)"
            content.body = "\(product.brand) dropped to $\(Int(currentPrice)). Tap to shop."
            content.sound = .default
            content.userInfo = ["type": "price_drop", "productId": product.id.uuidString]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "luma.price_drop.\(product.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Helpers

    private func isAuthorized() async -> Bool {
        let s = await center.notificationSettings()
        return s.authorizationStatus == .authorized
    }

    func cancelAll() { center.removeAllPendingNotificationRequests() }
}
