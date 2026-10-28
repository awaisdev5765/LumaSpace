import Foundation
import UIKit

// MARK: - OpenAI Service

final class OpenAIService {
    static let shared = OpenAIService()

    private var apiKey: String { Config.openAIKey }
    private let baseURL    = "https://api.openai.com/v1"
    private let chatModel  = Config.chatModel
    private let imageModel = Config.imageModel

    private var headers: [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    // MARK: - Room Analysis

    func analyzeRoom(_ room: Room) async throws -> RoomAnalysis {
        let prompt = """
        You are an expert interior designer. Analyze this room and respond with valid JSON only — no markdown, no code fences.

        Room data:
        - Type: \(room.type.rawValue)
        - Dimensions: \(room.dimensions.width)m × \(room.dimensions.length)m
        - Ceiling height: \(room.dimensions.ceilingHeight)m
        - Area: \(String(format: "%.1f", room.area))m²
        - Existing furniture count: \(room.furnitureItems.count)

        Respond with this exact JSON structure:
        {
          "roomScore": <int 0-100>,
          "lightingScore": <int 0-100>,
          "flowScore": <int 0-100>,
          "utilizationScore": <int 0-100>,
          "issues": [
            {"severity": "low|medium|high", "title": "...", "description": "...", "suggestion": "..."}
          ],
          "opportunities": ["...", "..."],
          "suggestedStyles": ["Japandi", "Scandinavian"]
        }
        """

        let response = try await chatCompletion(systemPrompt: "You are an expert interior designer. Respond with JSON only.", userPrompt: prompt)
        let data = Data(response.utf8)
        let decoded = try JSONDecoder().decode(RoomAnalysisResponse.self, from: data)

        return RoomAnalysis(
            roomScore: decoded.roomScore,
            lightingScore: decoded.lightingScore,
            flowScore: decoded.flowScore,
            utilizationScore: decoded.utilizationScore,
            issues: decoded.issues.map {
                RoomIssue(
                    severity: RoomIssue.Severity(rawValue: $0.severity) ?? .low,
                    title: $0.title,
                    description: $0.description,
                    suggestion: $0.suggestion
                )
            },
            opportunities: decoded.opportunities,
            suggestedStyles: decoded.suggestedStyles.compactMap { DesignStyle(rawValue: $0) },
            analyzedAt: .now
        )
    }

    // MARK: - Design Concept Text

    func generateDesignConcept(style: DesignStyle, room: Room, additionalPrompt: String? = nil) async throws -> DesignConceptText {
        let refinement = additionalPrompt.map { "\n\nUser refinement request: \($0)" } ?? ""
        let prompt = """
        You are a world-class interior designer. Create a design concept for this room.

        Style: \(style.rawValue)
        Style description: \(style.description)
        Room: \(room.type.rawValue), \(String(format: "%.1f", room.area))m²\(refinement)

        Respond with valid JSON only:
        {
          "title": "...",
          "description": "2-3 sentence evocative description of the design",
          "keyPieces": ["sofa", "coffee table", "floor lamp"],
          "colorStory": "1 sentence describing the color approach",
          "estimatedCost": <number in USD>,
          "furnitureSuggestions": [
            {
              "name": "...",
              "category": "sofa|chair|table|bed|desk|storage|lighting|rug|decor|plant",
              "estimatedPrice": <number>,
              "width": <meters>,
              "depth": <meters>,
              "height": <meters>
            }
          ]
        }
        """

        let response = try await chatCompletion(
            systemPrompt: "You are a world-class interior designer. Respond with JSON only.",
            userPrompt: prompt
        )
        let data = Data(response.utf8)
        return try JSONDecoder().decode(DesignConceptText.self, from: data)
    }

    // MARK: - Design Image (DALL·E 3)

    func generateDesignImage(style: DesignStyle, room: Room, additionalPrompt: String? = nil) async throws -> UIImage {
        let refinement = additionalPrompt.map { " \($0)." } ?? ""
        let prompt = """
        Professional interior design photo, \(style.rawValue) style, \
        \(room.type.rawValue.lowercased()), \
        \(String(format: "%.0f", room.area))sqm room,\(refinement) \
        photorealistic, architectural photography,
        high-end, natural light, beautifully staged. No text, no watermarks.
        """

        let body: [String: Any] = [
            "model":   imageModel,
            "prompt":  prompt,
            "n":       1,
            "size":    "1024x1024",
            "quality": "standard"
        ]

        let result = try await post(endpoint: "/images/generations", body: body)
        guard
            let data = result["data"] as? [[String: Any]],
            let urlString = data.first?["url"] as? String,
            let url = URL(string: urlString)
        else { throw OpenAIError.invalidResponse }

        let (imageData, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: imageData) else { throw OpenAIError.invalidResponse }
        return image
    }

    // MARK: - Future Vision

    func generateFutureVision(room: Room, scenario: FutureVisionScenario, budget: Double) async throws -> (text: String, image: UIImage) {
        let prompt = """
        You are an expert interior designer. Describe a \(scenario.rawValue.lowercased()) transformation
        for this \(room.type.rawValue.lowercased()) (\(String(format: "%.0f", room.area))m²)
        with a $\(Int(budget)) budget.

        Respond with JSON only:
        {
          "vision": "3-4 sentence vivid description of the transformed room",
          "keyChanges": ["...", "..."],
          "estimatedSavings": "...",
          "timelineWeeks": <int>
        }
        """

        async let text = chatCompletion(
            systemPrompt: "You are an expert interior designer. Respond with JSON only.",
            userPrompt: prompt
        )
        async let image = generateFutureVisionImage(room: room, scenario: scenario)

        return try await (text, image)
    }

    private func generateFutureVisionImage(room: Room, scenario: FutureVisionScenario) async throws -> UIImage {
        let imagePrompt = """
        Stunning \(scenario.rawValue.lowercased()) interior design transformation,
        \(room.type.rawValue.lowercased()), photorealistic, architectural photography,
        beautiful natural lighting, magazine quality, no text.
        """
        let body: [String: Any] = [
            "model": imageModel, "prompt": imagePrompt, "n": 1, "size": "1024x1024"
        ]
        let result = try await post(endpoint: "/images/generations", body: body)
        guard
            let data = result["data"] as? [[String: Any]],
            let urlString = data.first?["url"] as? String,
            let url = URL(string: urlString)
        else { throw OpenAIError.invalidResponse }
        let (imageData, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: imageData) else { throw OpenAIError.invalidResponse }
        return image
    }

    // MARK: - Color Palette

    func generateColorPalette(style: DesignStyle, room: Room) async throws -> ColorPaletteAI {
        let prompt = """
        Create a color palette for a \(style.rawValue) \(room.type.rawValue.lowercased()).

        Respond with JSON only:
        {
          "wallColor": "#RRGGBB",
          "accentWallColor": "#RRGGBB",
          "floorColor": "#RRGGBB",
          "primaryFurnitureColor": "#RRGGBB",
          "accentColor": "#RRGGBB",
          "textileColor": "#RRGGBB",
          "rationale": "1 sentence explaining the palette"
        }
        """
        let response = try await chatCompletion(
            systemPrompt: "You are a color theory expert. Respond with JSON only.",
            userPrompt: prompt
        )
        return try JSONDecoder().decode(ColorPaletteAI.self, from: Data(response.utf8))
    }

    // MARK: - Budget Plan

    func generateBudgetPlan(style: DesignStyle, room: Room, budget: Double) async throws -> [BudgetItem] {
        let prompt = """
        Create a prioritized budget plan for a \(style.rawValue) \(room.type.rawValue.lowercased()) refresh.
        Total budget: $\(Int(budget))
        Room area: \(String(format: "%.0f", room.area))m²

        Respond with JSON only:
        {
          "items": [
            {
              "name": "...",
              "category": "...",
              "estimatedCost": <number>,
              "priority": "essential|recommended|optional",
              "isOptional": <bool>
            }
          ]
        }
        """
        let response = try await chatCompletion(
            systemPrompt: "You are an interior design budget expert. Respond with JSON only.",
            userPrompt: prompt
        )
        let decoded = try JSONDecoder().decode(BudgetPlanResponse.self, from: Data(response.utf8))
        return decoded.items.map {
            BudgetItem(
                name: $0.name,
                category: $0.category,
                estimatedCost: $0.estimatedCost,
                priority: BudgetItem.Priority(rawValue: $0.priority) ?? .recommended,
                isOptional: $0.isOptional
            )
        }
    }

    // MARK: - Smart Furniture Fit Check

    func checkFurnitureFit(item: FurnitureItem, room: Room) async throws -> FitCheckResult {
        let prompt = """
        Check if this furniture fits well in this room. Respond with JSON only:

        Furniture: \(item.name), \(item.dimensions.width)m × \(item.dimensions.depth)m × \(item.dimensions.height)m
        Room: \(room.dimensions.width)m × \(room.dimensions.length)m, \(room.type.rawValue)
        Other furniture count: \(room.furnitureItems.count)

        {
          "fits": <bool>,
          "warningLevel": "none|caution|warning",
          "message": "...",
          "walkwayClearance": <meters remaining>,
          "suggestion": "..."
        }
        """
        let response = try await chatCompletion(
            systemPrompt: "You are a spatial planning expert. Respond with JSON only.",
            userPrompt: prompt
        )
        return try JSONDecoder().decode(FitCheckResult.self, from: Data(response.utf8))
    }

    // MARK: - Image-Aware Virtual Staging
    // Step 1: GPT-4o Vision describes the real room's architecture.
    // Step 2: DALL·E 3 generates a staged version grounded in that description.
    // This is far more accurate than using DALL·E 3 blind with only a text prompt.

    func generateVirtualStagingFromPhoto(_ photo: UIImage, style: DesignStyle) async throws -> UIImage {
        let roomDescription = try await describeRoomFromPhoto(photo)
        let stagingPrompt = """
        Photorealistic interior design photo, \(style.rawValue) style, fully furnished and decorated.
        Room description: \(roomDescription)
        Requirements: professional staging, beautiful natural lighting, magazine quality, \
        \(style.rawValue) furniture and materials, cohesive colour palette. \
        No people, no text, no watermarks.
        """
        let body: [String: Any] = [
            "model":   imageModel,
            "prompt":  stagingPrompt,
            "n":       1,
            "size":    "1024x1024",
            "quality": "standard"
        ]
        let result = try await post(endpoint: "/images/generations", body: body)
        guard
            let data     = result["data"]     as? [[String: Any]],
            let urlStr   = data.first?["url"] as? String,
            let url      = URL(string: urlStr)
        else { throw OpenAIError.invalidResponse }
        let (imageData, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: imageData) else { throw OpenAIError.invalidResponse }
        return image
    }

    /// Uses GPT-4o Vision to extract a concise architectural description from a photo.
    func describeRoomFromPhoto(_ photo: UIImage) async throws -> String {
        guard let jpeg = photo.jpegData(compressionQuality: 0.7) else {
            throw OpenAIError.invalidResponse
        }
        let base64 = jpeg.base64EncodedString()
        let body: [String: Any] = [
            "model": chatModel,
            "max_tokens": 200,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                    ],
                    [
                        "type": "text",
                        "text": """
                        Describe this room's fixed architectural features only — do NOT describe furniture \
                        or decor. Include: estimated dimensions, flooring type and colour, wall colour, \
                        ceiling height, number and position of windows, natural light direction, and any \
                        fixed elements (fireplace, built-in shelving, columns, alcoves). \
                        Be specific and concise. Maximum 3 sentences.
                        """
                    ]
                ]
            ]]
        ]
        let result = try await post(endpoint: "/chat/completions", body: body)
        guard
            let choices = result["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw OpenAIError.invalidResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Core Networking

    func chatCompletion(systemPrompt: String, userPrompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": chatModel,
            "temperature": 0.7,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ]
        ]
        let result = try await post(endpoint: "/chat/completions", body: body)
        guard
            let choices = result["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw OpenAIError.invalidResponse }

        // Strip markdown code fences if model adds them
        return content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```\n", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func post(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard !apiKey.isEmpty, apiKey != "YOUR_OPENAI_API_KEY_HERE" else { throw OpenAIError.missingAPIKey }  // Replace Config.openAIKey before shipping
        guard let url = URL(string: baseURL + endpoint) else { throw OpenAIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let errMsg = (msg?["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(http.statusCode)"
            throw OpenAIError.apiError(errMsg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIError.invalidResponse
        }
        return json
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "OpenAI API key not configured. Set Config.openAIKey in Config.swift."
        case .invalidURL:         return "Invalid API URL."
        case .invalidResponse:    return "Unexpected response from OpenAI."
        case .apiError(let msg):  return "OpenAI error: \(msg)"
        }
    }
}

// MARK: - Decodable Response Models

struct RoomAnalysisResponse: Decodable {
    let roomScore: Int
    let lightingScore: Int
    let flowScore: Int
    let utilizationScore: Int
    let issues: [IssueResponse]
    let opportunities: [String]
    let suggestedStyles: [String]

    struct IssueResponse: Decodable {
        let severity: String
        let title: String
        let description: String
        let suggestion: String
    }
}

struct DesignConceptText: Decodable {
    let title: String
    let description: String
    let keyPieces: [String]
    let colorStory: String
    let estimatedCost: Double
    let furnitureSuggestions: [FurnitureSuggestion]

    struct FurnitureSuggestion: Decodable {
        let name: String
        let category: String
        let estimatedPrice: Double
        let width: Double
        let depth: Double
        let height: Double
    }
}

struct ColorPaletteAI: Decodable {
    let wallColor: String
    let accentWallColor: String
    let floorColor: String
    let primaryFurnitureColor: String
    let accentColor: String
    let textileColor: String
    let rationale: String
}

struct BudgetPlanResponse: Decodable {
    let items: [Item]
    struct Item: Decodable {
        let name: String
        let category: String
        let estimatedCost: Double
        let priority: String
        let isOptional: Bool
    }
}

struct FitCheckResult: Decodable {
    let fits: Bool
    let warningLevel: String
    let message: String
    let walkwayClearance: Double
    let suggestion: String
}
