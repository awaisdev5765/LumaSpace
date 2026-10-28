import SwiftUI
import StoreKit

/// Tracks scan completions and AI redesign usage separately from AppState,
/// which now focuses on navigation/UI state only.
@MainActor
final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @AppStorage("totalScansCompleted") var totalScansCompleted = 0
    @AppStorage("hasRequestedReview") var hasRequestedReview = false
    @AppStorage("aiRedesignCount") var aiRedesignCount = 0
    @AppStorage("aiRedesignResetMonth") private var aiRedesignResetMonth = ""

    var isAtRedesignLimit: Bool {
        resetIfNeeded()
        return aiRedesignCount >= (SubscriptionTier.free.maxAIRedesigns ?? Int.max)
    }

    func recordRedesignUsed() {
        resetIfNeeded()
        aiRedesignCount += 1
    }

    func recordScanCompleted(in windowScene: UIWindowScene?) {
        totalScansCompleted += 1
        AnalyticsService.shared.track(.scanCompleted, properties: ["total": totalScansCompleted])
        SpotlightService.shared.indexAllProjects()
        if totalScansCompleted == 3 && !hasRequestedReview, let scene = windowScene {
            SKStoreReviewController.requestReview(in: scene)
            hasRequestedReview = true
        }
        let projectName = ProjectStore.shared.projects.sorted { $0.updatedAt > $1.updatedAt }.first?.name ?? "your room"
        NotificationService.shared.schedulePostScanNudge(projectName: projectName)
    }

    private func resetIfNeeded() {
        let currentMonth = Date.now.formatted(.dateTime.year().month())
        if aiRedesignResetMonth != currentMonth {
            aiRedesignCount = 0
            aiRedesignResetMonth = currentMonth
        }
    }
}
