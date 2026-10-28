import Foundation
import UIKit

final class ReferralService {
    static let shared = ReferralService()

    private let codeKey  = "lumaspace_referral_code"
    private let countKey = "lumaspace_referral_count"

    var myCode: String {
        if let existing = UserDefaults.standard.string(forKey: codeKey) { return existing }
        let code = "LUMA-" + UUID().uuidString.prefix(6).uppercased()
        UserDefaults.standard.set(code, forKey: codeKey)
        return code
    }

    var referralCount: Int {
        get { UserDefaults.standard.integer(forKey: countKey) }
        set { UserDefaults.standard.set(newValue, forKey: countKey) }
    }

    // Deep-link share URL — replace with your actual domain
    var shareURL: URL {
        URL(string: "https://lumaspace.app/join?ref=\(myCode)")!
    }

    func shareCode(from viewController: UIViewController?) {
        let message = """
        Design your home with AI — try LumaSpace free!
        Download the app and use my invite code \(myCode) when you sign up.
        \(shareURL.absoluteString)
        """
        let vc = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        viewController?.present(vc, animated: true)
        AnalyticsService.shared.track(.referralCodeShared, properties: ["code": myCode])
    }

    // Called when app opens with a referral deep link
    func redeem(code: String) {
        guard code != myCode else { return }      // can't redeem own code
        AnalyticsService.shared.track(.referralCodeRedeemed, properties: ["code": code])
        // In production: validate code server-side, then extend subscription via StoreKit promotional offer
        UserDefaults.standard.set(true, forKey: "referral_redeemed_\(code)")
    }
}
