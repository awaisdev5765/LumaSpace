import Foundation
import CloudKit
import Combine

// MARK: - Cloud Sync Service

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSynced: Date?

    private let container = CKContainer(identifier: "iCloud.com.lumaspace.app")
    private var database: CKDatabase { container.privateCloudDatabase }

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case completed(Date)
        case failed(String)

        var description: String {
            switch self {
            case .idle:                return "Not synced"
            case .syncing:             return "Syncing…"
            case .completed(let date): return "Synced \(date.formatted(date: .omitted, time: .shortened))"
            case .failed(let msg):     return "Sync failed: \(msg)"
            }
        }
    }

    // MARK: - Account Check

    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch { return false }
    }

    // MARK: - Single Project Sync (called from ProjectStore)

    func syncProject(_ project: Project) async {
        guard await checkAccountStatus() else { return }
        syncStatus = .syncing
        do {
            let record = try makeRecord(for: project)
            let _ = try await database.modifyRecords(saving: [record], deleting: [])
            let now = Date.now
            syncStatus = .completed(now)
            lastSynced = now
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    func deleteProject(_ project: Project) async {
        guard await checkAccountStatus() else { return }
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        do {
            let _ = try await database.modifyRecords(saving: [], deleting: [recordID])
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Push Projects (bulk)

    func syncProjects(_ projects: [Project]) async {
        guard await checkAccountStatus() else {
            syncStatus = .failed("iCloud account not available.")
            return
        }

        syncStatus = .syncing
        do {
            let records = try projects.map { try makeRecord(for: $0) }
            let _ = try await database.modifyRecords(saving: records, deleting: [])
            let now = Date.now
            syncStatus = .completed(now)
            lastSynced = now
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Projects

    func fetchProjects() async throws -> [Project] {
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let (results, _) = try await database.records(matching: query)
        return try results.compactMap { _, result in
            let record = try result.get()
            return try project(from: record)
        }
    }

    // MARK: - Record Conversion

    private func makeRecord(for project: Project) throws -> CKRecord {
        let record = CKRecord(recordType: "Project", recordID: CKRecord.ID(recordName: project.id.uuidString))
        // Strip all binary image data before encoding so the record stays well under
        // CloudKit's 1 MB per-field limit. Images remain on-device only.
        let stripped = project.strippedForSync
        let data = try JSONEncoder().encode(stripped)
        record["data"] = data as CKRecordValue
        record["name"] = project.name as CKRecordValue
        record["updatedAt"] = project.updatedAt as CKRecordValue
        return record
    }

    private func project(from record: CKRecord) throws -> Project {
        guard let data = record["data"] as? Data else { throw CloudError.invalidRecord }
        return try JSONDecoder().decode(Project.self, from: data)
    }

    enum CloudError: Error {
        case invalidRecord
    }
}
