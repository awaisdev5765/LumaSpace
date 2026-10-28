import CoreSpotlight
import UIKit

final class SpotlightService {
    static let shared = SpotlightService()
    private let domainID = "com.lumaspace.projects"

    @MainActor
    func indexAllProjects() {
        indexProjects(ProjectStore.shared.projects)
    }

    func indexProjects(_ projects: [Project]) {
        let items = projects.map { project -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title       = project.name
            attrs.contentDescription = "\(project.roomCount) room\(project.roomCount == 1 ? "" : "s") · updated \(project.updatedAt.formatted(date: .abbreviated, time: .omitted))"
            attrs.keywords    = project.tags + [project.name]
            attrs.thumbnailData = project.thumbnailData

            let item = CSSearchableItem(
                uniqueIdentifier: project.id.uuidString,
                domainIdentifier: domainID,
                attributeSet: attrs
            )
            item.expirationDate = .distantFuture
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("[Spotlight] Indexing error: \(error)") }
        }
    }

    func removeProject(_ project: Project) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [project.id.uuidString])
    }

    func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainID])
    }

    func handle(_ activity: NSUserActivity) {
        guard
            activity.activityType == CSSearchableItemActionType,
            let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return }

        Task { @MainActor in
            if let project = ProjectStore.shared.projects.first(where: { $0.id.uuidString == id }) {
                AppState.shared.activeProject = project
                AppState.shared.activeTab = .home
                AnalyticsService.shared.track(.spotlightOpened, properties: ["project": project.name])
            }
        }
    }
}
