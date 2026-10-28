import Foundation
import SwiftUI

@MainActor
final class AIDesignService: ObservableObject {
    static let shared = AIDesignService()

    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var error: String?

    private let openAI = OpenAIService.shared

    // MARK: - Generate Designs

    func generateDesigns(
        for room: Room,
        styles: [DesignStyle],
        tier: SubscriptionTier,
        additionalPrompt: String? = nil
    ) async -> [DesignConcept] {
        let allowedStyles = tier == .free ? Array(styles.prefix(1)) : styles
        isGenerating = true
        generationProgress = 0
        error = nil
        defer { isGenerating = false; generationProgress = 0 }

        // Offline check — return cached results if available
        if !NetworkMonitor.shared.isConnected {
            if let cached = cachedConcepts(for: room, styles: allowedStyles) {
                error = "Offline — showing cached designs."
                return cached
            }
            error = "No internet connection. Connect to generate AI designs."
            return []
        }

        // All styles run concurrently — text + image fetched in parallel per style.
        // Results arrive out of order, so we carry the original index for re-sorting.
        var indexedResults = [(index: Int, concept: DesignConcept)]()
        let total = Double(allowedStyles.count)

        await withTaskGroup(of: (Int, DesignConcept).self) { group in
            for (index, style) in allowedStyles.enumerated() {
                group.addTask { [openAI = self.openAI, extraPrompt = additionalPrompt] in
                    do {
                        async let textTask  = openAI.generateDesignConcept(style: style, room: room, additionalPrompt: extraPrompt)
                        async let imageTask = openAI.generateDesignImage(style: style, room: room, additionalPrompt: extraPrompt)
                        let (text, img) = try await (textTask, imageTask)

                        let palette   = await AIDesignService.shared.generatePalette(for: style)
                        let furniture = text.furnitureSuggestions.map { s in
                            FurnitureItem(
                                name: s.name,
                                category: FurnitureItem.Category(rawValue: s.category) ?? .decor,
                                dimensions: .init(width: s.width, depth: s.depth, height: s.height),
                                brand: s.name.components(separatedBy: " ").first ?? "LumaSpace",
                                price: s.estimatedPrice,
                                colorOptions: []
                            )
                        }
                        let concept = DesignConcept(
                            style: style,
                            title: text.title,
                            description: text.description,
                            imageData: img.jpegData(compressionQuality: 0.85),
                            roomBeforePhotoData: room.beforePhotoData,
                            palette: palette,
                            furnitureSuggestions: furniture,
                            estimatedCost: text.estimatedCost,
                            createdAt: .now,
                            tags: [style.rawValue, room.type.rawValue]
                        )
                        return (index, concept)
                    } catch {
                        let fallback = await AIDesignService.shared.makeFallbackConcept(style: style, room: room)
                        return (index, fallback)
                    }
                }
            }

            // Collect results as they complete and update progress live
            for await result in group {
                indexedResults.append(result)
                generationProgress = Double(indexedResults.count) / total
            }
        }

        generationProgress = 1.0
        let finalConcepts = indexedResults.sorted { $0.index < $1.index }.map(\.concept)

        // Notify user if app is backgrounded — fires only when not in foreground
        if !finalConcepts.isEmpty {
            NotificationService.shared.scheduleDesignsReadyNotification(styleCount: finalConcepts.count)
            cacheConcepts(finalConcepts, for: room, styles: allowedStyles)
        }

        return finalConcepts
    }

    // MARK: - Result Cache

    private func cacheKey(for room: Room, styles: [DesignStyle]) -> String {
        let styleStr = styles.map(\.rawValue).sorted().joined(separator: "_")
        return "ai_cache_\(room.id.uuidString)_\(styleStr)"
    }

    private func cacheConcepts(_ concepts: [DesignConcept], for room: Room, styles: [DesignStyle]) {
        guard let data = try? JSONEncoder().encode(concepts) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: room, styles: styles))
    }

    private func cachedConcepts(for room: Room, styles: [DesignStyle]) -> [DesignConcept]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: room, styles: styles)),
              let concepts = try? JSONDecoder().decode([DesignConcept].self, from: data)
        else { return nil }
        return concepts
    }

    // MARK: - Analyze Room

    func analyzeRoom(_ room: Room) async -> RoomAnalysis {
        do {
            return try await openAI.analyzeRoom(room)
        } catch {
            self.error = error.localizedDescription
            return makeFallbackAnalysis(room: room)
        }
    }

    // MARK: - Future Vision

    func generateFutureVision(
        for room: Room,
        scenario: FutureVisionScenario,
        budget: Double
    ) async -> (text: String, imageData: Data?) {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let (text, image) = try await openAI.generateFutureVision(room: room, scenario: scenario, budget: budget)
            return (text, image.jpegData(compressionQuality: 0.85))
        } catch {
            self.error = error.localizedDescription
            return ("Vision generation unavailable. Please check your API key and connection.", nil)
        }
    }

    // MARK: - Color Palette

    func generateAIPalette(style: DesignStyle, room: Room) async -> ColorPaletteAI? {
        do {
            return try await openAI.generateColorPalette(style: style, room: room)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Budget Planning

    func generateBudgetPlan(for room: Room, style: DesignStyle, budget: Double) -> BudgetPlan {
        let items = makeFallbackBudgetItems(for: style, totalBudget: budget)
        return BudgetPlan(total: budget, items: items, createdAt: .now)
    }

    func generateAIBudgetPlan(for room: Room, style: DesignStyle, budget: Double) async -> BudgetPlan {
        do {
            let items = try await openAI.generateBudgetPlan(style: style, room: room, budget: budget)
            return BudgetPlan(total: budget, items: items, createdAt: .now)
        } catch {
            self.error = error.localizedDescription
            return generateBudgetPlan(for: room, style: style, budget: budget)
        }
    }

    // MARK: - Furniture Fit

    func checkFit(item: FurnitureItem, room: Room) async -> FitCheckResult? {
        try? await openAI.checkFurnitureFit(item: item, room: room)
    }

    // MARK: - Local palette helper (used as colour seed)
    // nonisolated — only reads pure DesignStyle enum values, no actor state

    nonisolated func generatePalette(for style: DesignStyle) -> ColorPalette {
        let p = style.palette
        return ColorPalette(
            primary:    p[safe: 0]?.hexString ?? "#F5F5F0",
            secondary:  p[safe: 1]?.hexString ?? "#DED9D3",
            accent:     p[safe: 2]?.hexString ?? "#1A7A6E",
            neutral:    p[safe: 3]?.hexString ?? "#8C7B6B",
            wallColor:  p[safe: 0]?.hexString ?? "#F5F5F0",
            floorColor: p[safe: 3]?.hexString ?? "#C8A882",
            name: "\(style.rawValue) Palette"
        )
    }

    // MARK: - Fallback (no API key / offline)

    nonisolated func makeFallbackConcept(style: DesignStyle, room: Room) -> DesignConcept {
        DesignConcept(
            style: style,
            title: "\(style.rawValue) \(room.type.rawValue)",
            description: style.description + " Tailored to your \(String(format: "%.0f", room.area))m² space.",
            imageData: nil,
            roomBeforePhotoData: room.beforePhotoData,
            palette: generatePalette(for: style),
            furnitureSuggestions: [],
            estimatedCost: estimatedCost(for: style, area: room.area),
            createdAt: .now,
            tags: [style.rawValue]
        )
    }

    private func makeFallbackAnalysis(room: Room) -> RoomAnalysis {
        RoomAnalysis(
            roomScore: room.score,
            lightingScore: 70,
            flowScore: 65,
            utilizationScore: 72,
            issues: room.issues,
            opportunities: [
                "Add layered lighting for depth and warmth.",
                "Use a large mirror to amplify the sense of space.",
                "Define zones with a statement area rug."
            ],
            suggestedStyles: [.japandi, .scandinavian, .minimalist],
            analyzedAt: .now
        )
    }

    private func makeFallbackBudgetItems(for style: DesignStyle, totalBudget: Double) -> [BudgetItem] {
        [
            BudgetItem(name: "Seating",         category: "Furniture", estimatedCost: totalBudget * 0.30, priority: .essential,    isOptional: false),
            BudgetItem(name: "Lighting",         category: "Lighting",  estimatedCost: totalBudget * 0.15, priority: .essential,    isOptional: false),
            BudgetItem(name: "Storage",          category: "Furniture", estimatedCost: totalBudget * 0.20, priority: .recommended,  isOptional: false),
            BudgetItem(name: "Rugs & Textiles",  category: "Soft",      estimatedCost: totalBudget * 0.15, priority: .recommended,  isOptional: false),
            BudgetItem(name: "Decor & Plants",   category: "Decor",     estimatedCost: totalBudget * 0.10, priority: .optional,     isOptional: true),
            BudgetItem(name: "Paint & Finish",   category: "Finish",    estimatedCost: totalBudget * 0.10, priority: .essential,    isOptional: false)
        ]
    }

    nonisolated private func estimatedCost(for style: DesignStyle, area: Double) -> Double {
        let rate: Double
        switch style {
        case .modernLuxury: rate = 180
        case .bohemian:     rate = 80
        case .minimalist:   rate = 60
        default:            rate = 100
        }
        return rate * area
    }

}
