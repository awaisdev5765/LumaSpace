import SwiftUI
import RoomPlan
import ARKit
import AVFoundation
import TipKit

struct ScanView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var scanManager: RoomScanManager
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var aiService: AIDesignService
    @EnvironmentObject private var appState: AppState
    @State private var showScanner = false
    @State private var showRoomTypeSheet = false
    @State private var showScanComplete = false
    @State private var completedRoom: Room?
    @State private var showCameraPermissionAlert = false

    // True when LiDAR/RoomPlan is unavailable (Simulator or non-Pro iPhone)
    private var lidarUnavailable: Bool {
        !ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    private let generateTip = GenerateDesignsTip()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    scanHeader

                    // Contextual tip — shows after first scan
                    TipView(generateTip)
                        .tipBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .padding(.horizontal, LumaSpacing.base)

                    if lidarUnavailable {
                        simulatorBanner
                    } else if store.currentTier == .free {
                        scanLimitBanner
                    }

                    roomTypeSelector
                    scanCTA
                    recentScansSection
                }
                .padding(.horizontal, LumaSpacing.base)
                .padding(.vertical, LumaSpacing.lg)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Scan Room")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerOverlay(manager: scanManager) { room in
                completedRoom = room
                showScanComplete = true
            }
        }
        .onChange(of: appState.shouldAutoStartScan) { _, autoStart in
            guard autoStart else { return }
            appState.shouldAutoStartScan = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if lidarUnavailable { addDemoRoom() } else { startScan() }
            }
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("LumaSpace needs camera access to scan rooms. Please enable it in Settings.")
        }
        .sheet(isPresented: $showScanComplete) {
            if let room = completedRoom {
                ScanCompleteSheet(room: room, preselectedProjectID: appState.activeProject?.id) { savedRoom, targetProject, scanAnother in
                    attachRoomToProject(savedRoom, target: targetProject)
                    if scanAnother {
                        // Brief delay so the sheet fully dismisses before opening the scanner
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if lidarUnavailable {
                                addDemoRoom()
                            } else {
                                startScan()
                            }
                        }
                    }
                }
                .environmentObject(projectStore)
            }
        }
    }

    // MARK: - Sub Views

    private var scanHeader: some View {
        VStack(spacing: LumaSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.Luma.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(Color.Luma.accent)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: LumaSpacing.xs) {
                Text("LiDAR Room Scanner")
                    .font(LumaFont.title3)
                Text("Precise measurements in under 60 seconds.")
                    .font(LumaFont.subhead)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, LumaSpacing.lg)
    }

    private var scanLimitBanner: some View {
        let maxScans = store.currentTier.maxScans ?? 3
        let scansUsed = min(projectStore.projects.flatMap(\.rooms).count, maxScans)
        let remaining = max(maxScans - scansUsed, 0)
        return HStack(spacing: LumaSpacing.md) {
            LumaProgressRing(progress: Double(scansUsed) / Double(maxScans), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(remaining) free scan\(remaining == 1 ? "" : "s") remaining")
                    .font(LumaFont.subhead).fontWeight(.semibold)
                Text("Upgrade for unlimited scanning.")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
    }

    private var roomTypeSelector: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            Text("Room Type").font(LumaFont.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: LumaSpacing.sm) {
                ForEach(Room.RoomType.allCases, id: \.self) { type in
                    RoomTypeButton(
                        type: type,
                        isSelected: scanManager.roomType == type
                    ) {
                        scanManager.roomType = type
                        LumaHaptics.selection()
                    }
                }
            }
        }
    }

    private var simulatorBanner: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack(spacing: LumaSpacing.sm) {
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LiDAR not available")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                    Text("Simulator or non-Pro iPhone detected. Use a demo room to test AI design, AR, and export features.")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(LumaSpacing.md)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        }
    }

    private var isAtScanLimit: Bool {
        guard store.currentTier == .free, let max = store.currentTier.maxScans else { return false }
        return projectStore.projects.flatMap(\.rooms).count >= max
    }

    private var scanCTA: some View {
        VStack(spacing: LumaSpacing.md) {
            if lidarUnavailable {
                // Simulator / no-LiDAR path
                LumaPrimaryButton("Add Demo Room", icon: "square.dashed") {
                    addDemoRoom()
                }
                Text("Creates a realistic sample room so you can test AI design, AR placement, and PDF export.")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                LumaPrimaryButton(
                    isAtScanLimit ? "Upgrade to Scan More" : "Start Scanning",
                    icon: isAtScanLimit ? "crown.fill" : "camera.fill"
                ) {
                    startScan()
                }
                HStack(spacing: LumaSpacing.xs) {
                    Image(systemName: "info.circle").font(.caption)
                    Text("Keep your iPhone steady and walk around the room's perimeter.")
                        .font(LumaFont.caption1)
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
    }

    private var recentScansSection: some View {
        let allRooms = projectStore.projects.flatMap(\.rooms).sorted { $0.scanDate > $1.scanDate }.prefix(5)
        return VStack(alignment: .leading, spacing: LumaSpacing.md) {
            if !allRooms.isEmpty {
                LumaSectionHeader(title: "Recent Scans")
                ForEach(Array(allRooms)) { room in
                    RecentScanRow(room: room)
                }
            }
        }
    }

    // MARK: - Actions

    // MARK: - Demo room for Simulator / non-LiDAR devices

    private func addDemoRoom() {
        LumaHaptics.notification(.success)
        let demoRoom = Room(
            name: scanManager.roomType.rawValue,
            type: scanManager.roomType,
            dimensions: RoomDimensions(
                width: 4.8,
                length: 6.2,
                ceilingHeight: 2.7
            ),
            scanDate: .now,
            score: 0,   // AI analysis sets this after saving
            issues: [],
            furnitureItems: []
        )
        completedRoom = demoRoom
        showScanComplete = true
    }

    // MARK: - Real scan

    private func startScan() {
        // Enforce free-tier scan limit before starting
        if store.currentTier == .free {
            let usedScans = projectStore.projects.flatMap(\.rooms).count
            let maxScans = store.currentTier.maxScans ?? Int.max
            if usedScans >= maxScans {
                appState.isShowingSubscription = true
                LumaHaptics.notification(.warning)
                return
            }
        }

        // Camera permission gate
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            launchScanner()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    if granted { launchScanner() } else { showCameraPermissionAlert = true }
                }
            }
        default:
            showCameraPermissionAlert = true
        }
    }

    private func launchScanner() {
        LumaHaptics.impact(.medium)
        AnalyticsService.shared.track(.scanStarted, properties: ["room_type": scanManager.roomType.rawValue])
        scanManager.reset()
        scanManager.startScan()
        showScanner = true
    }

    private func attachRoomToProject(_ room: Room, target: Project?) {
        // Save immediately with score = 0, then update score once AI analysis completes
        if var project = target ?? projectStore.projects.first {
            project.rooms.append(room)
            projectStore.update(project)
            NotificationService.shared.schedulePostScanNudge(projectName: project.name)
            Task { await analyzeAndUpdateScore(room, in: project) }
        } else {
            var newProject = projectStore.create(name: "My Home")
            newProject.rooms.append(room)
            projectStore.update(newProject)
            NotificationService.shared.schedulePostScanNudge(projectName: newProject.name)
            Task { await analyzeAndUpdateScore(room, in: newProject) }
        }
        Task { await GenerateDesignsTip.roomScanned.donate() }
        AnalyticsService.shared.track(.scanCompleted, properties: [
            "room_type": room.type.rawValue,
            "area": room.area,
            "score": room.score
        ])
        Task { @MainActor in
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            AppState.shared.recordScanCompleted(in: scene)
        }
        LumaHaptics.notification(.success)
    }

    private func analyzeAndUpdateScore(_ room: Room, in project: Project) async {
        let analysis = await aiService.analyzeRoom(room)
        // Find the matching room in the (possibly updated) project and write back the score
        guard var updatedProject = projectStore.projects.first(where: { $0.id == project.id }),
              let roomIdx = updatedProject.rooms.firstIndex(where: { $0.id == room.id })
        else { return }
        updatedProject.rooms[roomIdx].recordScore(analysis.roomScore)
        updatedProject.rooms[roomIdx].issues = analysis.issues
        projectStore.update(updatedProject)
    }
}

// MARK: - Room Type Button

struct RoomTypeButton: View {
    let type: Room.RoomType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: LumaSpacing.xs) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Color.Luma.accent)
                Text(type.rawValue)
                    .font(LumaFont.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LumaSpacing.md)
            .background(isSelected ? Color.Luma.accent : Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                        .strokeBorder(Color.Luma.accent.opacity(0.4), lineWidth: 1)
                }
            }
            .animation(.lumaFast, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Recent Scan Row

struct RecentScanRow: View {
    let room: Room

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: room.type.icon)
                .font(.title3)
                .foregroundStyle(Color.Luma.accent)
                .frame(width: 44, height: 44)
                .background(Color.Luma.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name).font(LumaFont.subhead).fontWeight(.semibold)
                Text("\(room.dimensions.areaFormatted) · \(room.scanDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
            }

            Spacer()

            RoomScoreView(score: room.score, size: 40)
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
    }
}

// MARK: - Scanner Overlay

struct ScannerOverlay: View {
    @ObservedObject var manager: RoomScanManager
    let onComplete: (Room) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showStopConfirm = false

    var body: some View {
        ZStack {
            // Live AR Camera View
            RoomCaptureViewRepresentable(manager: manager)
                .ignoresSafeArea()

            // HUD overlay
            VStack {
                topBar
                Spacer()
                scanStats
                Spacer(minLength: 0)
                instructionBanner
                bottomControls
            }
        }
        .onChange(of: manager.state) { _, state in
            if case .completed(let room) = state {
                dismiss()
                onComplete(room)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showStopConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("Cancel scan")

            Spacer()

            if case .scanning(let p) = manager.state {
                LumaProgressRing(progress: p, lineWidth: 5, color: .white, size: 36)
            }
        }
        .padding(.horizontal, LumaSpacing.lg)
        .padding(.top, LumaSpacing.lg)
        .confirmationDialog("Stop Scanning?", isPresented: $showStopConfirm) {
            Button("Finish Scan") {
                if let session = manager.activeSession { manager.stopScan(session: session) }
            }
            Button("Cancel Scan", role: .destructive) {
                if let session = manager.activeSession { manager.cancelScan(session: session) }
                dismiss()
            }
            Button("Continue", role: .cancel) {}
        }
    }

    private var scanStats: some View {
        HStack(spacing: LumaSpacing.lg) {
            ScanStatPill(icon: "square.dashed", value: "\(manager.scannedWalls)", label: "Walls")
            ScanStatPill(icon: "door.left.hand.open", value: "\(manager.scannedDoors)", label: "Doors")
            ScanStatPill(icon: "window.horizontal", value: "\(manager.scannedWindows)", label: "Windows")
        }
        .padding(.horizontal)
    }

    private var instructionBanner: some View {
        Text(manager.instruction.rawValue)
            .font(LumaFont.subhead.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, LumaSpacing.xl)
            .padding(.vertical, LumaSpacing.md)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal)
            .animation(.lumaFast, value: manager.instruction)
    }

    private var bottomControls: some View {
        HStack {
            Spacer()
            Button {
                LumaHaptics.impact(.heavy)
                if let session = manager.activeSession { manager.stopScan(session: session) }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.Luma.accent)
                }
            }
            .accessibilityLabel("Finish scanning")
            Spacer()
        }
        .padding(.bottom, LumaSpacing.xxxl + LumaSpacing.lg)
    }
}

// MARK: - Scan Stat Pill

struct ScanStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: LumaSpacing.xs) {
            Image(systemName: icon).font(.caption)
            Text(value)
                .font(LumaFont.subhead)
                .fontWeight(.bold)
                .contentTransition(.numericText())
                .animation(.lumaFast, value: value)
            Text(label).font(LumaFont.caption1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, LumaSpacing.md)
        .padding(.vertical, LumaSpacing.xs + 2)
        .background(.thinMaterial, in: Capsule())
    }
}

// MARK: - Scan Complete Sheet

struct ScanCompleteSheet: View {
    let room: Room
    /// onSave(room, targetProject, scanAnother)
    let onSave: (Room, Project?, Bool) -> Void
    @EnvironmentObject private var projectStore: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var roomName: String
    @State private var roomType: Room.RoomType
    @State private var selectedProjectID: UUID?
    @State private var beforePhoto: UIImage?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var showPhotoSourceMenu = false

    let preselectedProjectID: UUID?

    init(room: Room, preselectedProjectID: UUID? = nil, onSave: @escaping (Room, Project?, Bool) -> Void) {
        self.room = room
        self.preselectedProjectID = preselectedProjectID
        self.onSave = onSave
        self._roomName = State(initialValue: room.name)
        self._roomType = State(initialValue: room.type)
    }

    private var selectedProject: Project? {
        projectStore.projects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: LumaSpacing.xxl) {
                // Dimensions card
                HStack(spacing: LumaSpacing.xxl) {
                    RoomScoreView(score: room.score, size: 80)
                    VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                        DimRow(label: "Width",   value: room.dimensions.widthFormatted)
                        DimRow(label: "Length",  value: room.dimensions.lengthFormatted)
                        DimRow(label: "Area",    value: room.dimensions.areaFormatted)
                        DimRow(label: "Ceiling", value: String(format: "%.1f m", room.dimensions.ceilingHeight))
                    }
                }
                .padding()
                .lumaCard()
                .padding(.horizontal)

                Form {
                    Section {
                        beforePhotoRow
                    } header: {
                        Text("Before Photo")
                    } footer: {
                        Text("Take a photo of the room as-is. It powers the Before/After comparison in your AI designs.")
                    }

                    Section("Room Details") {
                        TextField("Room Name", text: $roomName)
                        Picker("Room Type", selection: $roomType) {
                            ForEach(Room.RoomType.allCases, id: \.self) { t in
                                Label(t.rawValue, systemImage: t.icon).tag(t)
                            }
                        }
                    }

                    Section("Add to Project") {
                        if projectStore.projects.isEmpty {
                            Text("A new project will be created automatically.")
                                .font(LumaFont.caption1)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Project", selection: $selectedProjectID) {
                                Text("Create new project")
                                    .tag(Optional<UUID>.none)
                                ForEach(projectStore.projects) { project in
                                    Label(project.name, systemImage: "folder")
                                        .tag(Optional(project.id))
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                }
            }
            .padding(.top)
            .navigationTitle("Scan Complete!")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedProjectID = preselectedProjectID ?? projectStore.projects.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            saveRoom(scanAnother: false)
                        } label: {
                            Label("Save Room", systemImage: "checkmark.circle")
                        }
                        Button {
                            saveRoom(scanAnother: true)
                        } label: {
                            Label("Save & Scan Another Room", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraImagePicker(source: .camera, image: $beforePhoto)
        }
        .sheet(isPresented: $showLibraryPicker) {
            CameraImagePicker(source: .library, image: $beforePhoto)
        }
        .presentationDetents([.large])
    }

    private func saveRoom(scanAnother: Bool) {
        var saved = room
        saved.name = roomName.trimmingCharacters(in: .whitespaces).isEmpty
            ? room.name : roomName
        saved.type = roomType
        saved.beforePhotoData = beforePhoto.flatMap { $0.jpegData(compressionQuality: 0.80) }
        onSave(saved, selectedProject, scanAnother)
        dismiss()
    }

    private var beforePhotoRow: some View {
        HStack(spacing: LumaSpacing.md) {
            // Thumbnail or placeholder
            ZStack {
                if let photo = beforePhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(uiColor: .systemGray5)
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                Text(beforePhoto == nil ? "Add Before Photo" : "Before Photo Added")
                    .font(LumaFont.subhead)
                    .fontWeight(.semibold)
                Text(beforePhoto == nil
                     ? "Optional — enables Before/After comparison"
                     : "Tap to retake")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if beforePhoto != nil {
                Button {
                    beforePhoto = nil
                    LumaHaptics.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showPhotoSourceMenu = true }
        .confirmationDialog("Add Before Photo", isPresented: $showPhotoSourceMenu) {
            Button("Take Photo")    { showCameraPicker  = true }
            Button("Choose from Library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct DimRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(LumaFont.caption1).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(LumaFont.caption1).fontWeight(.semibold)
        }
    }
}
