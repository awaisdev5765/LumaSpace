import Foundation

final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    func track(_ event: Event, properties: [String: Any] = [:]) {
        #if DEBUG
        var log = "[Analytics] \(event.rawValue)"
        if !properties.isEmpty { log += " \(properties)" }
        print(log)
        #else
        // Route to your analytics backend here (Mixpanel, Amplitude, PostHog…)
        // Example: Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
        #endif
    }

    enum Event: String {
        // App lifecycle
        case appLaunched            = "app_launched"
        case notificationsEnabled   = "notifications_enabled"

        // Onboarding
        case onboardingStarted      = "onboarding_started"
        case onboardingCompleted    = "onboarding_completed"
        case paywallViewed          = "paywall_viewed"
        case paywallDismissed       = "paywall_dismissed"
        case trialStarted           = "trial_started"

        // Projects
        case projectCreated         = "project_created"
        case projectShared          = "project_shared"
        case projectDeleted         = "project_deleted"

        // Scans
        case scanStarted            = "scan_started"
        case scanCompleted          = "scan_completed"
        case scanCancelled          = "scan_cancelled"
        case scanFailed             = "scan_failed"

        // Designs
        case designGenerated        = "design_generated"
        case designFavorited        = "design_favorited"
        case designExported         = "design_exported"
        case designShared           = "design_shared"
        case styleSelected          = "style_selected"
        case futureVisionGenerated  = "future_vision_generated"
        case futureVisionSaved      = "future_vision_saved"
        case virtualStagingStarted  = "virtual_staging_started"

        // AR
        case arSessionStarted       = "ar_session_started"
        case furniturePlaced        = "furniture_placed"
        case furnitureRemoved       = "furniture_removed"
        case layoutSaved            = "layout_saved"
        case fitWarningShown        = "fit_warning_shown"
        case measurementToggled     = "measurement_toggled"
        case wallColorChanged       = "wall_color_changed"

        // Shopping
        case furnitureViewed        = "furniture_viewed"
        case furnitureAffiliateTap  = "furniture_affiliate_tap"
        case furnitureSaved         = "furniture_saved"

        // Subscription
        case purchaseInitiated      = "purchase_initiated"
        case purchaseCompleted      = "purchase_completed"
        case purchaseFailed         = "purchase_failed"
        case purchaseRestored       = "purchase_restored"

        // Engagement
        case moodboardItemAdded     = "moodboard_item_added"
        case budgetPlanCreated      = "budget_plan_created"
        case referralCodeShared     = "referral_code_shared"
        case referralCodeRedeemed   = "referral_code_redeemed"
        case feedbackSubmitted      = "feedback_submitted"
        case searchPerformed        = "search_performed"
        case spotlightOpened        = "spotlight_opened"
    }
}
