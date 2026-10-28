import Foundation
import SwiftUI

// MARK: - Catalog Product

struct CatalogProduct: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var brand: String
    var category: FurnitureItem.Category
    var subcategory: String
    var price: Double
    var originalPrice: Double?
    var colorOptions: [String]
    var dimensions: FurnitureItem.Dimensions
    var productDescription: String
    var compatibleStyles: [DesignStyle]
    var retailer: String
    var searchQuery: String
    var tags: [String]
    var isNew: Bool = false
    var isTrending: Bool = false
    var rating: Double = 4.5
    var reviewCount: Int = 0
    var inStock: Bool = true
    var imageURL: URL? = nil

    var isOnSale: Bool { originalPrice != nil }
    var discountPercent: Int? {
        guard let orig = originalPrice, orig > price else { return nil }
        return Int(((orig - price) / orig) * 100)
    }

    var priceRange: PriceRange {
        switch price {
        case 0..<200:    return .budget
        case 200..<800:  return .mid
        case 800..<2000: return .premium
        default:         return .luxury
        }
    }

    enum PriceRange: String, CaseIterable, Codable {
        case budget  = "Under $200"
        case mid     = "$200–$800"
        case premium = "$800–$2,000"
        case luxury  = "$2,000+"

        var icon: String {
            switch self {
            case .budget:  return "tag"
            case .mid:     return "tag.fill"
            case .premium: return "star"
            case .luxury:  return "crown"
            }
        }
    }

    var shoppingURL: URL? { rawRetailerURL }

    /// Affiliate-wrapped URL — call this on the buy button tap.
    func affiliateShoppingURL() -> URL? {
        guard let base = rawRetailerURL else { return nil }
        return AffiliateService.shared.affiliateURL(for: base, retailer: retailer, itemName: name)
    }

    private var rawRetailerURL: URL? {
        guard let q = searchQuery
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let base: String
        switch retailer.lowercased() {
        case "ikea":            base = "https://www.ikea.com/us/en/search/?q=\(q)"
        case "west elm":        base = "https://www.westelm.com/search/results.html?words=\(q)"
        case "cb2":             base = "https://www.cb2.com/search?query=\(q)"
        case "pottery barn":    base = "https://www.potterybarn.com/search/results.html?words=\(q)"
        case "article":         base = "https://www.article.com/search?q=\(q)"
        case "target":          base = "https://www.target.com/s?searchTerm=\(q)"
        case "amazon":          base = "https://www.amazon.com/s?k=\(q)"
        case "wayfair":         base = "https://www.wayfair.com/keyword.php?keyword=\(q)"
        case "rh":              base = "https://rh.com/search/results.jsp?q=\(q)"
        case "crate & barrel":  base = "https://www.crateandbarrel.com/search/results.html?q=\(q)"
        case "anthropologie":   base = "https://www.anthropologie.com/search?q=\(q)"
        case "joss & main":     base = "https://www.jossandmain.com/search.html?q=\(q)"
        default:                base = "https://www.google.com/search?tbm=shop&q=furniture+\(q)"
        }
        return URL(string: base)
    }

    func toFurnitureItem() -> FurnitureItem {
        FurnitureItem(
            name: name,
            category: category,
            dimensions: dimensions,
            brand: brand,
            price: price,
            colorOptions: colorOptions,
            retailer: retailer,
            searchQuery: searchQuery
        )
    }
}

// MARK: - Style Pack

struct StylePack: Identifiable {
    var id = UUID()
    var style: DesignStyle
    var items: [CatalogProduct]
    var totalPrice: Double { items.reduce(0) { $0 + $1.price } }
    var description: String
}

// MARK: - Furniture Catalog Service

@MainActor
final class FurnitureCatalogService: ObservableObject {
    static let shared = FurnitureCatalogService()

    @Published var searchText = ""
    @Published var selectedCategory: FurnitureItem.Category?
    @Published var selectedPriceRange: CatalogProduct.PriceRange?
    @Published var selectedRetailer: String?
    @Published var selectedStyle: DesignStyle?
    @Published var wishlistIDs: Set<UUID> = []

    private init() {
        loadWishlist()
        loadPriceAlerts()
    }

    // MARK: - Full Catalog (101 products)

    let allProducts: [CatalogProduct] = CatalogData.all

    // MARK: - Filtered Results

    var filteredProducts: [CatalogProduct] {
        var results = allProducts
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText) ||
                $0.subcategory.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if let cat = selectedCategory { results = results.filter { $0.category == cat } }
        if let pr  = selectedPriceRange { results = results.filter { $0.priceRange == pr } }
        if let ret = selectedRetailer { results = results.filter { $0.retailer.lowercased() == ret.lowercased() } }
        if let sty = selectedStyle { results = results.filter { $0.compatibleStyles.contains(sty) } }
        return results
    }

    var trendingProducts: [CatalogProduct] {
        allProducts.filter(\.isTrending)
    }

    var newArrivals: [CatalogProduct] {
        allProducts.filter(\.isNew)
    }

    var allRetailers: [String] {
        Array(Set(allProducts.map(\.retailer))).sorted()
    }

    // MARK: - Style Packs

    var stylePacks: [StylePack] {
        ([.japandi, .scandinavian, .modernLuxury, .industrial, .coastal, .bohemian, .midCentury, .farmhouse] as [DesignStyle])
            .compactMap { style -> StylePack? in
                let items = allProducts.filter { $0.compatibleStyles.contains(style) }
                    .sorted { $0.isTrending && !$1.isTrending }
                    .prefix(6)
                guard !items.isEmpty else { return nil }
                return StylePack(
                    style: style,
                    items: Array(items),
                    description: "Complete the \(style.rawValue) look"
                )
            }
    }

    func stylePack(for style: DesignStyle) -> StylePack? {
        let items = allProducts.filter { $0.compatibleStyles.contains(style) }
            .sorted { $0.isTrending && !$1.isTrending }
            .prefix(8)
        guard !items.isEmpty else { return nil }
        return StylePack(style: style, items: Array(items), description: "Complete the \(style.rawValue) look")
    }

    func products(for style: DesignStyle) -> [CatalogProduct] {
        allProducts.filter { $0.compatibleStyles.contains(style) }
    }

    // MARK: - Wishlist

    func toggleWishlist(_ product: CatalogProduct) {
        if wishlistIDs.contains(product.id) {
            wishlistIDs.remove(product.id)
        } else {
            wishlistIDs.insert(product.id)
        }
        saveWishlist()
    }

    func isWishlisted(_ product: CatalogProduct) -> Bool {
        wishlistIDs.contains(product.id)
    }

    var wishlistProducts: [CatalogProduct] {
        allProducts.filter { wishlistIDs.contains($0.id) }
    }

    private func saveWishlist() {
        let ids = Array(wishlistIDs).map(\.uuidString)
        UserDefaults.standard.set(ids, forKey: "catalog.wishlist")
    }

    private func loadWishlist() {
        let ids = UserDefaults.standard.stringArray(forKey: "catalog.wishlist") ?? []
        wishlistIDs = Set(ids.compactMap(UUID.init))
    }

    // MARK: - Recently Viewed

    @Published var recentlyViewedIDs: [UUID] = []

    func recordView(_ product: CatalogProduct) {
        recentlyViewedIDs.removeAll { $0 == product.id }
        recentlyViewedIDs.insert(product.id, at: 0)
        if recentlyViewedIDs.count > 20 { recentlyViewedIDs = Array(recentlyViewedIDs.prefix(20)) }
    }

    var recentlyViewed: [CatalogProduct] {
        recentlyViewedIDs.compactMap { id in allProducts.first { $0.id == id } }
    }

    // MARK: - Price Alerts

    @Published var priceAlerts: [UUID: Double] = [:]

    func setPriceAlert(for product: CatalogProduct, targetPrice: Double) {
        priceAlerts[product.id] = targetPrice
        savePriceAlerts()
    }

    func removePriceAlert(for product: CatalogProduct) {
        priceAlerts.removeValue(forKey: product.id)
        savePriceAlerts()
    }

    func hasPriceAlert(for product: CatalogProduct) -> Bool {
        priceAlerts[product.id] != nil
    }

    func targetPrice(for product: CatalogProduct) -> Double? {
        priceAlerts[product.id]
    }

    /// Call on each app launch to fire notifications for products now at or below their target price.
    func checkPriceAlerts() {
        var triggered: [UUID] = []
        for (id, target) in priceAlerts {
            guard let product = allProducts.first(where: { $0.id == id }) else { continue }
            if product.price <= target {
                NotificationService.shared.schedulePriceDropAlert(product: product, currentPrice: product.price)
                triggered.append(id)
            }
        }
        triggered.forEach { priceAlerts.removeValue(forKey: $0) }
        if !triggered.isEmpty { savePriceAlerts() }
    }

    private func savePriceAlerts() {
        let dict = Dictionary(uniqueKeysWithValues: priceAlerts.map { ($0.key.uuidString, $0.value) })
        UserDefaults.standard.set(dict, forKey: "catalog.priceAlerts")
    }

    private func loadPriceAlerts() {
        let dict = UserDefaults.standard.dictionary(forKey: "catalog.priceAlerts") as? [String: Double] ?? [:]
        priceAlerts = Dictionary(uniqueKeysWithValues: dict.compactMap { k, v -> (UUID, Double)? in
            guard let id = UUID(uuidString: k) else { return nil }
            return (id, v)
        })
    }

    // MARK: - Filters

    func clearFilters() {
        selectedCategory = nil
        selectedPriceRange = nil
        selectedRetailer = nil
        selectedStyle = nil
        searchText = ""
    }
}

// MARK: - Catalog Data (101 products)

private enum CatalogData {
    static let all: [CatalogProduct] = sofas + chairs + tables + beds + desks + storage + lighting + rugs + decor + plants

    // MARK: Sofas (15)
    static let sofas: [CatalogProduct] = [
        CatalogProduct(name: "KIVIK 3-Seat Sofa", brand: "IKEA", category: .sofa, subcategory: "3-Seater",
            price: 599, colorOptions: ["Beige", "Grey", "Dark Grey", "Natural"],
            dimensions: .init(width: 2.28, depth: 0.95, height: 0.83),
            productDescription: "Clean Scandinavian lines with deep seating and removable covers.",
            compatibleStyles: [.japandi, .scandinavian, .minimalist],
            retailer: "IKEA", searchQuery: "KIVIK 3-seat sofa",
            tags: ["sofa", "3-seater", "washable", "scandinavian"], isTrending: true, rating: 4.4, reviewCount: 3821),

        CatalogProduct(name: "Andes Sofa", brand: "Article", category: .sofa, subcategory: "Sofa",
            price: 1299, originalPrice: 1599,
            colorOptions: ["Charcoal", "Beige", "Rust", "Sage"],
            dimensions: .init(width: 2.08, depth: 0.91, height: 0.79),
            productDescription: "Mid-century silhouette with tapered wood legs and plush cushioning.",
            compatibleStyles: [.contemporary, .midCentury, .scandinavian],
            retailer: "Article", searchQuery: "Andes sofa",
            tags: ["sofa", "mid-century", "wood legs", "on sale"], isNew: false, isTrending: true, rating: 4.7, reviewCount: 1245),

        CatalogProduct(name: "Harmony Modular Sofa", brand: "West Elm", category: .sofa, subcategory: "Sectional",
            price: 2399, colorOptions: ["Natural Linen", "Dove Grey", "Oatmeal"],
            dimensions: .init(width: 2.74, depth: 1.02, height: 0.81),
            productDescription: "Modular design lets you configure to fit any living space.",
            compatibleStyles: [.contemporary, .organicModern, .coastal],
            retailer: "West Elm", searchQuery: "Harmony modular sofa",
            tags: ["sofa", "modular", "sectional", "linen"], rating: 4.5, reviewCount: 892),

        CatalogProduct(name: "Haven Sofa", brand: "CB2", category: .sofa, subcategory: "Sofa",
            price: 1849, colorOptions: ["Charcoal", "Cream", "Black"],
            dimensions: .init(width: 2.18, depth: 0.97, height: 0.74),
            productDescription: "Low-profile modern sofa with tight upholstery and solid steel legs.",
            compatibleStyles: [.modernLuxury, .industrial, .minimalist],
            retailer: "CB2", searchQuery: "Haven sofa CB2",
            tags: ["sofa", "modern", "low profile", "steel legs"], rating: 4.3, reviewCount: 432),

        CatalogProduct(name: "Comfort Roll-Arm Sofa", brand: "Pottery Barn", category: .sofa, subcategory: "Sofa",
            price: 1799, colorOptions: ["Cream", "Grey", "Navy", "White"],
            dimensions: .init(width: 2.13, depth: 0.99, height: 0.89),
            productDescription: "Classic roll-arm silhouette with deep cushions for everyday comfort.",
            compatibleStyles: [.farmhouse, .coastal, .grandmillennial],
            retailer: "Pottery Barn", searchQuery: "Comfort roll arm sofa",
            tags: ["sofa", "classic", "roll arm", "comfortable"], isTrending: true, rating: 4.6, reviewCount: 2103),

        CatalogProduct(name: "SÖDERHAMN Sofa", brand: "IKEA", category: .sofa, subcategory: "Sofa",
            price: 499, colorOptions: ["Grey", "Beige", "Dark Grey"],
            dimensions: .init(width: 1.91, depth: 0.99, height: 0.83),
            productDescription: "Low, airy design with chaise and detachable armrest.",
            compatibleStyles: [.minimalist, .scandinavian, .japandi],
            retailer: "IKEA", searchQuery: "SODERHAMN sofa IKEA",
            tags: ["sofa", "budget", "chaise", "minimalist"], rating: 4.2, reviewCount: 5102),

        CatalogProduct(name: "Sven Sofa", brand: "Article", category: .sofa, subcategory: "Sofa",
            price: 1499, colorOptions: ["Charcoal", "Ochre", "Ivory", "Dusty Blue"],
            dimensions: .init(width: 2.11, depth: 0.92, height: 0.78),
            productDescription: "Retro-inspired with slim tapered legs and button-tufted back cushions.",
            compatibleStyles: [.midCentury, .japandi, .scandinavian],
            retailer: "Article", searchQuery: "Sven sofa Article",
            tags: ["sofa", "retro", "tufted", "wood legs"], isNew: true, isTrending: true, rating: 4.8, reviewCount: 3567),

        CatalogProduct(name: "Rochester Roll-Arm Sofa", brand: "Wayfair", category: .sofa, subcategory: "Sofa",
            price: 899, colorOptions: ["Beige", "Grey", "Blue", "Green"],
            dimensions: .init(width: 2.03, depth: 0.91, height: 0.86),
            productDescription: "Transitional sofa with rolled arms and kiln-dried wood frame.",
            compatibleStyles: [.farmhouse, .coastal, .contemporary],
            retailer: "Wayfair", searchQuery: "Rochester roll arm sofa",
            tags: ["sofa", "transitional", "affordable"], rating: 4.1, reviewCount: 788),

        CatalogProduct(name: "ÄPPLARYD Sofa", brand: "IKEA", category: .sofa, subcategory: "Sofa",
            price: 799, colorOptions: ["Beige", "Grey", "Dark Brown"],
            dimensions: .init(width: 2.24, depth: 0.96, height: 0.77),
            productDescription: "Sustainable design with recycled filling and FSC-certified wood feet.",
            compatibleStyles: [.japandi, .minimalist, .organicModern],
            retailer: "IKEA", searchQuery: "APPLARYD sofa IKEA",
            tags: ["sofa", "sustainable", "eco", "japanese-inspired"], isNew: true, rating: 4.5, reviewCount: 612),

        CatalogProduct(name: "Milo Mid-Century Sofa", brand: "West Elm", category: .sofa, subcategory: "Sofa",
            price: 1699, colorOptions: ["Teal", "Rust", "Charcoal", "Blush"],
            dimensions: .init(width: 2.06, depth: 0.88, height: 0.81),
            productDescription: "Bold colors, angled legs, and clean silhouette define this showstopper.",
            compatibleStyles: [.midCentury, .bohemian, .contemporary],
            retailer: "West Elm", searchQuery: "Milo mid-century sofa West Elm",
            tags: ["sofa", "mid-century", "colorful", "show piece"], rating: 4.6, reviewCount: 1893),

        CatalogProduct(name: "Linden Sofa", brand: "Pottery Barn", category: .sofa, subcategory: "Sofa",
            price: 2299, colorOptions: ["White", "Grey", "Navy", "Natural"],
            dimensions: .init(width: 2.21, depth: 1.04, height: 0.86),
            productDescription: "Performance fabric resists stains and fading — great for families.",
            compatibleStyles: [.farmhouse, .coastal, .contemporary],
            retailer: "Pottery Barn", searchQuery: "Linden sofa Pottery Barn",
            tags: ["sofa", "performance fabric", "family-friendly", "durable"], isTrending: true, rating: 4.7, reviewCount: 2341),

        CatalogProduct(name: "Shelter Sofa", brand: "RH", category: .sofa, subcategory: "Sofa",
            price: 3499, colorOptions: ["Cream", "Charcoal", "Warm White", "Stone"],
            dimensions: .init(width: 2.44, depth: 1.07, height: 0.91),
            productDescription: "Bespoke luxury with hand-tied springs and premium down fill.",
            compatibleStyles: [.modernLuxury, .contemporary, .grandmillennial],
            retailer: "RH", searchQuery: "Shelter sofa RH",
            tags: ["sofa", "luxury", "down fill", "premium"], rating: 4.9, reviewCount: 347),

        CatalogProduct(name: "Luna 3-Piece Sectional", brand: "Wayfair", category: .sofa, subcategory: "Sectional",
            price: 1199, colorOptions: ["Grey", "Beige", "Blue", "Green"],
            dimensions: .init(width: 2.84, depth: 1.52, height: 0.84),
            productDescription: "Reversible chaise configures left or right to suit your space.",
            compatibleStyles: [.contemporary, .coastal, .minimalist],
            retailer: "Wayfair", searchQuery: "Luna sectional sofa",
            tags: ["sectional", "reversible", "L-shape", "modular"], isNew: true, rating: 4.3, reviewCount: 1102),

        CatalogProduct(name: "Paidge Sofa", brand: "West Elm", category: .sofa, subcategory: "Sofa",
            price: 1199, colorOptions: ["Natural", "Sage", "Mocha", "Charcoal"],
            dimensions: .init(width: 2.03, depth: 0.94, height: 0.79),
            productDescription: "Organic curves meet minimal profile in this sustainably-made sofa.",
            compatibleStyles: [.organicModern, .japandi, .biophilic],
            retailer: "West Elm", searchQuery: "Paidge sofa West Elm",
            tags: ["sofa", "organic", "sustainable", "curves"], isNew: true, isTrending: true, rating: 4.6, reviewCount: 823),

        CatalogProduct(name: "LANDSKRONA Sofa", brand: "IKEA", category: .sofa, subcategory: "Sofa",
            price: 899, colorOptions: ["Beige", "Grey", "Black", "Natural"],
            dimensions: .init(width: 2.33, depth: 0.93, height: 0.78),
            productDescription: "Generous seating with detachable armrests and easy-clean covers.",
            compatibleStyles: [.scandinavian, .minimalist, .japandi],
            retailer: "IKEA", searchQuery: "LANDSKRONA sofa IKEA",
            tags: ["sofa", "comfortable", "detachable arms", "washable"], rating: 4.4, reviewCount: 4211),
    ]

    // MARK: Chairs (12)
    static let chairs: [CatalogProduct] = [
        CatalogProduct(name: "POÄNG Armchair", brand: "IKEA", category: .chair, subcategory: "Armchair",
            price: 199, colorOptions: ["Natural", "Dark Brown", "Beige"],
            dimensions: .init(width: 0.68, depth: 0.82, height: 1.00),
            productDescription: "Iconic bent-wood armchair with cushioned seat — a Scandinavian classic.",
            compatibleStyles: [.scandinavian, .japandi, .minimalist],
            retailer: "IKEA", searchQuery: "POANG armchair IKEA",
            tags: ["chair", "armchair", "bent wood", "classic"], isTrending: true, rating: 4.6, reviewCount: 12043),

        CatalogProduct(name: "Swoop Armchair", brand: "West Elm", category: .chair, subcategory: "Accent Chair",
            price: 699, colorOptions: ["Grey", "Walnut", "Charcoal", "Teal"],
            dimensions: .init(width: 0.81, depth: 0.81, height: 0.81),
            productDescription: "Mid-century inspired with solid walnut legs and 360° swivel.",
            compatibleStyles: [.midCentury, .contemporary, .scandinavian],
            retailer: "West Elm", searchQuery: "Swoop armchair West Elm",
            tags: ["chair", "swivel", "mid-century", "armchair"], rating: 4.5, reviewCount: 892),

        CatalogProduct(name: "Papasan Chair", brand: "Target", category: .chair, subcategory: "Lounge Chair",
            price: 149, colorOptions: ["Natural", "Brown", "Black"],
            dimensions: .init(width: 0.91, depth: 0.91, height: 0.99),
            productDescription: "Round bowl-shaped chair with plush cushion — a boho essential.",
            compatibleStyles: [.bohemian, .coastal, .tropical],
            retailer: "Target", searchQuery: "Papasan chair round",
            tags: ["chair", "papasan", "boho", "round"], isTrending: true, rating: 4.2, reviewCount: 3421),

        CatalogProduct(name: "Lona Shell Chair", brand: "CB2", category: .chair, subcategory: "Accent Chair",
            price: 549, colorOptions: ["White", "Grey", "Black"],
            dimensions: .init(width: 0.71, depth: 0.71, height: 0.81),
            productDescription: "Sculptural fiberglass shell on polished chrome base.",
            compatibleStyles: [.contemporary, .minimalist, .artDeco],
            retailer: "CB2", searchQuery: "Lona shell chair CB2",
            tags: ["chair", "fiberglass", "sculptural", "chrome"], rating: 4.3, reviewCount: 234),

        CatalogProduct(name: "Barrel Accent Chair", brand: "Pottery Barn", category: .chair, subcategory: "Armchair",
            price: 899, colorOptions: ["Grey", "Beige", "Navy", "Cream"],
            dimensions: .init(width: 0.84, depth: 0.91, height: 0.79),
            productDescription: "Classic barrel silhouette with solid hardwood frame and plush cushions.",
            compatibleStyles: [.farmhouse, .coastal, .grandmillennial],
            retailer: "Pottery Barn", searchQuery: "barrel accent chair Pottery Barn",
            tags: ["chair", "barrel", "armchair", "classic"], rating: 4.7, reviewCount: 1234),

        CatalogProduct(name: "FRÖSET Armchair", brand: "IKEA", category: .chair, subcategory: "Armchair",
            price: 99, colorOptions: ["Ash", "Birch", "Black"],
            dimensions: .init(width: 0.57, depth: 0.58, height: 0.73),
            productDescription: "Solid ash frame with handwoven seat — FSC-certified sustainable wood.",
            compatibleStyles: [.japandi, .scandinavian, .minimalist, .wabiSabi],
            retailer: "IKEA", searchQuery: "FROSET armchair IKEA",
            tags: ["chair", "sustainable", "woven", "natural"], isNew: false, isTrending: true, rating: 4.5, reviewCount: 2341),

        CatalogProduct(name: "Tucker Chair", brand: "Article", category: .chair, subcategory: "Dining Chair",
            price: 499, colorOptions: ["Walnut", "Charcoal", "White Oak"],
            dimensions: .init(width: 0.56, depth: 0.62, height: 0.84),
            productDescription: "Upholstered dining chair on solid walnut base — works at desk or table.",
            compatibleStyles: [.midCentury, .industrial, .japandi],
            retailer: "Article", searchQuery: "Tucker dining chair Article",
            tags: ["chair", "dining", "upholstered", "walnut"], isTrending: true, rating: 4.6, reviewCount: 1567),

        CatalogProduct(name: "Carmen Chair", brand: "West Elm", category: .chair, subcategory: "Accent Chair",
            price: 799, colorOptions: ["Grey", "Blue", "Rust", "Mustard"],
            dimensions: .init(width: 0.79, depth: 0.79, height: 0.81),
            productDescription: "Velvet upholstery on solid wood legs — bold color options.",
            compatibleStyles: [.contemporary, .modernLuxury, .bohemian],
            retailer: "West Elm", searchQuery: "Carmen velvet chair West Elm",
            tags: ["chair", "velvet", "colorful", "accent"], rating: 4.4, reviewCount: 678),

        CatalogProduct(name: "KOARP Armchair", brand: "IKEA", category: .chair, subcategory: "Armchair",
            price: 349, colorOptions: ["Beige", "White", "Dark Grey"],
            dimensions: .init(width: 0.73, depth: 0.78, height: 0.81),
            productDescription: "Low-pile velvet upholstery on birch legs — great texture at this price.",
            compatibleStyles: [.japandi, .scandinavian, .minimalist],
            retailer: "IKEA", searchQuery: "KOARP armchair IKEA",
            tags: ["chair", "velvet", "birch", "affordable"], isNew: true, rating: 4.3, reviewCount: 891),

        CatalogProduct(name: "Paramont Chair", brand: "CB2", category: .chair, subcategory: "Lounge Chair",
            price: 649, colorOptions: ["Charcoal", "Grey", "Black"],
            dimensions: .init(width: 0.76, depth: 0.81, height: 0.79),
            productDescription: "Monochrome lounge chair with foam-wrapped frame and steel base.",
            compatibleStyles: [.industrial, .contemporary, .minimalist],
            retailer: "CB2", searchQuery: "Paramont lounge chair CB2",
            tags: ["chair", "lounge", "industrial", "modern"], rating: 4.1, reviewCount: 312),

        CatalogProduct(name: "Irving Swivel Chair", brand: "Pottery Barn", category: .chair, subcategory: "Swivel Chair",
            price: 999, colorOptions: ["Cream", "Grey", "Blue", "Natural"],
            dimensions: .init(width: 0.84, depth: 0.84, height: 0.84),
            productDescription: "360° swivel on a metal base — classic silhouette with performance fabric.",
            compatibleStyles: [.contemporary, .coastal, .farmhouse],
            retailer: "Pottery Barn", searchQuery: "Irving swivel chair Pottery Barn",
            tags: ["chair", "swivel", "performance fabric"], isTrending: true, rating: 4.6, reviewCount: 2103),

        CatalogProduct(name: "Tulip Accent Chair", brand: "Amazon", category: .chair, subcategory: "Accent Chair",
            price: 299, colorOptions: ["White", "Grey", "Black", "Cream"],
            dimensions: .init(width: 0.66, depth: 0.74, height: 0.84),
            productDescription: "Eero Saarinen-inspired design with single-pedestal base.",
            compatibleStyles: [.midCentury, .minimalist, .artDeco],
            retailer: "Amazon", searchQuery: "tulip accent chair mid-century pedestal",
            tags: ["chair", "mid-century", "pedestal", "iconic"], rating: 4.0, reviewCount: 5432),
    ]

    // MARK: Tables (12)
    static let tables: [CatalogProduct] = [
        CatalogProduct(name: "LACK Coffee Table", brand: "IKEA", category: .table, subcategory: "Coffee Table",
            price: 69, colorOptions: ["White", "Black", "Oak"],
            dimensions: .init(width: 0.90, depth: 0.55, height: 0.45),
            productDescription: "Simple and affordable — pairs with almost any sofa.",
            compatibleStyles: [.minimalist, .scandinavian, .contemporary],
            retailer: "IKEA", searchQuery: "LACK coffee table IKEA",
            tags: ["table", "coffee table", "affordable", "simple"], rating: 4.1, reviewCount: 8901),

        CatalogProduct(name: "Rowan Coffee Table", brand: "West Elm", category: .table, subcategory: "Coffee Table",
            price: 499, colorOptions: ["Walnut", "White", "Acacia"],
            dimensions: .init(width: 1.14, depth: 0.61, height: 0.46),
            productDescription: "Solid wood top with geometric metal base — a standout centerpiece.",
            compatibleStyles: [.japandi, .organicModern, .midCentury],
            retailer: "West Elm", searchQuery: "Rowan coffee table West Elm",
            tags: ["table", "coffee table", "solid wood", "metal base"], isTrending: true, rating: 4.7, reviewCount: 1234),

        CatalogProduct(name: "Marble Coffee Table", brand: "CB2", category: .table, subcategory: "Coffee Table",
            price: 999, colorOptions: ["White Marble", "Black Marble", "Travertine"],
            dimensions: .init(width: 1.07, depth: 0.56, height: 0.41),
            productDescription: "Genuine marble top on brushed brass base — pure luxury underfoot.",
            compatibleStyles: [.modernLuxury, .artDeco, .mediterranean],
            retailer: "CB2", searchQuery: "marble coffee table brass base",
            tags: ["table", "marble", "brass", "luxury"], isTrending: true, rating: 4.5, reviewCount: 532),

        CatalogProduct(name: "LISABO Dining Table", brand: "IKEA", category: .table, subcategory: "Dining Table",
            price: 249, colorOptions: ["Ash", "Bamboo", "Oak"],
            dimensions: .init(width: 1.40, depth: 0.78, height: 0.74),
            productDescription: "Natural veneer top with solid wood legs — seats 4 comfortably.",
            compatibleStyles: [.scandinavian, .minimalist, .japandi],
            retailer: "IKEA", searchQuery: "LISABO dining table IKEA",
            tags: ["table", "dining", "ash", "4-seat"], isNew: true, rating: 4.4, reviewCount: 3210),

        CatalogProduct(name: "Emmerson Dining Table", brand: "West Elm", category: .table, subcategory: "Dining Table",
            price: 1299, colorOptions: ["Burnt Wax", "Stone Grey", "Natural"],
            dimensions: .init(width: 1.83, depth: 0.91, height: 0.76),
            productDescription: "Reclaimed pine with distinct grain patterns — each piece is unique.",
            compatibleStyles: [.farmhouse, .industrial, .bohemian],
            retailer: "West Elm", searchQuery: "Emmerson reclaimed dining table West Elm",
            tags: ["table", "dining", "reclaimed wood", "farmhouse"], rating: 4.6, reviewCount: 987),

        CatalogProduct(name: "Pedestal Dining Table", brand: "Pottery Barn", category: .table, subcategory: "Dining Table",
            price: 1599, colorOptions: ["White", "Grey", "Black"],
            dimensions: .init(width: 1.83, depth: 0.91, height: 0.76),
            productDescription: "Single pedestal base for open legroom — classic proportions.",
            compatibleStyles: [.contemporary, .minimalist, .farmhouse],
            retailer: "Pottery Barn", searchQuery: "pedestal dining table Pottery Barn",
            tags: ["table", "dining", "pedestal", "classic"], rating: 4.5, reviewCount: 1432),

        CatalogProduct(name: "Live Edge Coffee Table", brand: "Wayfair", category: .table, subcategory: "Coffee Table",
            price: 599, colorOptions: ["Natural", "Walnut", "Honey Oak"],
            dimensions: .init(width: 1.22, depth: 0.61, height: 0.43),
            productDescription: "Solid wood slab with natural live edge preserved — truly one-of-a-kind.",
            compatibleStyles: [.organicModern, .biophilic, .wabiSabi],
            retailer: "Wayfair", searchQuery: "live edge coffee table solid wood",
            tags: ["table", "live edge", "solid wood", "natural", "organic"], isTrending: true, rating: 4.3, reviewCount: 678),

        CatalogProduct(name: "Mid-Century Side Table", brand: "Article", category: .table, subcategory: "Side Table",
            price: 299, colorOptions: ["Walnut", "Oak", "White"],
            dimensions: .init(width: 0.51, depth: 0.51, height: 0.61),
            productDescription: "Hairpin legs meet solid walnut top — a true mid-century icon.",
            compatibleStyles: [.midCentury, .contemporary, .japandi],
            retailer: "Article", searchQuery: "mid-century side table hairpin legs Article",
            tags: ["table", "side table", "hairpin legs", "walnut"], isTrending: true, rating: 4.8, reviewCount: 2341),

        CatalogProduct(name: "Nesting Tables Set of 3", brand: "CB2", category: .table, subcategory: "Side Table",
            price: 449, colorOptions: ["White", "Grey", "Black", "Walnut"],
            dimensions: .init(width: 0.64, depth: 0.38, height: 0.56),
            productDescription: "Lacquered nesting tables stack neatly when not in use.",
            compatibleStyles: [.minimalist, .contemporary, .artDeco],
            retailer: "CB2", searchQuery: "nesting tables set 3 CB2",
            tags: ["table", "side table", "nesting", "space-saving"], rating: 4.2, reviewCount: 321),

        CatalogProduct(name: "VITTSJÖ Coffee Table", brand: "IKEA", category: .table, subcategory: "Coffee Table",
            price: 79, colorOptions: ["Black", "White"],
            dimensions: .init(width: 1.00, depth: 0.60, height: 0.45),
            productDescription: "Tempered glass top on steel frame — light and open visual profile.",
            compatibleStyles: [.minimalist, .industrial, .scandinavian],
            retailer: "IKEA", searchQuery: "VITTSJO coffee table IKEA",
            tags: ["table", "glass", "steel", "minimalist", "budget"], rating: 4.0, reviewCount: 6789),

        CatalogProduct(name: "Chloe Round Dining Table", brand: "Target", category: .table, subcategory: "Dining Table",
            price: 249, colorOptions: ["Natural", "Grey", "Black"],
            dimensions: .init(width: 1.07, depth: 1.07, height: 0.76),
            productDescription: "Round pedestal table seats 4 — perfect for smaller dining spaces.",
            compatibleStyles: [.farmhouse, .contemporary, .coastal],
            retailer: "Target", searchQuery: "round dining table pedestal Target",
            tags: ["table", "dining", "round", "pedestal", "small space"], isNew: true, rating: 4.3, reviewCount: 1102),

        CatalogProduct(name: "Slab Side Table", brand: "CB2", category: .table, subcategory: "Side Table",
            price: 249, colorOptions: ["Black", "Grey", "White"],
            dimensions: .init(width: 0.46, depth: 0.46, height: 0.56),
            productDescription: "Geometric concrete-look table with powder-coated metal legs.",
            compatibleStyles: [.industrial, .minimalist, .nordicNoir],
            retailer: "CB2", searchQuery: "Slab side table CB2",
            tags: ["table", "side table", "concrete", "geometric"], rating: 4.1, reviewCount: 289),
    ]

    // MARK: Beds (10)
    static let beds: [CatalogProduct] = [
        CatalogProduct(name: "MALM Bed Frame", brand: "IKEA", category: .bed, subcategory: "Bed Frame",
            price: 249, colorOptions: ["White", "Oak", "Dark Brown", "Black-Brown"],
            dimensions: .init(width: 1.97, depth: 2.11, height: 1.00),
            productDescription: "Clean lined bed frame with under-bed storage option.",
            compatibleStyles: [.scandinavian, .minimalist, .japandi],
            retailer: "IKEA", searchQuery: "MALM bed frame IKEA Queen",
            tags: ["bed", "storage", "clean lines", "budget"], isTrending: true, rating: 4.3, reviewCount: 15432),

        CatalogProduct(name: "Palo Alto Platform Bed", brand: "CB2", category: .bed, subcategory: "Platform Bed",
            price: 1299, colorOptions: ["Walnut", "Grey", "Charcoal"],
            dimensions: .init(width: 1.83, depth: 2.13, height: 0.76),
            productDescription: "Low-slung walnut platform bed — modern and grounded.",
            compatibleStyles: [.industrial, .contemporary, .japandi],
            retailer: "CB2", searchQuery: "Palo Alto platform bed CB2",
            tags: ["bed", "platform", "walnut", "low profile"], rating: 4.6, reviewCount: 432),

        CatalogProduct(name: "Farmhouse Bed", brand: "Pottery Barn", category: .bed, subcategory: "Bed Frame",
            price: 1899, colorOptions: ["White", "Grey", "Weathered Oak"],
            dimensions: .init(width: 1.97, depth: 2.29, height: 1.52),
            productDescription: "Shiplap-inspired headboard with vintage hardware details.",
            compatibleStyles: [.farmhouse, .coastal, .grandmillennial],
            retailer: "Pottery Barn", searchQuery: "Farmhouse bed Pottery Barn",
            tags: ["bed", "farmhouse", "shiplap", "headboard"], rating: 4.7, reviewCount: 1892),

        CatalogProduct(name: "Callan Mid-Century Bed", brand: "Article", category: .bed, subcategory: "Bed Frame",
            price: 999, colorOptions: ["Walnut", "Oak", "Ebony"],
            dimensions: .init(width: 1.90, depth: 2.13, height: 1.22),
            productDescription: "Solid walnut frame with angled legs — a mid-century bedroom anchor.",
            compatibleStyles: [.midCentury, .scandinavian, .japandi],
            retailer: "Article", searchQuery: "Callan mid-century bed Article",
            tags: ["bed", "walnut", "mid-century", "angled legs"], isTrending: true, rating: 4.8, reviewCount: 1234),

        CatalogProduct(name: "Auburn Platform Bed", brand: "West Elm", category: .bed, subcategory: "Platform Bed",
            price: 1199, colorOptions: ["Natural", "Grey", "Walnut", "White"],
            dimensions: .init(width: 1.93, depth: 2.18, height: 0.99),
            productDescription: "FSC-certified solid wood with inset leg detail — no box spring needed.",
            compatibleStyles: [.japandi, .minimalist, .organicModern],
            retailer: "West Elm", searchQuery: "Auburn platform bed West Elm",
            tags: ["bed", "platform", "sustainable", "no box spring"], rating: 4.5, reviewCount: 2103),

        CatalogProduct(name: "TRYSIL Bed Frame", brand: "IKEA", category: .bed, subcategory: "Bed Frame",
            price: 329, colorOptions: ["White", "Dark Brown"],
            dimensions: .init(width: 1.90, depth: 2.12, height: 0.99),
            productDescription: "Simple pine frame with slatted base — easy assembly, great price.",
            compatibleStyles: [.scandinavian, .minimalist, .farmhouse],
            retailer: "IKEA", searchQuery: "TRYSIL bed frame IKEA",
            tags: ["bed", "pine", "simple", "affordable"], rating: 4.2, reviewCount: 8901),

        CatalogProduct(name: "Upholstered Panel Bed", brand: "Pottery Barn", category: .bed, subcategory: "Upholstered Bed",
            price: 2299, colorOptions: ["Cream", "Grey", "Navy", "Dusty Blue"],
            dimensions: .init(width: 1.97, depth: 2.18, height: 1.52),
            productDescription: "Tall upholstered headboard with nailhead trim — hotel-bedroom elegance.",
            compatibleStyles: [.modernLuxury, .coastal, .grandmillennial],
            retailer: "Pottery Barn", searchQuery: "upholstered panel bed Pottery Barn",
            tags: ["bed", "upholstered", "nailhead", "luxury"], isTrending: true, rating: 4.7, reviewCount: 3421),

        CatalogProduct(name: "Finley Bed", brand: "Article", category: .bed, subcategory: "Bed Frame",
            price: 1299, colorOptions: ["Walnut", "Natural"],
            dimensions: .init(width: 1.90, depth: 2.13, height: 1.07),
            productDescription: "Solid wood with organic curve details — a statement piece.",
            compatibleStyles: [.organicModern, .bohemian, .japandi],
            retailer: "Article", searchQuery: "Finley bed Article",
            tags: ["bed", "organic curves", "solid wood", "artisan"], isNew: true, rating: 4.6, reviewCount: 567),

        CatalogProduct(name: "BRIMNES Bed Frame", brand: "IKEA", category: .bed, subcategory: "Storage Bed",
            price: 399, colorOptions: ["White", "Black"],
            dimensions: .init(width: 1.60, depth: 2.09, height: 1.00),
            productDescription: "Two large drawers under the bed — maximise storage in small bedrooms.",
            compatibleStyles: [.scandinavian, .minimalist, .contemporary],
            retailer: "IKEA", searchQuery: "BRIMNES bed frame storage IKEA",
            tags: ["bed", "storage", "drawers", "small space"], rating: 4.1, reviewCount: 12103),

        CatalogProduct(name: "Nara Low Bed", brand: "Wayfair", category: .bed, subcategory: "Platform Bed",
            price: 499, colorOptions: ["Walnut", "Oak", "Grey"],
            dimensions: .init(width: 1.90, depth: 2.18, height: 0.61),
            productDescription: "Ultra-low profile platform bed inspired by Japanese sleeping culture.",
            compatibleStyles: [.japandi, .minimalist, .wabiSabi],
            retailer: "Wayfair", searchQuery: "low platform bed Japanese style",
            tags: ["bed", "low profile", "japanese", "platform"], isNew: true, isTrending: true, rating: 4.4, reviewCount: 789),
    ]

    // MARK: Desks (8)
    static let desks: [CatalogProduct] = [
        CatalogProduct(name: "MICKE Desk", brand: "IKEA", category: .desk, subcategory: "Writing Desk",
            price: 99, colorOptions: ["White", "Oak", "Black"],
            dimensions: .init(width: 1.05, depth: 0.50, height: 0.75),
            productDescription: "Compact desk with integrated drawer and cable management.",
            compatibleStyles: [.minimalist, .scandinavian, .contemporary],
            retailer: "IKEA", searchQuery: "MICKE desk IKEA",
            tags: ["desk", "compact", "cable management", "budget"], rating: 4.3, reviewCount: 9876),

        CatalogProduct(name: "Mid-Century Desk", brand: "West Elm", category: .desk, subcategory: "Writing Desk",
            price: 699, colorOptions: ["Walnut", "Oak", "White"],
            dimensions: .init(width: 1.37, depth: 0.61, height: 0.76),
            productDescription: "Solid wood legs and leather-wrapped drawer pulls — desk goals.",
            compatibleStyles: [.midCentury, .contemporary, .japandi],
            retailer: "West Elm", searchQuery: "mid-century desk West Elm walnut",
            tags: ["desk", "walnut", "mid-century", "leather"], isTrending: true, rating: 4.7, reviewCount: 1432),

        CatalogProduct(name: "ALEX Desk", brand: "IKEA", category: .desk, subcategory: "Desk with Storage",
            price: 199, colorOptions: ["White", "Grey", "Black"],
            dimensions: .init(width: 1.31, depth: 0.60, height: 0.76),
            productDescription: "Six drawers on one side — serious storage at a serious price.",
            compatibleStyles: [.minimalist, .scandinavian, .minimalist],
            retailer: "IKEA", searchQuery: "ALEX desk drawers IKEA",
            tags: ["desk", "drawers", "storage", "home office"], rating: 4.5, reviewCount: 21034),

        CatalogProduct(name: "Industrial Desk", brand: "CB2", category: .desk, subcategory: "Writing Desk",
            price: 799, colorOptions: ["Grey", "Black", "Steel"],
            dimensions: .init(width: 1.52, depth: 0.61, height: 0.76),
            productDescription: "Concrete-topped desk on powder-coated steel frame — industrial edge.",
            compatibleStyles: [.industrial, .contemporary, .nordicNoir],
            retailer: "CB2", searchQuery: "industrial desk concrete steel CB2",
            tags: ["desk", "concrete", "industrial", "steel"], rating: 4.2, reviewCount: 312),

        CatalogProduct(name: "Secretary Desk", brand: "Pottery Barn", category: .desk, subcategory: "Secretary Desk",
            price: 999, colorOptions: ["White", "Antique Bronze", "Espresso"],
            dimensions: .init(width: 0.86, depth: 0.46, height: 1.52),
            productDescription: "Wall-mounted fold-down desk — disappears when work is done.",
            compatibleStyles: [.farmhouse, .grandmillennial, .artDeco],
            retailer: "Pottery Barn", searchQuery: "secretary fold-down desk Pottery Barn",
            tags: ["desk", "fold-down", "space-saving", "secretary"], rating: 4.4, reviewCount: 678),

        CatalogProduct(name: "Finch Writing Desk", brand: "Article", category: .desk, subcategory: "Writing Desk",
            price: 499, colorOptions: ["Walnut", "Black", "White Oak"],
            dimensions: .init(width: 1.37, depth: 0.61, height: 0.76),
            productDescription: "Clean Scandinavian form with solid walnut legs — minimal but functional.",
            compatibleStyles: [.midCentury, .japandi, .minimalist],
            retailer: "Article", searchQuery: "Finch writing desk Article",
            tags: ["desk", "walnut", "clean", "minimal"], isNew: true, rating: 4.6, reviewCount: 892),

        CatalogProduct(name: "LINNMON Desk", brand: "IKEA", category: .desk, subcategory: "Table Desk",
            price: 129, colorOptions: ["White", "Black", "Oak"],
            dimensions: .init(width: 1.50, depth: 0.60, height: 0.74),
            productDescription: "Versatile table-top with ADILS legs — configure your own desk setup.",
            compatibleStyles: [.minimalist, .scandinavian],
            retailer: "IKEA", searchQuery: "LINNMON ADILS desk IKEA",
            tags: ["desk", "customizable", "affordable", "versatile"], rating: 4.0, reviewCount: 34521),

        CatalogProduct(name: "Studio Desk", brand: "Wayfair", category: .desk, subcategory: "Studio Desk",
            price: 349, colorOptions: ["Black", "White", "Walnut"],
            dimensions: .init(width: 1.37, depth: 0.61, height: 0.76),
            productDescription: "Industrial-inspired desk with bookshelf hutch and drawer unit.",
            compatibleStyles: [.industrial, .contemporary, .farmhouse],
            retailer: "Wayfair", searchQuery: "studio desk hutch drawer unit",
            tags: ["desk", "hutch", "storage", "industrial"], isTrending: true, rating: 4.3, reviewCount: 1234),
    ]

    // MARK: Storage (10)
    static let storage: [CatalogProduct] = [
        CatalogProduct(name: "KALLAX Shelving Unit", brand: "IKEA", category: .storage, subcategory: "Shelving",
            price: 119, colorOptions: ["White", "Black", "Birch", "Grey"],
            dimensions: .init(width: 1.47, depth: 0.39, height: 1.47),
            productDescription: "Iconic grid shelving — endlessly versatile with cube inserts.",
            compatibleStyles: [.scandinavian, .minimalist, .industrial],
            retailer: "IKEA", searchQuery: "KALLAX shelving unit IKEA",
            tags: ["shelving", "storage", "grid", "versatile"], isTrending: true, rating: 4.5, reviewCount: 24531),

        CatalogProduct(name: "Anton Sideboard", brand: "Article", category: .storage, subcategory: "Sideboard",
            price: 899, colorOptions: ["Walnut", "Oak", "White"],
            dimensions: .init(width: 1.68, depth: 0.43, height: 0.79),
            productDescription: "Solid walnut sideboard with exposed joinery — timeless craftsmanship.",
            compatibleStyles: [.midCentury, .japandi, .scandinavian],
            retailer: "Article", searchQuery: "Anton sideboard walnut Article",
            tags: ["sideboard", "storage", "walnut", "mid-century"], isTrending: true, rating: 4.8, reviewCount: 1892),

        CatalogProduct(name: "Industrial Bookshelf", brand: "CB2", category: .storage, subcategory: "Bookshelf",
            price: 699, colorOptions: ["Black", "White", "Steel Grey"],
            dimensions: .init(width: 0.91, depth: 0.36, height: 1.83),
            productDescription: "Steel frame and wood shelf combo — sturdy and looks great.",
            compatibleStyles: [.industrial, .contemporary, .nordicNoir],
            retailer: "CB2", searchQuery: "industrial bookshelf steel wood CB2",
            tags: ["bookshelf", "storage", "industrial", "metal"], rating: 4.3, reviewCount: 456),

        CatalogProduct(name: "HEMNES Bookcase", brand: "IKEA", category: .storage, subcategory: "Bookcase",
            price: 179, colorOptions: ["White", "Light Brown", "Dark Brown"],
            dimensions: .init(width: 0.90, depth: 0.22, height: 1.97),
            productDescription: "Solid pine bookcase with 5 shelves and classic clean lines.",
            compatibleStyles: [.scandinavian, .farmhouse, .minimalist],
            retailer: "IKEA", searchQuery: "HEMNES bookcase IKEA",
            tags: ["bookcase", "pine", "solid wood", "affordable"], rating: 4.4, reviewCount: 12034),

        CatalogProduct(name: "Stacked Media Console", brand: "West Elm", category: .storage, subcategory: "Media Console",
            price: 999, colorOptions: ["Walnut", "Black", "White"],
            dimensions: .init(width: 1.52, depth: 0.43, height: 0.61),
            productDescription: "Solid wood media console with wire management and glass doors.",
            compatibleStyles: [.contemporary, .midCentury, .japandi],
            retailer: "West Elm", searchQuery: "media console West Elm walnut",
            tags: ["media console", "TV stand", "storage", "walnut"], rating: 4.5, reviewCount: 2103),

        CatalogProduct(name: "Floating Shelves Set", brand: "Target", category: .storage, subcategory: "Wall Shelves",
            price: 59, colorOptions: ["White", "Grey", "Natural"],
            dimensions: .init(width: 0.60, depth: 0.15, height: 0.10),
            productDescription: "Set of 3 wall-mounted floating shelves — clean and modern.",
            compatibleStyles: [.minimalist, .scandinavian, .contemporary],
            retailer: "Target", searchQuery: "floating shelves wall mounted set of 3",
            tags: ["shelves", "wall-mounted", "floating", "budget"], rating: 4.0, reviewCount: 4532),

        CatalogProduct(name: "Storage Ottoman", brand: "Pottery Barn", category: .storage, subcategory: "Ottoman",
            price: 599, colorOptions: ["Beige", "Grey", "Navy", "Brown"],
            dimensions: .init(width: 0.91, depth: 0.91, height: 0.43),
            productDescription: "Tufted top lifts to reveal large interior storage — dual-purpose.",
            compatibleStyles: [.farmhouse, .coastal, .contemporary],
            retailer: "Pottery Barn", searchQuery: "storage ottoman tufted Pottery Barn",
            tags: ["ottoman", "storage", "dual purpose", "tufted"], isTrending: true, rating: 4.6, reviewCount: 2341),

        CatalogProduct(name: "BESTÅ TV Unit", brand: "IKEA", category: .storage, subcategory: "TV Unit",
            price: 299, colorOptions: ["White", "Grey", "Oak", "Black-Brown"],
            dimensions: .init(width: 1.80, depth: 0.40, height: 0.64),
            productDescription: "Modular TV bench with push-open doors — hides clutter effortlessly.",
            compatibleStyles: [.minimalist, .japandi, .scandinavian],
            retailer: "IKEA", searchQuery: "BESTA TV unit IKEA",
            tags: ["TV stand", "storage", "modular", "minimal"], rating: 4.3, reviewCount: 18902),

        CatalogProduct(name: "Elara Credenza", brand: "CB2", category: .storage, subcategory: "Credenza",
            price: 1499, colorOptions: ["White", "Walnut", "Glossy Black"],
            dimensions: .init(width: 1.83, depth: 0.43, height: 0.76),
            productDescription: "Lacquered credenza with cane-front doors on solid brass legs.",
            compatibleStyles: [.modernLuxury, .midCentury, .artDeco],
            retailer: "CB2", searchQuery: "credenza cane doors brass legs CB2",
            tags: ["credenza", "cane", "brass", "luxury"], isNew: true, isTrending: true, rating: 4.7, reviewCount: 312),

        CatalogProduct(name: "Seagrass Storage Baskets", brand: "Amazon", category: .storage, subcategory: "Baskets",
            price: 49, colorOptions: ["Natural", "Black", "White"],
            dimensions: .init(width: 0.35, depth: 0.35, height: 0.30),
            productDescription: "Set of 3 woven seagrass baskets — great for toys, blankets, or plants.",
            compatibleStyles: [.bohemian, .farmhouse, .coastal, .biophilic],
            retailer: "Amazon", searchQuery: "seagrass storage baskets woven set of 3",
            tags: ["basket", "storage", "woven", "natural", "budget"], rating: 4.5, reviewCount: 8912),
    ]

    // MARK: Lighting (8)
    static let lighting: [CatalogProduct] = [
        CatalogProduct(name: "HEKTAR Floor Lamp", brand: "IKEA", category: .lighting, subcategory: "Floor Lamp",
            price: 69, colorOptions: ["Dark Grey", "White"],
            dimensions: .init(width: 0.36, depth: 0.36, height: 1.80),
            productDescription: "Industrial-style adjustable floor lamp with dimmer.",
            compatibleStyles: [.industrial, .contemporary, .minimalist],
            retailer: "IKEA", searchQuery: "HEKTAR floor lamp IKEA",
            tags: ["lamp", "floor lamp", "adjustable", "dimmer"], rating: 4.4, reviewCount: 5432),

        CatalogProduct(name: "Arc Floor Lamp", brand: "West Elm", category: .lighting, subcategory: "Arc Lamp",
            price: 299, colorOptions: ["Brass", "Black", "Antique Bronze"],
            dimensions: .init(width: 0.30, depth: 0.30, height: 1.93),
            productDescription: "Dramatic arching floor lamp on a marble base — a room statement.",
            compatibleStyles: [.midCentury, .contemporary, .artDeco],
            retailer: "West Elm", searchQuery: "arc floor lamp brass marble base West Elm",
            tags: ["lamp", "arc lamp", "brass", "marble base"], isTrending: true, rating: 4.7, reviewCount: 2103),

        CatalogProduct(name: "Hammered Brass Pendant", brand: "CB2", category: .lighting, subcategory: "Pendant Light",
            price: 499, colorOptions: ["Brass", "Chrome", "Matte Black"],
            dimensions: .init(width: 0.46, depth: 0.46, height: 0.30),
            productDescription: "Hand-hammered brass pendant with adjustable wire length.",
            compatibleStyles: [.modernLuxury, .artDeco, .bohemian],
            retailer: "CB2", searchQuery: "hammered brass pendant light CB2",
            tags: ["pendant", "brass", "hammered", "ceiling light"], rating: 4.6, reviewCount: 432),

        CatalogProduct(name: "Jute Pendant Light", brand: "Pottery Barn", category: .lighting, subcategory: "Pendant Light",
            price: 249, colorOptions: ["Natural"],
            dimensions: .init(width: 0.53, depth: 0.53, height: 0.41),
            productDescription: "Hand-woven jute shade filters warm, ambient light.",
            compatibleStyles: [.bohemian, .coastal, .farmhouse, .biophilic],
            retailer: "Pottery Barn", searchQuery: "jute pendant light Pottery Barn",
            tags: ["pendant", "jute", "woven", "boho"], rating: 4.5, reviewCount: 1892),

        CatalogProduct(name: "RANARP Floor Lamp", brand: "IKEA", category: .lighting, subcategory: "Floor Lamp",
            price: 79, colorOptions: ["Black", "White"],
            dimensions: .init(width: 0.30, depth: 0.30, height: 1.63),
            productDescription: "Retro-inspired work lamp with adjustable arm and head.",
            compatibleStyles: [.industrial, .midCentury, .minimalist],
            retailer: "IKEA", searchQuery: "RANARP floor lamp IKEA",
            tags: ["lamp", "floor lamp", "adjustable", "retro"], rating: 4.3, reviewCount: 7821),

        CatalogProduct(name: "Ceramic Table Lamp", brand: "Article", category: .lighting, subcategory: "Table Lamp",
            price: 199, colorOptions: ["White", "Sage", "Cream", "Terracotta"],
            dimensions: .init(width: 0.30, depth: 0.30, height: 0.56),
            productDescription: "Hand-thrown ceramic base with linen shade — warm bedside glow.",
            compatibleStyles: [.japandi, .scandinavian, .wabiSabi, .biophilic],
            retailer: "Article", searchQuery: "ceramic table lamp linen shade Article",
            tags: ["lamp", "table lamp", "ceramic", "bedside"], isNew: true, isTrending: true, rating: 4.8, reviewCount: 678),

        CatalogProduct(name: "Sputnik Chandelier", brand: "Wayfair", category: .lighting, subcategory: "Chandelier",
            price: 299, colorOptions: ["Brass", "Chrome", "Black"],
            dimensions: .init(width: 0.61, depth: 0.61, height: 0.51),
            productDescription: "12-arm sputnik design — mid-century retro flair overhead.",
            compatibleStyles: [.midCentury, .artDeco, .maximalist],
            retailer: "Wayfair", searchQuery: "sputnik chandelier mid-century",
            tags: ["chandelier", "sputnik", "mid-century", "ceiling light"], isTrending: true, rating: 4.4, reviewCount: 2341),

        CatalogProduct(name: "Smart LED Floor Lamp", brand: "Amazon", category: .lighting, subcategory: "Floor Lamp",
            price: 149, colorOptions: ["White", "Black"],
            dimensions: .init(width: 0.30, depth: 0.30, height: 1.75),
            productDescription: "App-controlled RGB floor lamp with 16 million colors and dimmer.",
            compatibleStyles: [.contemporary, .minimalist, .maximalist],
            retailer: "Amazon", searchQuery: "smart LED floor lamp RGB app controlled",
            tags: ["lamp", "smart home", "LED", "RGB", "app controlled"], isNew: true, rating: 4.2, reviewCount: 12034),
    ]

    // MARK: Rugs (8)
    static let rugs: [CatalogProduct] = [
        CatalogProduct(name: "HÖJET Kilim Rug 5x8", brand: "IKEA", category: .rug, subcategory: "Flatweave Rug",
            price: 149, colorOptions: ["Multi/Beige", "Blue/White", "Natural/Brown"],
            dimensions: .init(width: 1.60, depth: 2.30, height: 0.01),
            productDescription: "Traditional kilim pattern handwoven in India with wool.",
            compatibleStyles: [.bohemian, .coastal, .farmhouse],
            retailer: "IKEA", searchQuery: "HOJET kilim rug IKEA",
            tags: ["rug", "kilim", "flatweave", "handwoven", "wool"], rating: 4.3, reviewCount: 3421),

        CatalogProduct(name: "Wool Area Rug 8x10", brand: "West Elm", category: .rug, subcategory: "Wool Rug",
            price: 499, colorOptions: ["Grey", "Beige", "Ivory", "Navy"],
            dimensions: .init(width: 2.44, depth: 3.05, height: 0.01),
            productDescription: "Hand-woven 100% wool pile — durable and luxuriously soft underfoot.",
            compatibleStyles: [.japandi, .scandinavian, .minimalist, .organicModern],
            retailer: "West Elm", searchQuery: "wool area rug 8x10 West Elm",
            tags: ["rug", "wool", "area rug", "natural"], isTrending: true, rating: 4.7, reviewCount: 2341),

        CatalogProduct(name: "Persian Medallion Rug", brand: "Wayfair", category: .rug, subcategory: "Traditional Rug",
            price: 299, colorOptions: ["Multi", "Blue/Red", "Green/Ivory"],
            dimensions: .init(width: 1.83, depth: 2.74, height: 0.01),
            productDescription: "Machine-made Persian medallion design in rich jewel tones.",
            compatibleStyles: [.bohemian, .grandmillennial, .maximalist],
            retailer: "Wayfair", searchQuery: "Persian medallion area rug",
            tags: ["rug", "Persian", "traditional", "medallion"], rating: 4.1, reviewCount: 5678),

        CatalogProduct(name: "Geometric Wool Rug", brand: "CB2", category: .rug, subcategory: "Geometric Rug",
            price: 699, colorOptions: ["Black/White", "Grey/White", "Charcoal/Cream"],
            dimensions: .init(width: 2.44, depth: 3.05, height: 0.01),
            productDescription: "Bold graphic pattern hand-tufted in 100% wool.",
            compatibleStyles: [.contemporary, .industrial, .artDeco],
            retailer: "CB2", searchQuery: "geometric wool rug black white CB2",
            tags: ["rug", "geometric", "wool", "graphic"], rating: 4.5, reviewCount: 567),

        CatalogProduct(name: "Jute Area Rug 8x10", brand: "Pottery Barn", category: .rug, subcategory: "Natural Rug",
            price: 399, colorOptions: ["Natural", "Natural/Ivory", "Dark Natural"],
            dimensions: .init(width: 2.44, depth: 3.05, height: 0.02),
            productDescription: "Chunky jute weave for earthy texture — durable indoor/outdoor use.",
            compatibleStyles: [.farmhouse, .coastal, .biophilic, .bohemian],
            retailer: "Pottery Barn", searchQuery: "jute area rug Pottery Barn",
            tags: ["rug", "jute", "natural", "earthy"], isTrending: true, rating: 4.6, reviewCount: 3892),

        CatalogProduct(name: "SINDAL Rug", brand: "IKEA", category: .rug, subcategory: "Low Pile Rug",
            price: 79, colorOptions: ["Beige", "Grey", "Blue"],
            dimensions: .init(width: 1.60, depth: 2.30, height: 0.01),
            productDescription: "Low pile flatweave rug — easy to vacuum and maintain.",
            compatibleStyles: [.minimalist, .scandinavian, .contemporary],
            retailer: "IKEA", searchQuery: "SINDAL rug IKEA",
            tags: ["rug", "low pile", "easy care", "affordable"], rating: 4.1, reviewCount: 6712),

        CatalogProduct(name: "Shag Rug 5x7", brand: "Target", category: .rug, subcategory: "Shag Rug",
            price: 129, colorOptions: ["White", "Grey", "Beige", "Blush"],
            dimensions: .init(width: 1.52, depth: 2.13, height: 0.04),
            productDescription: "Plush shag pile — soft underfoot in bedrooms and reading nooks.",
            compatibleStyles: [.bohemian, .contemporary, .coastal, .grandmillennial],
            retailer: "Target", searchQuery: "shag rug 5x7 plush",
            tags: ["rug", "shag", "plush", "cozy"], rating: 4.3, reviewCount: 4321),

        CatalogProduct(name: "Indoor/Outdoor Rug", brand: "Amazon", category: .rug, subcategory: "Outdoor Rug",
            price: 89, colorOptions: ["Green/Blue", "Grey/White", "Black/White"],
            dimensions: .init(width: 1.52, depth: 2.44, height: 0.01),
            productDescription: "Waterproof polypropylene — perfect for patios, entryways, or playrooms.",
            compatibleStyles: [.coastal, .contemporary, .tropical],
            retailer: "Amazon", searchQuery: "indoor outdoor area rug polypropylene",
            tags: ["rug", "outdoor", "waterproof", "durable"], isNew: false, rating: 4.2, reviewCount: 15432),
    ]

    // MARK: Decor (10)
    static let decor: [CatalogProduct] = [
        CatalogProduct(name: "Ceramic Vase Set of 3", brand: "CB2", category: .decor, subcategory: "Vases",
            price: 89, colorOptions: ["White", "Sage", "Cream", "Black"],
            dimensions: .init(width: 0.10, depth: 0.10, height: 0.30),
            productDescription: "Three sculptural vases in matte ceramic — arrange as a still life.",
            compatibleStyles: [.japandi, .minimalist, .wabiSabi, .organicModern],
            retailer: "CB2", searchQuery: "ceramic vase set 3 matte CB2",
            tags: ["vase", "ceramic", "decor", "set", "minimalist"], isTrending: true, rating: 4.7, reviewCount: 1234),

        CatalogProduct(name: "Gallery Wall Frame Set", brand: "IKEA", category: .decor, subcategory: "Frames",
            price: 79, colorOptions: ["White", "Black", "Natural"],
            dimensions: .init(width: 0.90, depth: 0.03, height: 0.60),
            productDescription: "9-piece gallery wall frame set in various sizes.",
            compatibleStyles: [.scandinavian, .minimalist, .contemporary, .bohemian],
            retailer: "IKEA", searchQuery: "gallery wall frame set IKEA RIBBA",
            tags: ["frames", "gallery wall", "art", "decor"], isTrending: true, rating: 4.5, reviewCount: 8921),

        CatalogProduct(name: "Velvet Throw Pillow Set", brand: "West Elm", category: .decor, subcategory: "Pillows",
            price: 99, colorOptions: ["Multi", "Beige/Rust", "Blue/Green", "Blush/Cream"],
            dimensions: .init(width: 0.46, depth: 0.46, height: 0.15),
            productDescription: "Set of 2 velvet throw pillows with down-alternative insert.",
            compatibleStyles: [.bohemian, .coastal, .maximalist, .midCentury],
            retailer: "West Elm", searchQuery: "velvet throw pillow set West Elm",
            tags: ["pillow", "velvet", "throw pillow", "cozy"], rating: 4.4, reviewCount: 3421),

        CatalogProduct(name: "Abstract Canvas Print", brand: "Wayfair", category: .decor, subcategory: "Wall Art",
            price: 199, colorOptions: ["Multi", "Warm Tones", "Cool Tones", "Monochrome"],
            dimensions: .init(width: 0.76, depth: 0.05, height: 1.02),
            productDescription: "Gallery-wrapped canvas on kiln-dried wood frame — ready to hang.",
            compatibleStyles: [.modernLuxury, .contemporary, .bohemian],
            retailer: "Wayfair", searchQuery: "abstract canvas wall art large",
            tags: ["wall art", "canvas", "abstract", "painting"], rating: 4.3, reviewCount: 2341),

        CatalogProduct(name: "Decorative Catchall Bowl", brand: "Pottery Barn", category: .decor, subcategory: "Bowls",
            price: 129, colorOptions: ["Natural", "White", "Terracotta"],
            dimensions: .init(width: 0.30, depth: 0.30, height: 0.10),
            productDescription: "Turned mango wood bowl — for keys, fruit, or table styling.",
            compatibleStyles: [.farmhouse, .coastal, .wabiSabi, .japandi],
            retailer: "Pottery Barn", searchQuery: "decorative wood bowl Pottery Barn",
            tags: ["bowl", "wood", "decor", "catchall"], rating: 4.6, reviewCount: 892),

        CatalogProduct(name: "Macrame Wall Hanging", brand: "Amazon", category: .decor, subcategory: "Wall Art",
            price: 59, colorOptions: ["Natural", "Ivory"],
            dimensions: .init(width: 0.61, depth: 0.05, height: 0.91),
            productDescription: "Hand-knotted cotton macrame — boho texture for any blank wall.",
            compatibleStyles: [.bohemian, .coastal, .farmhouse],
            retailer: "Amazon", searchQuery: "macrame wall hanging handmade cotton",
            tags: ["macrame", "wall art", "boho", "handmade"], isTrending: true, rating: 4.4, reviewCount: 12034),

        CatalogProduct(name: "Marble & Wood Bookends", brand: "West Elm", category: .decor, subcategory: "Bookends",
            price: 49, colorOptions: ["Marble/Brass", "Marble/Black", "White/Walnut"],
            dimensions: .init(width: 0.10, depth: 0.10, height: 0.20),
            productDescription: "Marble base with walnut top — keep your shelves orderly in style.",
            compatibleStyles: [.minimalist, .modernLuxury, .japandi],
            retailer: "West Elm", searchQuery: "marble bookends brass wood West Elm",
            tags: ["bookends", "marble", "brass", "shelf decor"], rating: 4.5, reviewCount: 1234),

        CatalogProduct(name: "Woven Throw Blanket", brand: "Pottery Barn", category: .decor, subcategory: "Throws",
            price: 149, colorOptions: ["Cream", "Grey", "Oatmeal", "Sage"],
            dimensions: .init(width: 1.30, depth: 0.05, height: 1.70),
            productDescription: "Chunky hand-woven cotton throw — drape on sofa or chair arm.",
            compatibleStyles: [.farmhouse, .coastal, .japandi, .bohemian],
            retailer: "Pottery Barn", searchQuery: "woven throw blanket cotton Pottery Barn",
            tags: ["throw", "blanket", "cotton", "cozy"], isTrending: true, rating: 4.8, reviewCount: 5678),

        CatalogProduct(name: "Candle Set of 4", brand: "CB2", category: .decor, subcategory: "Candles",
            price: 79, colorOptions: ["White", "Cream", "Black", "Sage"],
            dimensions: .init(width: 0.08, depth: 0.08, height: 0.15),
            productDescription: "Unscented pillar candles in varying heights — perfect for styling.",
            compatibleStyles: [.japandi, .scandinavian, .wabiSabi, .minimalist],
            retailer: "CB2", searchQuery: "pillar candle set CB2",
            tags: ["candle", "pillar", "minimal", "styling"], isNew: true, rating: 4.3, reviewCount: 892),

        CatalogProduct(name: "DRÖMSK Bamboo Tray", brand: "IKEA", category: .decor, subcategory: "Trays",
            price: 29, colorOptions: ["Bamboo", "White"],
            dimensions: .init(width: 0.45, depth: 0.35, height: 0.06),
            productDescription: "Natural bamboo tray for coffee table or kitchen counter styling.",
            compatibleStyles: [.minimalist, .japandi, .biophilic, .scandinavian],
            retailer: "IKEA", searchQuery: "bamboo tray IKEA",
            tags: ["tray", "bamboo", "natural", "organization"], rating: 4.5, reviewCount: 4321),
    ]

    // MARK: Plants (8)
    static let plants: [CatalogProduct] = [
        CatalogProduct(name: "FEJKA Artificial Plant Set", brand: "IKEA", category: .plant, subcategory: "Artificial Plant",
            price: 19, colorOptions: ["Green"],
            dimensions: .init(width: 0.12, depth: 0.12, height: 0.30),
            productDescription: "Lifelike artificial plants — no water, no sun, endless style.",
            compatibleStyles: [.minimalist, .japandi, .biophilic, .scandinavian],
            retailer: "IKEA", searchQuery: "FEJKA artificial plant IKEA",
            tags: ["plant", "artificial", "faux", "low maintenance"], isTrending: true, rating: 4.4, reviewCount: 18902),

        CatalogProduct(name: "Large Fiddle Leaf Fig (Faux)", brand: "Target", category: .plant, subcategory: "Faux Tree",
            price: 89, colorOptions: ["Green"],
            dimensions: .init(width: 0.50, depth: 0.50, height: 1.52),
            productDescription: "Realistic faux fiddle leaf fig — the statement plant that never dies.",
            compatibleStyles: [.biophilic, .organicModern, .contemporary, .coastal],
            retailer: "Target", searchQuery: "faux fiddle leaf fig tree large",
            tags: ["plant", "faux tree", "statement", "indoor"], isTrending: true, rating: 4.3, reviewCount: 6789),

        CatalogProduct(name: "Terracotta Plant Pot Set", brand: "Amazon", category: .plant, subcategory: "Plant Pots",
            price: 49, colorOptions: ["Terracotta", "White Terracotta", "Speckled"],
            dimensions: .init(width: 0.15, depth: 0.15, height: 0.15),
            productDescription: "Set of 5 unglazed terracotta pots in graduated sizes.",
            compatibleStyles: [.mediterranean, .bohemian, .wabiSabi, .farmhouse],
            retailer: "Amazon", searchQuery: "terracotta plant pot set 5 unglazed",
            tags: ["pot", "terracotta", "plant pot", "set"], isTrending: true, rating: 4.6, reviewCount: 23041),

        CatalogProduct(name: "Marble Plant Stand", brand: "CB2", category: .plant, subcategory: "Plant Stand",
            price: 199, colorOptions: ["Marble/Brass", "White/Gold"],
            dimensions: .init(width: 0.25, depth: 0.25, height: 0.71),
            productDescription: "White marble top on slim brass legs — elevate your plant game.",
            compatibleStyles: [.minimalist, .artDeco, .modernLuxury],
            retailer: "CB2", searchQuery: "marble plant stand brass CB2",
            tags: ["plant stand", "marble", "brass", "minimal"], isNew: true, rating: 4.5, reviewCount: 432),

        CatalogProduct(name: "Hanging Planter Set", brand: "West Elm", category: .plant, subcategory: "Hanging Planter",
            price: 79, colorOptions: ["Natural", "White", "Black"],
            dimensions: .init(width: 0.20, depth: 0.20, height: 0.20),
            productDescription: "Set of 2 hand-woven macrame hanging planters — great for trailing plants.",
            compatibleStyles: [.bohemian, .biophilic, .coastal, .farmhouse],
            retailer: "West Elm", searchQuery: "macrame hanging planter set West Elm",
            tags: ["planter", "hanging", "macrame", "set"], rating: 4.6, reviewCount: 2341),

        CatalogProduct(name: "Snake Plant Faux 4ft", brand: "Wayfair", category: .plant, subcategory: "Faux Plant",
            price: 129, colorOptions: ["Green/Yellow"],
            dimensions: .init(width: 0.40, depth: 0.40, height: 1.22),
            productDescription: "Ultra-realistic sansevieria in nursery pot — fool anyone with this one.",
            compatibleStyles: [.minimalist, .industrial, .biophilic, .japandi],
            retailer: "Wayfair", searchQuery: "faux snake plant 4 foot realistic",
            tags: ["plant", "faux", "snake plant", "realistic"], rating: 4.2, reviewCount: 3456),

        CatalogProduct(name: "Concrete Plant Pot Trio", brand: "CB2", category: .plant, subcategory: "Plant Pots",
            price: 149, colorOptions: ["Grey", "Black", "Speckled"],
            dimensions: .init(width: 0.18, depth: 0.18, height: 0.20),
            productDescription: "Set of 3 raw concrete pots — textured finish, drainage holes included.",
            compatibleStyles: [.industrial, .minimalist, .wabiSabi, .nordicNoir],
            retailer: "CB2", searchQuery: "concrete plant pot set 3 CB2",
            tags: ["pot", "concrete", "industrial", "set"], isNew: true, rating: 4.4, reviewCount: 678),

        CatalogProduct(name: "Woven Seagrass Planter", brand: "Pottery Barn", category: .plant, subcategory: "Planter Basket",
            price: 89, colorOptions: ["Natural", "Natural/White"],
            dimensions: .init(width: 0.30, depth: 0.30, height: 0.35),
            productDescription: "Hand-woven seagrass planter basket — hides nursery pots in style.",
            compatibleStyles: [.coastal, .farmhouse, .bohemian, .tropical],
            retailer: "Pottery Barn", searchQuery: "seagrass planter basket Pottery Barn",
            tags: ["planter", "seagrass", "basket", "natural"], isTrending: true, rating: 4.7, reviewCount: 3892),
    ]
}
