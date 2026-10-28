import Foundation
import SwiftUI
import UIKit
import RealityKit

// MARK: - Project

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var rooms: [Room]
    var designs: [DesignConcept]
    var moodboardItems: [MoodboardItem]
    var budget: BudgetPlan?
    var tags: [String]
    var thumbnailData: Data?
    var isFavorite: Bool = false
    var notes: String = ""

    var thumbnail: UIImage? { thumbnailData.flatMap(UIImage.init) }
    var roomCount: Int { rooms.count }
    var totalArea: Double { rooms.reduce(0) { $0 + $1.area } }

    static func empty(name: String = "Untitled Project") -> Project {
        Project(
            name: name,
            createdAt: .now,
            updatedAt: .now,
            rooms: [],
            designs: [],
            moodboardItems: [],
            tags: []
        )
    }

    // Returns a copy with all binary image data removed — used for CloudKit sync
    // to avoid exceeding the 1 MB CKRecord field limit.
    var strippedForSync: Project {
        var copy = self
        copy.thumbnailData = nil
        copy.rooms = rooms.map { room in
            var r = room
            r.floorPlanImageData = nil
            r.beforePhotoData = nil
            // capturedWalls kept — small float data, essential for floor plan sync
            return r
        }
        copy.designs = designs.map { concept in
            var d = concept
            d.imageData = nil
            d.roomBeforePhotoData = nil
            return d
        }
        copy.moodboardItems = moodboardItems.map { item in
            var m = item
            m.imageData = nil
            return m
        }
        return copy
    }
}

// MARK: - Captured Wall
// Stores the real-world wall geometry extracted from a LiDAR scan.
// Used by FloorPlanService to draw architecturally accurate floor plans.

struct CapturedWall: Codable, Hashable {
    var centerX: Float    // world-space X of wall centre
    var centerZ: Float    // world-space Z of wall centre
    var width: Float      // wall width in metres
    var height: Float     // wall height in metres
    var angle: Float      // rotation around Y axis (radians)
}

// MARK: - Room Score Entry

struct RoomScoreEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var score: Int
}

// MARK: - Room

struct Room: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: RoomType
    var dimensions: RoomDimensions
    var scanDate: Date
    var score: Int
    var scoreHistory: [RoomScoreEntry] = []
    var issues: [RoomIssue]
    var furnitureItems: [FurnitureItem]
    var scanDataURL: URL?
    var floorPlanImageData: Data?
    var beforePhotoData: Data?   // photo taken before the AI redesign — used in Before/After slider
    var capturedWalls: [CapturedWall] = []   // real LiDAR wall geometry for accurate floor plans

    var area: Double { dimensions.width * dimensions.length }
    var floorPlanImage: UIImage? { floorPlanImageData.flatMap(UIImage.init) }
    var beforePhoto: UIImage?    { beforePhotoData.flatMap(UIImage.init) }

    mutating func recordScore(_ newScore: Int) {
        score = newScore
        scoreHistory.append(RoomScoreEntry(date: .now, score: newScore))
    }

    enum RoomType: String, Codable, CaseIterable {
        case livingRoom = "Living Room"
        case bedroom    = "Bedroom"
        case kitchen    = "Kitchen"
        case bathroom   = "Bathroom"
        case diningRoom = "Dining Room"
        case homeOffice = "Home Office"
        case nursery    = "Nursery"
        case studio     = "Studio"
        case garage     = "Garage"
        case other      = "Other"

        var icon: String {
            switch self {
            case .livingRoom: return "sofa.fill"
            case .bedroom:    return "bed.double.fill"
            case .kitchen:    return "fork.knife"
            case .bathroom:   return "shower.fill"
            case .diningRoom: return "chair.fill"
            case .homeOffice: return "desktopcomputer"
            case .nursery:    return "figure.and.child.holdinghands"
            case .studio:     return "camera.fill"
            case .garage:     return "car.fill"
            case .other:      return "square.fill"
            }
        }
    }
}

struct RoomDimensions: Codable, Hashable {
    var width: Double      // meters
    var length: Double     // meters
    var ceilingHeight: Double

    var widthFormatted: String  { String(format: "%.1f m", width) }
    var lengthFormatted: String { String(format: "%.1f m", length) }
    var areaFormatted: String   { String(format: "%.1f m²", width * length) }
}

struct RoomIssue: Identifiable, Codable, Hashable {
    var id = UUID()
    var severity: Severity
    var title: String
    var description: String
    var suggestion: String

    enum Severity: String, Codable {
        case low, medium, high

        var color: Color {
            switch self {
            case .low:    return .green
            case .medium: return .orange
            case .high:   return .red
            }
        }

        var icon: String {
            switch self {
            case .low:    return "info.circle.fill"
            case .medium: return "exclamationmark.triangle.fill"
            case .high:   return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - Furniture

struct FurnitureItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: Category
    var dimensions: Dimensions
    var usdzURL: URL?
    var thumbnailURL: URL?
    var brand: String?
    var price: Double?
    var affiliateURL: URL?
    var colorOptions: [String]
    var isPlaced: Bool = false
    var isPurchased: Bool = false
    var position: SIMD3<Float>?
    var rotation: Float = 0
    // Real-world retailer info from AI
    var retailer: String?
    var searchQuery: String?

    /// Plain retailer search URL (no affiliate wrapping).
    /// Use affiliateShoppingURL(for:) on tap to get a commission-earning link.
    var shoppingURL: URL? { rawRetailerURL }

    /// Returns an affiliate-wrapped URL ready to open on the "Shop" button tap.
    /// When affiliate IDs are not yet configured it falls back to the plain search URL.
    func affiliateShoppingURL() -> URL? {
        guard let base = rawRetailerURL else { return nil }
        return AffiliateService.shared.affiliateURL(
            for: base,
            retailer: retailer ?? "wayfair",
            itemName: name
        )
    }

    private var rawRetailerURL: URL? {
        guard let q = (searchQuery ?? name)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        let base: String
        switch (retailer ?? "").lowercased() {
        case "ikea":                            base = "https://www.ikea.com/us/en/search/?q=\(q)"
        case "west elm", "westelm":             base = "https://www.westelm.com/search/results.html?words=\(q)"
        case "cb2":                             base = "https://www.cb2.com/search?query=\(q)"
        case "pottery barn", "potterybarn":     base = "https://www.potterybarn.com/search/results.html?words=\(q)"
        case "article":                         base = "https://www.article.com/search?q=\(q)"
        case "target":                          base = "https://www.target.com/s?searchTerm=\(q)"
        case "amazon":                          base = "https://www.amazon.com/s?k=\(q)"
        case "crate & barrel", "crate and barrel": base = "https://www.crateandbarrel.com/search/results.html?q=\(q)"
        default:                                base = "https://www.wayfair.com/keyword.php?keyword=\(q)"
        }
        return URL(string: base)
    }

    struct Dimensions: Codable, Hashable {
        var width: Double
        var depth: Double
        var height: Double
    }

    enum Category: String, Codable, CaseIterable {
        case sofa, chair, table, bed, desk, storage, lighting, rug, decor, plant

        var icon: String {
            switch self {
            case .sofa:    return "sofa.fill"
            case .chair:   return "chair.fill"
            case .table:   return "table.furniture.fill"
            case .bed:     return "bed.double.fill"
            case .desk:    return "desktopcomputer"
            case .storage: return "cabinet.fill"
            case .lighting: return "lightbulb.fill"
            case .rug:     return "square.grid.3x3.fill"
            case .decor:   return "paintbrush.fill"
            case .plant:   return "leaf.fill"
            }
        }

        // AR rendering properties — distinct material per category
        var arColor: UIColor {
            switch self {
            case .sofa:     return UIColor(red: 0.55, green: 0.48, blue: 0.40, alpha: 1) // warm taupe
            case .chair:    return UIColor(red: 0.60, green: 0.52, blue: 0.43, alpha: 1) // light taupe
            case .table:    return UIColor(red: 0.55, green: 0.40, blue: 0.28, alpha: 1) // warm oak
            case .bed:      return UIColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 1) // linen
            case .desk:     return UIColor(red: 0.42, green: 0.35, blue: 0.28, alpha: 1) // dark walnut
            case .storage:  return UIColor(red: 0.85, green: 0.82, blue: 0.76, alpha: 1) // off-white
            case .lighting: return UIColor(red: 0.90, green: 0.82, blue: 0.55, alpha: 1) // brass
            case .rug:      return UIColor(red: 0.50, green: 0.44, blue: 0.62, alpha: 1) // dusty purple
            case .decor:    return UIColor(red: 0.35, green: 0.62, blue: 0.60, alpha: 1) // teal
            case .plant:    return UIColor(red: 0.35, green: 0.58, blue: 0.32, alpha: 1) // leaf green
            }
        }

        var arRoughness: Float {
            switch self {
            case .lighting: return 0.1
            case .storage:  return 0.6
            default:        return 0.8
            }
        }

        var arMetallic: Float {
            switch self {
            case .lighting: return 0.7
            case .desk:     return 0.1
            default:        return 0.0
            }
        }
    }
}

// MARK: - Design Rating

enum DesignRating: String, Codable, Hashable {
    case thumbsUp, thumbsDown
}

// MARK: - Design Concept

struct DesignConcept: Identifiable, Codable, Hashable {
    var id = UUID()
    var style: DesignStyle
    var title: String
    var description: String
    var imageData: Data?
    var roomBeforePhotoData: Data?  // room photo taken before redesign — powers Before/After slider
    var palette: ColorPalette
    var furnitureSuggestions: [FurnitureItem]
    var estimatedCost: Double
    var createdAt: Date
    var isFavorite: Bool = false
    var tags: [String]
    var rating: DesignRating?

    var previewImage: UIImage? { imageData.flatMap(UIImage.init) }
}

enum DesignStyle: String, Codable, CaseIterable, Identifiable {
    case japandi         = "Japandi"
    case scandinavian    = "Scandinavian"
    case modernLuxury    = "Modern Luxury"
    case minimalist      = "Minimalist"
    case industrial      = "Industrial"
    case coastal         = "Coastal"
    case contemporary    = "Contemporary"
    case organicModern   = "Organic Modern"
    case bohemian        = "Bohemian"
    case midCentury      = "Mid-Century Modern"
    case wabiSabi        = "Wabi-Sabi"
    case farmhouse       = "Farmhouse"
    case artDeco         = "Art Deco"
    case tropical        = "Tropical"
    case mediterranean   = "Mediterranean"
    case maximalist      = "Maximalist"
    case nordicNoir      = "Nordic Noir"
    case biophilic       = "Biophilic"
    case grandmillennial = "Grandmillennial"
    case japandiTwo      = "Japandi 2.0"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .japandi:         return "🌿"
        case .scandinavian:    return "❄️"
        case .modernLuxury:    return "✨"
        case .minimalist:      return "⬜"
        case .industrial:      return "⚙️"
        case .coastal:         return "🌊"
        case .contemporary:    return "🔷"
        case .organicModern:   return "🌱"
        case .bohemian:        return "🎨"
        case .midCentury:      return "🕰️"
        case .wabiSabi:        return "🍃"
        case .farmhouse:       return "🏡"
        case .artDeco:         return "🔶"
        case .tropical:        return "🌴"
        case .mediterranean:   return "🫒"
        case .maximalist:      return "🪩"
        case .nordicNoir:      return "🌑"
        case .biophilic:       return "🪴"
        case .grandmillennial: return "🌸"
        case .japandiTwo:      return "🎋"
        }
    }

    var description: String {
        switch self {
        case .japandi:         return "Japanese simplicity meets Scandinavian function"
        case .scandinavian:    return "Clean lines, natural materials, cozy warmth"
        case .modernLuxury:    return "High-end materials with contemporary elegance"
        case .minimalist:      return "Less is more — space, light, and purpose"
        case .industrial:      return "Raw materials, urban character, exposed structure"
        case .coastal:         return "Breezy, light-filled, natural textures"
        case .contemporary:    return "Current trends, balanced, liveable"
        case .organicModern:   return "Biophilic design with modern sensibility"
        case .bohemian:        return "Eclectic, layered, globally inspired"
        case .midCentury:      return "1950s–70s optimism, timeless silhouettes"
        case .wabiSabi:        return "Beauty in imperfection, aged textures, natural decay"
        case .farmhouse:       return "Rustic warmth, shiplap, vintage charm"
        case .artDeco:         return "Bold geometry, gilded glamour, 1920s opulence"
        case .tropical:        return "Lush plants, rattan, warm island palette"
        case .mediterranean:   return "Terracotta, arched doorways, sun-bleached whites"
        case .maximalist:      return "More is more — layered, bold, unapologetically abundant"
        case .nordicNoir:      return "Dark drama, moody tones, stark Scandinavian edge"
        case .biophilic:       return "Nature inside — living walls, wood, stone, natural light"
        case .grandmillennial:  return "Grandma chic — chintz, needlepoint, antiques made fresh"
        case .japandiTwo:      return "Evolved Japandi — warmer, tactile, wabi textures added"
        }
    }

    var palette: [Color] {
        switch self {
        case .japandi:         return [Color(hex: "E8E0D5"), Color(hex: "7A6E63"), Color(hex: "2C2C2C"), Color(hex: "A8B5A2")]
        case .scandinavian:    return [Color(hex: "F5F5F0"), Color(hex: "DEDAD3"), Color(hex: "8C7B6B"), Color(hex: "4A90A4")]
        case .modernLuxury:    return [Color(hex: "1C1C1E"), Color.Luma.gold, Color(hex: "F5F5F0"), Color(hex: "8B7355")]
        case .minimalist:      return [Color(hex: "FFFFFF"), Color(hex: "F2F2F7"), Color(hex: "636366"), Color(hex: "1C1C1E")]
        case .industrial:      return [Color(hex: "2C2C2C"), Color(hex: "8B7355"), Color(hex: "C0392B"), Color(hex: "BDC3C7")]
        case .coastal:         return [Color(hex: "E8F4F8"), Color(hex: "A8C5D8"), Color(hex: "F5ECD7"), Color(hex: "2C7873")]
        case .contemporary:    return [Color(hex: "F8F8F8"), Color(hex: "2C3E50"), Color(hex: "E74C3C"), Color(hex: "ECF0F1")]
        case .organicModern:   return [Color(hex: "E8E0D5"), Color(hex: "7A8C6E"), Color(hex: "C8B89A"), Color(hex: "4A5240")]
        case .bohemian:        return [Color(hex: "D4A853"), Color(hex: "8B4513"), Color(hex: "6B8E7A"), Color(hex: "C8A882")]
        case .midCentury:      return [Color(hex: "E8A87C"), Color(hex: "2C4A52"), Color(hex: "F5C842"), Color(hex: "8B3A3A")]
        case .wabiSabi:        return [Color(hex: "D6CABB"), Color(hex: "9C8B78"), Color(hex: "5C4F42"), Color(hex: "B8A99A")]
        case .farmhouse:       return [Color(hex: "F5F0E8"), Color(hex: "C8B99A"), Color(hex: "6B5B4E"), Color(hex: "3D2B1F")]
        case .artDeco:         return [Color(hex: "1A1A2E"), Color.Luma.gold, Color(hex: "E8D5A3"), Color(hex: "2D4A3E")]
        case .tropical:        return [Color(hex: "2D6A4F"), Color(hex: "F4A261"), Color(hex: "E9C46A"), Color(hex: "F5F0E8")]
        case .mediterranean:   return [Color(hex: "E8D5B0"), Color(hex: "C1440E"), Color(hex: "1B5E7B"), Color(hex: "F5F0E8")]
        case .maximalist:      return [Color(hex: "8B1A4A"), Color.Luma.gold, Color(hex: "1A5276"), Color(hex: "27AE60")]
        case .nordicNoir:      return [Color(hex: "1C1C1E"), Color(hex: "2C2C2C"), Color(hex: "4A4A4A"), Color(hex: "8B8B8B")]
        case .biophilic:       return [Color(hex: "2D5A27"), Color(hex: "8B6914"), Color(hex: "C8B89A"), Color(hex: "E8F4E8")]
        case .grandmillennial:  return [Color(hex: "F5D0D0"), Color(hex: "B5838D"), Color(hex: "6D6875"), Color(hex: "E2C4B5")]
        case .japandiTwo:      return [Color(hex: "D4C8BC"), Color(hex: "8C7B6B"), Color(hex: "4A3E36"), Color(hex: "A89880")]
        }
    }
}

// MARK: - Color Palette

struct ColorPalette: Codable, Hashable {
    var primary: String   // hex
    var secondary: String
    var accent: String
    var neutral: String
    var wallColor: String
    var floorColor: String
    var name: String
}

// MARK: - Moodboard

struct MoodboardItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var type: ItemType
    var title: String
    var imageData: Data?
    var sourceURL: URL?
    var colorHex: String?
    var notes: String = ""
    var addedAt: Date = .now

    enum ItemType: String, Codable {
        case image, color, furniture, texture, palette
    }
}

// MARK: - Budget Plan

struct BudgetPlan: Codable, Hashable {
    var total: Double
    var currency: String = "USD"
    var items: [BudgetItem]
    var createdAt: Date

    var spent: Double { items.reduce(0) { $0 + $1.estimatedCost } }
    var remaining: Double { total - spent }
    var percentUsed: Double { total > 0 ? min(spent / total, 1.0) : 0 }
}

struct BudgetItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: String
    var estimatedCost: Double
    var priority: Priority
    var isOptional: Bool

    enum Priority: String, Codable, CaseIterable {
        case essential, recommended, optional

        var color: Color {
            switch self {
            case .essential:    return .red
            case .recommended:  return .orange
            case .optional:     return .green
            }
        }
    }
}

// MARK: - Subscription

enum SubscriptionTier: String, Codable, CaseIterable {
    case free     = "Free"
    case pro      = "Pro"
    case premium  = "Premium"
    case lifetime = "Lifetime"

    var icon: String {
        switch self {
        case .free:     return "sparkle"
        case .pro:      return "crown"
        case .premium:  return "crown.fill"
        case .lifetime: return "infinity"
        }
    }

    var maxScans: Int? {
        switch self {
        case .free: return 3
        default: return nil
        }
    }

    var maxAIRedesigns: Int? {
        switch self {
        case .free: return 5
        default: return nil
        }
    }

    var hasCloudSync: Bool { self != .free }
    var hasHDExport: Bool  { self != .free }
    var hasBudgetPlanner: Bool { self == .premium || self == .lifetime }
    var hasMultiRoom: Bool { self == .premium || self == .lifetime }
    var hasFutureVision: Bool { self == .premium }
    var hasDesignerCollab: Bool { self == .premium }
    var watermarksExports: Bool { self == .free }
}

// MARK: - AI Analysis

struct RoomAnalysis: Codable {
    var roomScore: Int
    var lightingScore: Int
    var flowScore: Int
    var utilizationScore: Int
    var issues: [RoomIssue]
    var opportunities: [String]
    var suggestedStyles: [DesignStyle]
    var analyzedAt: Date
}

// MARK: - Color hex init

// MARK: - Future Vision Scenario

enum FutureVisionScenario: String, CaseIterable, Identifiable {
    case luxury     = "Luxury Upgrade"
    case budget     = "Budget Makeover"
    case homeOffice = "Home Office Conversion"
    case nursery    = "Nursery Conversion"
    case renovation = "Full Renovation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .luxury:     return "crown.fill"
        case .budget:     return "dollarsign.circle.fill"
        case .homeOffice: return "desktopcomputer"
        case .nursery:    return "figure.and.child.holdinghands"
        case .renovation: return "hammer.fill"
        }
    }

    var style: DesignStyle {
        switch self {
        case .luxury:     return .modernLuxury
        case .budget:     return .scandinavian
        case .homeOffice: return .minimalist
        case .nursery:    return .coastal
        case .renovation: return .contemporary
        }
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
