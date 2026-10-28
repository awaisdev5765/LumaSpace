import SwiftUI
import UserNotifications
import TipKit

enum ConceptFilter: String, CaseIterable {
    case all       = "All"
    case favorites = "Favorites"
    case topRated  = "Top Rated"
}

@MainActor
final class DesignsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var generatedConcepts: [DesignConcept] = []
    @Published var selectedStyles: Set<DesignStyle> = [.japandi]
    @Published var selectedRoom: Room?
    @Published var conceptSearchText = ""
    @Published var conceptFilter: ConceptFilter = .all
    @Published var lastAppliedPrompt: String?

    // Compare flow
    @Published var compareFirst: DesignConcept?
    @Published var compareSecond: DesignConcept?
    @Published var showComparison = false

    // Redo flow
    @Published var isRedoing = false
    @Published var redoPrompt = ""
    @Published var redoConcept: DesignConcept?
    @Published var showRedoSheet = false

    // Notification pre-prompt
    @Published var showNotifPrePrompt = false

    // MARK: - Services

    private let projectStore  = ProjectStore.shared
    private let aiService     = AIDesignService.shared
    private let store         = StoreService.shared
    private let appState      = AppState.shared

    // MARK: - Computed

    var availableRooms: [Room] {
        projectStore.projects.flatMap(\.rooms)
    }

    var filteredConcepts: [DesignConcept] {
        var results = generatedConcepts
        if !conceptSearchText.isEmpty {
            results = results.filter {
                $0.title.localizedCaseInsensitiveContains(conceptSearchText) ||
                $0.style.rawValue.localizedCaseInsensitiveContains(conceptSearchText) ||
                $0.description.localizedCaseInsensitiveContains(conceptSearchText)
            }
        }
        switch conceptFilter {
        case .all:       break
        case .favorites: results = results.filter(\.isFavorite)
        case .topRated:  results = results.filter { $0.rating == .thumbsUp }
        }
        return results
    }

    // MARK: - Actions

    func generateConcepts() async {
        guard let room = selectedRoom ?? availableRooms.first else { return }

        if store.currentTier == .free && appState.isAtRedesignLimit {
            appState.isShowingSubscription = true
            LumaHaptics.notification(.warning)
            return
        }

        LumaHaptics.impact(.medium)
        compareFirst = nil
        compareSecond = nil
        AnalyticsService.shared.track(.designGenerated, properties: [
            "styles": selectedStyles.map(\.rawValue),
            "room_type": room.type.rawValue,
            "tier": store.currentTier.rawValue
        ])

        let concepts = await aiService.generateDesigns(
            for: room,
            styles: Array(selectedStyles),
            tier: store.currentTier
        )

        let noMotion = UIAccessibility.isReduceMotionEnabled
        withAnimation(noMotion ? .none : .lumaSpring) {
            generatedConcepts = concepts
            conceptSearchText = ""
            conceptFilter = .all
        }

        if store.currentTier == .free {
            appState.recordRedesignUsed()
        }

        saveConceptsToProject(concepts, room: room)
        LumaHaptics.notification(.success)
        appState.notifyDesignsReady()
        Task { await ARPlacementTip.designGenerated.donate() }

        if !concepts.isEmpty {
            let status = await UNUserNotificationCenter.current().notificationSettings()
            switch status.authorizationStatus {
            case .notDetermined:
                if !appState.hasSeenNotificationPrePrompt {
                    appState.hasSeenNotificationPrePrompt = true
                    showNotifPrePrompt = true
                }
            case .authorized, .provisional, .ephemeral:
                NotificationService.shared.schedulePostDesignNudge()
                NotificationService.shared.scheduleWeeklyInspiration()
            default:
                break
            }
        }

        if store.currentTier == .free && !appState.hasSeenFirstDesignPaywall && !concepts.isEmpty {
            appState.hasSeenFirstDesignPaywall = true
            try? await Task.sleep(for: .seconds(1.8))
            appState.isShowingSubscription = true
        }
    }

    func redoWithChanges(concept: DesignConcept) async {
        guard !redoPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let room = availableRooms.first else { return }

        if store.currentTier == .free && appState.isAtRedesignLimit {
            appState.isShowingSubscription = true
            return
        }

        isRedoing = true
        LumaHaptics.impact(.medium)
        AnalyticsService.shared.track(.designGenerated, properties: [
            "source": "redo_with_changes",
            "style": concept.style.rawValue
        ])

        let modifiedConcepts = await aiService.generateDesigns(
            for: room,
            styles: [concept.style],
            tier: store.currentTier,
            additionalPrompt: redoPrompt
        )

        let noMotion = UIAccessibility.isReduceMotionEnabled
        isRedoing = false
        showRedoSheet = false

        if let newConcept = modifiedConcepts.first {
            withAnimation(noMotion ? .none : .lumaSpring) {
                if let idx = generatedConcepts.firstIndex(where: { $0.id == concept.id }) {
                    generatedConcepts[idx] = newConcept
                } else {
                    generatedConcepts.insert(newConcept, at: 0)
                }
                lastAppliedPrompt = redoPrompt
            }
            saveConceptsToProject([newConcept], room: room)
            LumaHaptics.notification(.success)
            appState.notifyDesignsReady()
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.lumaFast) { lastAppliedPrompt = nil }
            }
        }

        if store.currentTier == .free { appState.recordRedesignUsed() }
    }

    func startQuickRefine(with text: String) async {
        guard let concept = generatedConcepts.first else { return }
        redoConcept = concept
        redoPrompt = text
        await redoWithChanges(concept: concept)
    }

    func rateConceptLocally(_ concept: DesignConcept, rating: DesignRating) {
        if let idx = generatedConcepts.firstIndex(where: { $0.id == concept.id }) {
            generatedConcepts[idx].rating = rating
        }
        for var project in projectStore.projects {
            if let idx = project.designs.firstIndex(where: { $0.id == concept.id }) {
                project.designs[idx].rating = rating
                projectStore.update(project)
                break
            }
        }
        AnalyticsService.shared.track(.designFavorited, properties: [
            "style": concept.style.rawValue,
            "rating": rating.rawValue
        ])
    }

    func selectForCompare(_ concept: DesignConcept) {
        LumaHaptics.impact(.medium)
        if compareFirst == nil {
            compareFirst = concept
        } else if compareSecond == nil && concept.id != compareFirst?.id {
            compareSecond = concept
            showComparison = true
        } else {
            compareFirst = concept
            compareSecond = nil
        }
    }

    // MARK: - Private

    private func saveConceptsToProject(_ concepts: [DesignConcept], room: Room) {
        guard !concepts.isEmpty,
              var project = projectStore.projects.first(where: { p in
                  p.rooms.contains { $0.id == room.id }
              })
        else { return }
        project.designs.append(contentsOf: concepts)
        projectStore.update(project)
    }
}
