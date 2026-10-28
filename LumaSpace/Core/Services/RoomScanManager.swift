import RoomPlan
import RealityKit
import ARKit
import SwiftUI
import Combine

// MARK: - Scan State

enum ScanState: Equatable {
    case idle
    case preparing
    case scanning(progress: Double)
    case processing
    case completed(Room)
    case failed(String)

    var isActive: Bool {
        switch self { case .scanning, .processing: return true; default: return false }
    }
}

// MARK: - Scan Instruction

enum ScanInstruction: String {
    case moveCloser   = "Move closer to walls"
    case moveFarther  = "Move farther from wall"
    case moveSlowly   = "Move more slowly"
    case captureDoor  = "Capture the doorway"
    case captureWindow = "Move to a window"
    case scanCorner   = "Scan the corners"
    case ready        = "Point camera at the room to begin"
}

// MARK: - Manager

@MainActor
final class RoomScanManager: NSObject, ObservableObject {
    static let shared = RoomScanManager()

    @Published var state: ScanState = .idle
    @Published var instruction: ScanInstruction = .ready
    @Published var scannedWalls: Int = 0
    @Published var scannedDoors: Int = 0
    @Published var scannedWindows: Int = 0
    @Published var scannedFurniture: Int = 0
    @Published var roomName: String = "My Room"
    @Published var roomType: Room.RoomType = .livingRoom

    // Last live CapturedRoom from didUpdate — used for dimension extraction
    private var lastCapturedRoom: CapturedRoom?
    // The session is owned by RoomCaptureView; we hold a weak ref for stop/cancel
    weak var activeSession: RoomCaptureSession?
    private var config = RoomCaptureSession.Configuration()

    func startScan() {
        guard ARWorldTrackingConfiguration.isSupported else {
            state = .failed("AR not supported on this device.")
            return
        }
        state = .scanning(progress: 0)
    }

    func stopScan(session: RoomCaptureSession) {
        session.stop(pauseARSession: false)
        state = .processing
    }

    func cancelScan(session: RoomCaptureSession) {
        session.stop(pauseARSession: true)
        state = .idle
        reset()
    }

    func reset() {
        scannedWalls = 0
        scannedDoors = 0
        scannedWindows = 0
        scannedFurniture = 0
        lastCapturedRoom = nil
        instruction = .ready
    }

    var completedRoom: Room? {
        guard case .completed(let room) = state else { return nil }
        return room
    }
}

// MARK: - RoomCaptureSessionDelegate

extension RoomScanManager: RoomCaptureSessionDelegate {
    nonisolated func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        Task { @MainActor in
            lastCapturedRoom = room
            scannedWalls     = room.walls.count
            scannedDoors     = room.doors.count
            scannedWindows   = room.windows.count
            scannedFurniture = room.objects.count
            state = .scanning(progress: computeProgress(room))
            instruction = computeInstruction(room)
        }
    }

    nonisolated func captureSession(
        _ session: RoomCaptureSession,
        didEndWith data: CapturedRoomData,
        error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                state = .failed(error.localizedDescription)
                return
            }
            let room = buildRoom()
            state = .completed(room)
            LumaHaptics.notification(.success)
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession,
                                    didProvide instruction: RoomCaptureSession.Instruction) {
        Task { @MainActor in
            self.instruction = mapInstruction(instruction)
        }
    }

    // MARK: - Private helpers

    private func computeProgress(_ room: CapturedRoom) -> Double {
        let walls   = min(Double(room.walls.count) / 4.0, 1.0)
        let doors   = min(Double(room.doors.count), 1.0)
        let windows = min(Double(room.windows.count), 1.0)
        return walls * 0.6 + doors * 0.2 + windows * 0.2
    }

    private func computeInstruction(_ room: CapturedRoom) -> ScanInstruction {
        if room.walls.count < 4  { return .scanCorner }
        if room.doors.count == 0 { return .captureDoor }
        if room.windows.count == 0 { return .captureWindow }
        return .ready
    }

    private func mapInstruction(_ i: RoomCaptureSession.Instruction) -> ScanInstruction {
        switch i {
        case .moveCloseToWall:  return .moveCloser
        case .moveAwayFromWall: return .moveFarther
        case .slowDown:         return .moveSlowly
        case .normal, .turnOnLight, .lowTexture: return .ready
        @unknown default:       return .ready
        }
    }

    private func buildRoom() -> Room {
        let dims  = extractDimensions()
        let walls = extractWallGeometry()
        let usdz  = exportUSDZ()
        return Room(
            name: roomName,
            type: roomType,
            dimensions: dims,
            scanDate: .now,
            score: 0,
            issues: [],
            furnitureItems: [],
            scanDataURL: usdz,
            capturedWalls: walls
        )
    }

    /// Exports the final CapturedRoom to a USDZ file in the app's Documents/scans directory.
    private func exportUSDZ() -> URL? {
        guard let room = lastCapturedRoom else { return nil }
        let scansDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scans", isDirectory: true)
        let url = scansDir.appendingPathComponent("\(UUID().uuidString).usdz")
        do {
            try FileManager.default.createDirectory(at: scansDir, withIntermediateDirectories: true)
            try room.export(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func extractWallGeometry() -> [CapturedWall] {
        guard let room = lastCapturedRoom else { return [] }
        return room.walls.map { wall in
            let pos   = wall.transform.columns.3
            let fwd   = wall.transform.columns.0   // local X = wall-length direction
            let angle = atan2(fwd.z, fwd.x)
            return CapturedWall(
                centerX: pos.x,
                centerZ: pos.z,
                width:   abs(wall.dimensions.x),
                height:  abs(wall.dimensions.y),
                angle:   angle
            )
        }
    }

    private func extractDimensions() -> RoomDimensions {
        guard let room = lastCapturedRoom, !room.walls.isEmpty else {
            return RoomDimensions(width: 4.0, length: 5.0, ceilingHeight: 2.4)
        }

        // Derive the room footprint from wall centre positions.
        // wall.transform.columns.3 is the world-space centre of each wall panel.
        // X and Z give the floor-plane extent; Y is elevation (not used here).
        let centres = room.walls.map { wall -> (x: Float, z: Float) in
            let col = wall.transform.columns.3
            return (x: col.x, z: col.z)
        }

        let allX = centres.map(\.x)
        let allZ = centres.map(\.z)

        let spanX = Double((allX.max() ?? 4.0) - (allX.min() ?? 0.0))
        let spanZ = Double((allZ.max() ?? 5.0) - (allZ.min() ?? 0.0))

        // Add half-a-wall-thickness on each side (~0.1 m) to reach the inner face of opposite walls.
        let width  = max(spanX + 0.2, 1.5)
        let length = max(spanZ + 0.2, 1.5)

        // Ceiling height: use the tallest wall panel height (wall.dimensions.y)
        let ceilingHeight = Double(room.walls.map { abs($0.dimensions.y) }.max() ?? 2.4)

        return RoomDimensions(
            width:         width,
            length:        length,
            ceilingHeight: max(ceilingHeight, 2.0)
        )
    }
}

// MARK: - RoomCaptureView Representable

struct RoomCaptureViewRepresentable: UIViewRepresentable {
    @ObservedObject var manager: RoomScanManager

    func makeUIView(context: Context) -> RoomCaptureView {
        let captureView = RoomCaptureView(frame: .zero)
        // RoomCaptureView owns the session; wire our delegate to it
        captureView.captureSession.delegate = manager
        manager.activeSession = captureView.captureSession
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
