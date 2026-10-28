import Foundation
import SwiftUI
import Combine
import WidgetKit

@MainActor
final class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published var projects: [Project] = []
    @Published var isLoading = false

    private let saveURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("lumaspace_projects.json")
    }()

    init() {
        load()
        SpotlightService.shared.indexProjects(projects)
    }

    // MARK: CRUD

    func create(name: String = "Untitled Project") -> Project {
        let project = Project.empty(name: name)
        projects.insert(project, at: 0)
        save()
        AnalyticsService.shared.track(.projectCreated)
        return project
    }

    func update(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        updated.updatedAt = .now
        projects[idx] = updated
        save()
        SpotlightService.shared.indexProjects([updated])
        if Config.cloudKitEnabled {
            Task { await CloudSyncService.shared.syncProject(updated) }
        }
    }

    func delete(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        save()
        SpotlightService.shared.removeProject(project)
        if Config.cloudKitEnabled {
            Task { await CloudSyncService.shared.deleteProject(project) }
        }
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { projects[$0] }
        projects.remove(atOffsets: offsets)
        save()
        toDelete.forEach { SpotlightService.shared.removeProject($0) }
    }

    func toggleFavorite(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].isFavorite.toggle()
        save()
    }

    // MARK: Filtering

    var recentProjects: [Project] {
        Array(projects.prefix(5))
    }

    var favoriteProjects: [Project] {
        projects.filter(\.isFavorite)
    }

    func projects(matching query: String) -> [Project] {
        guard !query.isEmpty else { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    // MARK: Persistence

    private func save() {
        syncWidgetData()
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: saveURL, options: .atomicWrite)
        } catch {
            print("[ProjectStore] Save failed: \(error)")
        }
    }

    private func syncWidgetData() {
        guard let project = projects.first else { return }
        let defaults = UserDefaults(suiteName: "group.com.lumaspace.app")
        defaults?.set(project.name,                           forKey: "widget_project_name")
        defaults?.set(project.roomCount,                      forKey: "widget_room_count")
        defaults?.set(project.rooms.first?.score ?? 0,        forKey: "widget_room_score")
        defaults?.set(project.designs.first?.style.rawValue,  forKey: "widget_last_style")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            projects = []   // start fresh — onboarding guides user to first scan
            return
        }
        do {
            let data = try Data(contentsOf: saveURL)
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            projects = []
        }
    }
}
