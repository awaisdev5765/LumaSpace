import Foundation

// MARK: - Affiliate Service
//
// Converts a plain retailer search URL into a commission-earning affiliate link.
//
// Revenue flow:
//   User taps "Shop on Wayfair" → affiliateURL(for:) wraps the URL in your
//   Impact.com click URL → browser opens → user buys → Impact credits commission.
//
// Fill in Config.Affiliate IDs to activate each retailer. When an ID is empty,
// the plain search URL is returned so the button still works while pending approval.

final class AffiliateService {
    static let shared = AffiliateService()
    private init() {}

    // MARK: - Primary entry point
    //
    // Call this on every "Shop" button tap. Pass the retailer search URL already
    // built by FurnitureItem.shoppingURL or CatalogProduct.shoppingURL.
    // Returns a commission-tracked URL when an affiliate ID is configured,
    // or the plain URL as a fallback.

    func affiliateURL(for url: URL, retailer: String, itemName: String) -> URL {
        let retailerKey = retailer.lowercased().trimmingCharacters(in: .whitespaces)

        switch retailerKey {
        case "amazon":
            return amazonURL(from: url)
        case "wayfair":
            return impactURL(baseClick: Config.Affiliate.wayfairClickURL,
                             destination: url, retailer: retailer, item: itemName)
        case "west elm", "westelm":
            return impactURL(baseClick: Config.Affiliate.westElmClickURL,
                             destination: url, retailer: retailer, item: itemName)
        case "article":
            return impactURL(baseClick: Config.Affiliate.articleClickURL,
                             destination: url, retailer: retailer, item: itemName)
        case "pottery barn", "potterybarn":
            return impactURL(baseClick: Config.Affiliate.potteryBarnClickURL,
                             destination: url, retailer: retailer, item: itemName)
        case "cb2":
            return impactURL(baseClick: Config.Affiliate.cb2ClickURL,
                             destination: url, retailer: retailer, item: itemName)
        case "target":
            return impactURL(baseClick: Config.Affiliate.targetClickURL,
                             destination: url, retailer: retailer, item: itemName)
        case "ikea":
            return ikeaURL(from: url)
        default:
            return utmTagged(url, retailer: retailer, item: itemName)
        }
    }

    // MARK: - Amazon Associates
    //
    // Appends ?tag=YOUR_ID to any amazon.com URL.
    // Earns 3–4% on anything the user buys within 24 hours of clicking.

    private func amazonURL(from url: URL) -> URL {
        guard !Config.Affiliate.amazonID.isEmpty else {
            return utmTagged(url, retailer: "amazon", item: "")
        }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        items.removeAll { $0.name == "tag" }
        items.append(URLQueryItem(name: "tag", value: Config.Affiliate.amazonID))
        comps?.queryItems = items
        return comps?.url ?? url
    }

    // MARK: - Impact.com Deeplink
    //
    // Impact.com tracks clicks via a redirect:
    //   https://[click-domain]/click-PUBLISHER_ID-PROGRAM_ID?url=ENCODED_DESTINATION
    //
    // baseClick = the full base URL they show in your Impact dashboard under
    //             Partners → [Retailer] → Links → Deeplink. Do NOT include ?url=...
    //             Example: "https://www.jdoqocy.com/click-1234567-8901234"
    //
    // When baseClick is empty (not yet approved), returns the plain search URL
    // with UTM params so analytics still works.

    private func impactURL(baseClick: String, destination: URL,
                           retailer: String, item: String) -> URL {
        guard !baseClick.isEmpty,
              let encodedDest = destination.absoluteString
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let result = URL(string: "\(baseClick)?url=\(encodedDest)&utm_content=\(slug(item))")
        else {
            return utmTagged(destination, retailer: retailer, item: item)
        }
        return result
    }

    // MARK: - IKEA Partnerize
    //
    // Partnerize deeplink format:
    //   https://prf.hn/click/camref:CAMPAIGN_KEY/destination:ENCODED_URL

    private func ikeaURL(from url: URL) -> URL {
        guard !Config.Affiliate.ikeaCampaignKey.isEmpty,
              let encodedDest = url.absoluteString
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let result = URL(string: "https://prf.hn/click/camref:\(Config.Affiliate.ikeaCampaignKey)/destination:\(encodedDest)")
        else {
            return utmTagged(url, retailer: "ikea", item: "")
        }
        return result
    }

    // MARK: - UTM fallback (analytics only, no commission)
    //
    // Used when an affiliate ID is not yet configured. At minimum this lets
    // you see traffic volume in Google Analytics / retailer dashboards.

    private func utmTagged(_ url: URL, retailer: String, item: String) -> URL {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        let utms: [URLQueryItem] = [
            .init(name: "utm_source",   value: "lumaspace"),
            .init(name: "utm_medium",   value: "app"),
            .init(name: "utm_campaign", value: "furniture"),
            .init(name: "utm_content",  value: slug(item)),
        ]
        items.removeAll { utms.map(\.name).contains($0.name) }
        items.append(contentsOf: utms)
        comps?.queryItems = items
        return comps?.url ?? url
    }

    private func slug(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
