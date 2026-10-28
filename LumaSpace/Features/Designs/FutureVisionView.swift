import SwiftUI

struct FutureVisionView: View {
    let room: Room
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiService: AIDesignService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedScenario: FutureVisionScenario = .luxury
    @State private var budget: Double = 10000
    @State private var isGenerating = false
    @State private var resultText: String?
    @State private var resultImageData: Data?
    @State private var showUpgrade = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    if !store.canAccessFeature(requiring: .premium) {
                        premiumGate
                    } else {
                        scenarioPicker
                        budgetSlider
                        generateButton

                        if isGenerating {
                            generatingView
                        } else if let imageData = resultImageData,
                                  let img = UIImage(data: imageData) {
                            resultView(image: img, text: resultText ?? "")
                        } else {
                            emptyPrompt
                        }
                    }
                }
                .padding()
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Future Vision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showUpgrade) {
            SubscriptionView(context: .featureGate("Future Vision"))
        }
    }

    // MARK: - Scenario Picker

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            Text("Choose Scenario").font(LumaFont.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LumaSpacing.sm) {
                ForEach(FutureVisionScenario.allCases) { scenario in
                    ScenarioCard(
                        scenario: scenario,
                        isSelected: selectedScenario == scenario
                    ) { selectedScenario = scenario }
                }
            }
        }
    }

    // MARK: - Budget Slider

    private var budgetSlider: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack {
                Text("Budget").font(LumaFont.headline)
                Spacer()
                Text("$\(Int(budget).formatted())")
                    .font(LumaFont.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Luma.accent)
                    .monospacedDigit()
            }
            Slider(value: $budget, in: 500...50000, step: 500)
                .tint(Color.Luma.accent)
            HStack {
                Text("$500").font(LumaFont.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("$50K").font(LumaFont.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
    }

    // MARK: - Generate

    private var generateButton: some View {
        LumaPrimaryButton(
            "Generate Future Vision",
            icon: "sparkles",
            isLoading: isGenerating
        ) {
            Task { await generate() }
        }
    }

    private var generatingView: some View {
        VStack(spacing: LumaSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.Luma.accent)
                .symbolEffect(.pulse)

            Text("Imagining your \(selectedScenario.rawValue.lowercased())…")
                .font(LumaFont.headline)
                .multilineTextAlignment(.center)
            Text("DALL·E 3 is rendering your future room. This takes ~15 seconds.")
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, LumaSpacing.xxxl)
    }

    private var emptyPrompt: some View {
        VStack(spacing: LumaSpacing.md) {
            Image(systemName: selectedScenario.icon)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Color.Luma.accent)
                .symbolRenderingMode(.hierarchical)
            Text(selectedScenario.rawValue)
                .font(LumaFont.title3)
            Text("Tap Generate to see your room reimagined with AI.")
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, LumaSpacing.xxxl)
    }

    @ViewBuilder
    private func resultView(image: UIImage, text: String) -> some View {
        VStack(spacing: LumaSpacing.lg) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                .lumaShadow(radius: 20, y: 8, opacity: 0.15)

            if let data = try? JSONDecoder().decode(FutureVisionTextResponse.self, from: Data(text.utf8)) {
                VStack(alignment: .leading, spacing: LumaSpacing.md) {
                    Text("Your \(selectedScenario.rawValue)")
                        .font(LumaFont.title3)
                    Text(data.vision)
                        .font(LumaFont.body)
                        .foregroundStyle(.secondary)

                    if !data.keyChanges.isEmpty {
                        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                            Text("Key Changes").font(LumaFont.headline)
                            ForEach(data.keyChanges, id: \.self) { change in
                                Label(change, systemImage: "checkmark.circle.fill")
                                    .font(LumaFont.subhead)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(spacing: LumaSpacing.lg) {
                        if let savings = data.estimatedSavings {
                            VStack(alignment: .leading) {
                                Text("Potential Value").font(LumaFont.caption1).foregroundStyle(.secondary)
                                Text(savings).font(LumaFont.subhead).fontWeight(.bold)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Timeline").font(LumaFont.caption1).foregroundStyle(.secondary)
                            Text("\(data.timelineWeeks) weeks").font(LumaFont.subhead).fontWeight(.bold)
                        }
                    }
                }
                .padding(LumaSpacing.md)
                .lumaCard(padding: LumaSpacing.md)
            }

            HStack(spacing: LumaSpacing.md) {
                LumaSecondaryButton("Save to Project", icon: "square.and.arrow.down") {
                    saveVisionToProject(image: image, text: resultText ?? "")
                }
                LumaPrimaryButton("Share", icon: "square.and.arrow.up") { shareImage(image) }
            }
        }
    }

    // MARK: - Premium Gate

    private var premiumGate: some View {
        VStack(spacing: LumaSpacing.xxl) {
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.Luma.goldFallback)

            VStack(spacing: LumaSpacing.md) {
                Text("Future Vision")
                    .font(LumaFont.title2)
                Text("See your room reimagined with AI — luxury upgrade, budget makeover, office conversion, and more.")
                    .font(LumaFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LumaPrimaryButton("Unlock with Premium", icon: "crown.fill") {
                showUpgrade = true
            }
        }
        .padding(.vertical, LumaSpacing.xxxl)
    }

    // MARK: - Actions

    private func saveVisionToProject(image: UIImage, text: String) {
        let parsed = try? JSONDecoder().decode(FutureVisionTextResponse.self, from: Data(text.utf8))
        let description = parsed?.vision ?? text
        let concept = DesignConcept(
            style: selectedScenario.style,
            title: "\(selectedScenario.rawValue) Vision",
            description: description,
            imageData: image.jpegData(compressionQuality: 0.85),
            roomBeforePhotoData: room.beforePhotoData,
            palette: AIDesignService.shared.generatePalette(for: selectedScenario.style),
            furnitureSuggestions: [],
            estimatedCost: budget,
            createdAt: .now,
            tags: ["Future Vision", selectedScenario.rawValue]
        )
        if var project = ProjectStore.shared.projects.first {
            project.designs.append(concept)
            ProjectStore.shared.update(project)
        }
        AnalyticsService.shared.track(.futureVisionSaved, properties: ["scenario": selectedScenario.rawValue])
        LumaHaptics.notification(.success)
    }

    private func generate() async {
        isGenerating = true
        resultText = nil
        resultImageData = nil
        let (text, imageData) = await aiService.generateFutureVision(
            for: room, scenario: selectedScenario, budget: budget
        )
        resultText = text
        resultImageData = imageData
        isGenerating = false
        AnalyticsService.shared.track(.futureVisionGenerated, properties: [
            "scenario": selectedScenario.rawValue, "budget": budget
        ])
        LumaHaptics.notification(.success)
    }

    private func shareImage(_ image: UIImage) {
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }
}

// MARK: - Scenario Card

struct ScenarioCard: View {
    let scenario: FutureVisionScenario
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            LumaHaptics.selection()
            action()
        }) {
            VStack(spacing: LumaSpacing.sm) {
                Image(systemName: scenario.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.Luma.accent)
                Text(scenario.rawValue)
                    .font(LumaFont.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LumaSpacing.md)
            .background(isSelected ? Color.Luma.accent : Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color(uiColor: .separator), lineWidth: 0.5)
            }
            .animation(reduceMotion ? .none : .lumaFast, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct FutureVisionTextResponse: Decodable {
    let vision: String
    let keyChanges: [String]
    let estimatedSavings: String?
    let timelineWeeks: Int
}
