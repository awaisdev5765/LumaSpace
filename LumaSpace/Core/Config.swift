import Foundation

// MARK: - App Configuration

enum Config {
    // Never commit API keys to source control. Inject this value through your
    // local build configuration or a secure backend before enabling AI calls.
    static let openAIKey = ""

    static var isUsingDefaultKey: Bool { false }
    static var hasAPIKey: Bool { !openAIKey.isEmpty && openAIKey != "YOUR_OPENAI_API_KEY_HERE" }

    // Models
    static let chatModel  = "gpt-4o"
    static let imageModel = "dall-e-3"

    // Feature flags
    static let enableFutureVision     = true
    static let enableVirtualStaging   = true
    static let enableDesignerCollab   = false   // Phase 2
    // Set to true only after iCloud entitlements are added in Xcode + container
    // registered at developer.apple.com → Identifiers → iCloud Containers
    static let cloudKitEnabled        = false

    // Analytics
    static let analyticsEnabled = true

    // App Store / support
    // ⚠️ Set this once your listing is live in App Store Connect:
    //    appstoreconnect.apple.com → Your App → General → App Information → Apple ID
    static let appStoreID = ""  // e.g. "1234567890"

    static var appStoreURL: URL? {
        guard !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    static var appStoreReviewURL: URL? {
        guard !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    // Marketing website — used as the "Property URL" in Impact.com while the
    // App Store listing is pending. Once live, update your Impact.com property
    // to the real appStoreURL above (dashboard → Properties → Edit).
    static let marketingURL = URL(string: "https://lumaspace.app")!

    static let supportEmail = "support@lumaspace.app"
    static let privacyURL   = "https://lumaspace.app/privacy"
    static let termsURL     = "https://lumaspace.app/terms"
    static let helpURL      = "https://lumaspace.app/help"

    // MARK: - Affiliate IDs
    //
    // HOW TO FILL THESE IN:
    //
    // 1. AMAZON ASSOCIATES (associates.amazon.com)
    //    After approval, go to: Associates Central → Tools → Product Links
    //    Your tracking ID looks like "yourname-20"
    //    Paste it into amazonAssociatesID below.
    //
    // 2. IMPACT.COM (wayfair, west elm, article, pottery barn, cb2, target)
    //    For the "Property URL" during registration, use https://lumaspace.app
    //    (impact.com accepts a website URL while your App Store listing is pending)
    //    After each retailer partnership is approved:
    //    → Go to impact.com → Partners → [Retailer] → Links → Create Deeplink
    //    → Copy the "Publisher ID" shown in the deeplink URL — it is a number like 1234567
    //    → Paste it into the matching field below.
    //    The deeplink format impact.com gives you will be:
    //    https://[retailer-click-domain]/click-PUBLISHER_ID-PROGRAM_ID
    //    Paste the full base click URL (without ?url=...) into the field below.
    //
    // 3. IKEA (partnerize.com)
    //    After approval they send you a campaign key. Paste it into ikeaCampaignKey.

    enum Affiliate {
        // Amazon Associates — tracking ID (e.g. "lumaspace-20")
        static let amazonID = ""

        // Impact.com — base click URLs per retailer (without trailing ?url=...)
        // Example: "https://www.jdoqocy.com/click-1234567-8901234"
        static let wayfairClickURL     = ""
        static let westElmClickURL     = ""
        static let articleClickURL     = ""
        static let potteryBarnClickURL = ""
        static let cb2ClickURL         = ""
        static let targetClickURL      = ""

        // Partnerize — IKEA campaign key
        static let ikeaCampaignKey = ""
    }
}
