import SwiftUI
import Charts

struct ProjectDetailView: View {
    @State var project: Project
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var aiService: AIDesignService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreService
    @State private var showAddRoom = false
    @State private var selectedRoom: Room?
    @State private var showAnalysis = false
    @State private var analysis: RoomAnalysis?
    @State private var isAnalyzing = false
    @State private var showBudget = false
    @State private var showRenameAlert = false
    @State private var renameDraft = ""
    @State private var showDeleteConfirm = false
    @State private var selectedConcept: DesignConcept?
    @State private var showActivity = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: LumaSpacing.lg) {
                statsBar
                quickActions
                roomsSection
                designsSection
                if project.budget != nil || !project.moodboardItems.isEmpty {
                    bottomRow
                }
            }
            .padding(.horizontal, LumaSpacing.base)
            .padding(.top, LumaSpacing.md)
            .padding(.bottom, LumaSpacing.xxxl)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project name", text: $renameDraft)
            Button("Rename") {
                guard !renameDraft.isEmpty else { return }
                project.name = renameDraft
                projectStore.update(project)
                LumaHaptics.notification(.success)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \"\(project.name)\"?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Project", role: .destructive) {
                projectStore.delete(project)
                AnalyticsService.shared.track(.projectDeleted)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $selectedRoom) { room in
            RoomDetailSheet(room: room, project: $project)
                .environmentObject(projectStore)
                .environmentObject(aiService)
                .environmentObject(appState)
                .environmentObject(store)
        }
        .sheet(item: $selectedConcept) { concept in
            DesignDetailView(concept: concept)
                .environmentObject(store)
                .environmentObject(appState)
                .environmentObject(aiService)
        }
        .sheet(isPresented: $showBudget) {
            BudgetPlannerSheet(project: $project) { updated in
                projectStore.update(updated)
            }
            .environmentObject(aiService)
        }
        .sheet(isPresented: $showActivity) {
            ActivitySheet(events: activityEvents)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: LumaSpacing.sm) {
                Button {
                    projectStore.toggleFavorite(project)
                    if let updated = projectStore.projects.first(where: { $0.id == project.id }) {
                        project = updated
                    }
                    LumaHaptics.impact(.light)
                } label: {
                    Image(systemName: project.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(project.isFavorite ? .red : .secondary)
                }
                .accessibilityLabel(project.isFavorite ? "Remove from favorites" : "Favourite")

                Menu {
                    Button("Rename", systemImage: "pencil") {
                        renameDraft = project.name
                        showRenameAlert = true
                    }
                    Button("Export PDF", systemImage: "doc.fill") { exportPDF() }
                    Button("Share", systemImage: "square.and.arrow.up") { shareProject() }
                    Button("Activity Log", systemImage: "clock") { showActivity = true }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statPill(value: "\(project.roomCount)", label: "Rooms", icon: "square.3.layers.3d")
            Divider().frame(height: 32)
            if project.totalArea > 0 {
                statPill(value: String(format: "%.0f m²", project.totalArea), label: "Area", icon: "ruler")
                Divider().frame(height: 32)
            }
            statPill(value: "\(project.designs.count)", label: "Designs", icon: "paintbrush.fill")
            Divider().frame(height: 32)
            statPill(
                value: project.updatedAt.formatted(date: .abbreviated, time: .omitted),
                label: "Updated",
                icon: "clock"
            )
        }
        .padding(.vertical, LumaSpacing.sm)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(LumaFont.subhead)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(LumaFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LumaSpacing.xs)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: LumaSpacing.sm) {
            actionButton(icon: "camera.viewfinder", label: "Scan Room",
                         color: Color.Luma.accent) {
                appState.activeProject = project
                appState.activeTab = .scan
            }
            actionButton(icon: "wand.and.stars", label: "AI Design",
                         color: Color.Luma.purple) {
                appState.activeProject = project
                appState.activeTab = .designs
            }
            actionButton(icon: "chair", label: "Furnish",
                         color: Color.Luma.navy) {
                appState.activeProject = project
                appState.activeTab = .ar
            }
            actionButton(icon: "dollarsign.circle.fill", label: "Budget",
                         color: Color.Luma.gold) {
                showBudget = true
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { LumaHaptics.impact(.light); action() }) {
            VStack(spacing: LumaSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack {
                Text("Rooms")
                    .font(LumaFont.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    appState.activeProject = project
                    appState.activeTab = .scan
                    LumaHaptics.impact(.light)
                } label: {
                    Label("Scan New", systemImage: "camera.viewfinder")
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Luma.accent)
                }
            }

            if project.rooms.isEmpty {
                emptyRoomsCard
            } else {
                ForEach(project.rooms) { room in
                    RoomRow(room: room, isAnalyzing: isAnalyzing) {
                        selectedRoom = room
                    }
                }
            }
        }
    }

    private var emptyRoomsCard: some View {
        Button { appState.activeTab = .scan } label: {
            HStack(spacing: LumaSpacing.md) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .foregroundStyle(Color.Luma.accent)
                    .frame(width: 52, height: 52)
                    .background(Color.Luma.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan your first room")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                    Text("Go to Scan tab → walk the room slowly")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Designs

    private var designsSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack {
                Text("AI Designs")
                    .font(LumaFont.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    appState.activeTab = .designs
                    LumaHaptics.impact(.light)
                } label: {
                    Label("Generate", systemImage: "wand.and.stars")
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Luma.purple)
                }
            }

            if project.designs.isEmpty {
                emptyDesignsCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LumaSpacing.md) {
                        ForEach(project.designs.prefix(6)) { concept in
                            ConceptCard(concept: concept) { selectedConcept = concept }
                                .frame(width: 152)
                        }
                        // "Generate more" tile
                        Button { appState.activeTab = .designs } label: {
                            VStack(spacing: LumaSpacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.Luma.purple.opacity(0.5))
                                Text("Generate more")
                                    .font(LumaFont.caption1)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 100, height: 120)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyDesignsCard: some View {
        Button { appState.activeTab = .designs } label: {
            HStack(spacing: LumaSpacing.md) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(Color.Luma.purple)
                    .frame(width: 52, height: 52)
                    .background(Color.Luma.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generate AI designs")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                    Text("Pick a style and let GPT-4o design your room")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Row (Budget + Moodboard, only if data exists)

    private var bottomRow: some View {
        HStack(alignment: .top, spacing: LumaSpacing.md) {
            if let budget = project.budget {
                compactBudgetCard(budget)
            }
            if !project.moodboardItems.isEmpty {
                compactMoodboardCard
            }
        }
    }

    private func compactBudgetCard(_ budget: BudgetPlan) -> some View {
        Button { showBudget = true } label: {
            VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                Label("Budget", systemImage: "dollarsign.circle.fill")
                    .font(LumaFont.caption1)
                    .foregroundStyle(Color.Luma.gold)
                Text("$\(Int(budget.total).formatted())")
                    .font(LumaFont.title3)
                    .fontWeight(.bold)
                ProgressView(value: budget.percentUsed)
                    .tint(budget.remaining > 0 ? Color.Luma.accent : .red)
                Text("$\(Int(budget.remaining).formatted()) left")
                    .font(LumaFont.caption2)
                    .foregroundStyle(budget.remaining > 0 ? Color(uiColor: .secondaryLabel) : Color.red)
            }
            .padding(LumaSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var compactMoodboardCard: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
            Label("Moodboard", systemImage: "photo.stack")
                .font(LumaFont.caption1)
                .foregroundStyle(Color.Luma.accent)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 4
            ) {
                ForEach(project.moodboardItems.prefix(4)) { item in
                    MoodboardCell(item: item) {}
                        .frame(height: 44)
                }
            }
        }
        .padding(LumaSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }

    // MARK: - Activity Log

    private var activityEvents: [ProjectActivityEvent] {
        var events: [ProjectActivityEvent] = []
        events.append(ProjectActivityEvent(
            icon: "folder.badge.plus", color: Color.Luma.accent,
            title: "Project created", date: project.createdAt
        ))
        for room in project.rooms.sorted(by: { $0.scanDate < $1.scanDate }) {
            events.append(ProjectActivityEvent(
                icon: room.type.icon, color: Color.Luma.purple,
                title: "\(room.name) scanned", date: room.scanDate
            ))
        }
        for design in project.designs.sorted(by: { $0.createdAt < $1.createdAt }) {
            events.append(ProjectActivityEvent(
                icon: "wand.and.stars", color: Color.Luma.goldFallback,
                title: "\(design.style.rawValue) design generated", date: design.createdAt
            ))
        }
        return events.sorted { $0.date > $1.date }
    }

    // MARK: - Actions

    private func exportPDF() {
        Task {
            await PDFExportService.shared.shareAsync(project)
            AnalyticsService.shared.track(.designExported, properties: ["format": "pdf"])
        }
    }

    private func shareProject() {
        let text = "Check out my \"\(project.name)\" interior design project — created with LumaSpace 🏠"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(vc, animated: true)
        AnalyticsService.shared.track(.projectShared)
    }
}

// MARK: - Room Row (compact with floor plan thumbnail)

struct RoomRow: View {
    let room: Room
    let isAnalyzing: Bool
    let onTap: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LumaSpacing.md) {
                // Floor plan thumbnail
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: room.type.icon)
                            .font(.title3)
                            .foregroundStyle(Color.Luma.accent)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Color.Luma.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name)
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                    HStack(spacing: LumaSpacing.xs) {
                        Text(room.type.rawValue)
                        Text("·")
                        Text(room.dimensions.areaFormatted)
                    }
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
                    if !room.furnitureItems.isEmpty {
                        Text("\(room.furnitureItems.count) furniture items")
                            .font(LumaFont.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isAnalyzing {
                    ProgressView().scaleEffect(0.75)
                } else {
                    RoomScoreView(score: room.score, size: 40)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .task {
            thumbnail = await Task.detached(priority: .utility) {
                FloorPlanService.shared.generateFloorPlan(for: room)
            }.value
        }
    }
}

// MARK: - Room Detail Sheet (full room view on tap)

struct RoomDetailSheet: View {
    let room: Room
    @Binding var project: Project
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var aiService: AIDesignService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss
    @State private var showAnalysis = false
    @State private var analysis: RoomAnalysis?
    @State private var isAnalyzing = false
    @State private var floorPlanImage: UIImage?
    @State private var showUSDZPreview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.lg) {
                    // Floor plan
                    Group {
                        if let img = floorPlanImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                        } else {
                            SkeletonView()
                                .frame(height: 220)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                    .padding(.horizontal)

                    // Stats row
                    HStack(spacing: 0) {
                        roomStat(room.dimensions.areaFormatted, "Area")
                        Divider().frame(height: 28)
                        roomStat(String(format: "%.1fm × %.1fm", room.dimensions.width, room.dimensions.length), "Size")
                        Divider().frame(height: 28)
                        roomStat("\(room.furnitureItems.count)", "Furniture")
                    }
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: LumaSpacing.sm) {
                        LumaPrimaryButton("Analyse Room", icon: "brain", isLoading: isAnalyzing) {
                            Task { await analyzeRoom() }
                        }
                        .padding(.horizontal)

                        HStack(spacing: LumaSpacing.sm) {
                            LumaSecondaryButton("Design", icon: "wand.and.stars") {
                                appState.activeTab = .designs; dismiss()
                            }
                            LumaSecondaryButton("Furnish in AR", icon: "chair") {
                                NotificationCenter.default.post(name: .launchAR, object: nil)
                                dismiss()
                            }
                        }
                        .padding(.horizontal)
                    }

                    // USDZ link
                    if let url = room.scanDataURL,
                       FileManager.default.fileExists(atPath: url.path) {
                        Button {
                            showUSDZPreview = true
                            LumaHaptics.impact(.light)
                        } label: {
                            HStack(spacing: LumaSpacing.sm) {
                                Image(systemName: "cube.transparent")
                                    .foregroundStyle(Color.Luma.accent)
                                Text("View 3D Model in AR Quick Look")
                                    .font(LumaFont.subhead)
                                    .foregroundStyle(Color.Luma.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(LumaSpacing.md)
                            .lumaCard(padding: LumaSpacing.md)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .sheet(isPresented: $showUSDZPreview) {
                            USDZQuickLookView(url: url)
                        }
                    }

                    // Score history chart
                    if room.scoreHistory.count >= 2 {
                        RoomScoreChartView(history: room.scoreHistory, currentScore: room.score)
                            .padding(.horizontal)
                    }

                    // Design history
                    if !project.designs.isEmpty {
                        NavigationLink {
                            DesignHistoryView(room: room)
                                .environmentObject(projectStore)
                        } label: {
                            HStack {
                                Label("Design History (\(project.designs.count))", systemImage: "clock.arrow.circlepath")
                                    .font(LumaFont.subhead)
                                    .foregroundStyle(Color.Luma.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(LumaSpacing.md)
                            .lumaCard(padding: LumaSpacing.md)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, LumaSpacing.lg)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(room.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAnalysis) {
                if let a = analysis {
                    RoomAnalysisSheet(room: room, analysis: a)
                }
            }
        }
        .task {
            floorPlanImage = await Task.detached(priority: .userInitiated) {
                FloorPlanService.shared.generateFloorPlan(for: room)
            }.value
        }
    }

    private func roomStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(LumaFont.subhead).fontWeight(.semibold)
            Text(label).font(LumaFont.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func analyzeRoom() async {
        isAnalyzing = true
        analysis = await aiService.analyzeRoom(room)
        isAnalyzing = false
        showAnalysis = true
    }
}

// MARK: - Activity Sheet

struct ActivitySheet: View {
    let events: [ProjectActivityEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(events) { event in
                HStack(spacing: LumaSpacing.md) {
                    Image(systemName: event.icon)
                        .font(.caption)
                        .foregroundStyle(event.color)
                        .frame(width: 28, height: 28)
                        .background(event.color.opacity(0.10))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).font(LumaFont.caption1).fontWeight(.medium)
                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                            .font(LumaFont.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Shared sub-views (kept from original)

struct ProjectActivityEvent: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let date: Date
}

// MARK: - USDZ Quick Look

import QuickLook

struct USDZQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem { url as QLPreviewItem }
    }
}

// MARK: - Room Analysis Sheet

struct RoomAnalysisSheet: View {
    let room: Room
    let analysis: RoomAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    HStack(spacing: LumaSpacing.xxl) {
                        ScoreCard(label: "Overall",  score: analysis.roomScore)
                        ScoreCard(label: "Lighting", score: analysis.lightingScore)
                        ScoreCard(label: "Flow",     score: analysis.flowScore)
                        ScoreCard(label: "Space",    score: analysis.utilizationScore)
                    }
                    .padding()

                    if !analysis.issues.isEmpty {
                        VStack(alignment: .leading, spacing: LumaSpacing.md) {
                            LumaSectionHeader(title: "Issues Found")
                            ForEach(analysis.issues) { issue in IssueRow(issue: issue) }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: LumaSpacing.md) {
                        LumaSectionHeader(title: "Opportunities")
                        ForEach(Array(analysis.opportunities.enumerated()), id: \.offset) { _, opp in
                            HStack(alignment: .top, spacing: LumaSpacing.md) {
                                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow).font(.subheadline)
                                Text(opp).font(LumaFont.subhead)
                            }
                            .padding(LumaSpacing.md)
                            .lumaCard(padding: LumaSpacing.md)
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: LumaSpacing.md) {
                        LumaSectionHeader(title: "Recommended Styles")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: LumaSpacing.sm) {
                                ForEach(analysis.suggestedStyles) { style in
                                    LumaChip(text: "\(style.emoji) \(style.rawValue)")
                                }
                            }
                            .padding(.vertical, LumaSpacing.xs)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .navigationTitle(room.name + " Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

struct ScoreCard: View {
    let label: String
    let score: Int

    var body: some View {
        VStack(spacing: LumaSpacing.xs) {
            RoomScoreView(score: score, size: 56)
            Text(label).font(LumaFont.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Budget Summary Card

struct BudgetSummaryCard: View {
    let budget: BudgetPlan

    var body: some View {
        VStack(spacing: LumaSpacing.md) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Budget").font(LumaFont.caption1).foregroundStyle(.secondary)
                    Text("$\(Int(budget.total).formatted())").font(LumaFont.title2).fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Remaining").font(LumaFont.caption1).foregroundStyle(.secondary)
                    Text("$\(Int(budget.remaining).formatted())")
                        .font(LumaFont.title3).fontWeight(.semibold)
                        .foregroundStyle(budget.remaining > 0 ? .green : .red)
                }
            }
            ProgressView(value: budget.percentUsed)
                .tint(budget.remaining > 0 ? Color.Luma.accent : .red)
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
    }
}

// MARK: - Budget Planner Sheet

struct BudgetPlannerSheet: View {
    @Binding var project: Project
    let onSave: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var aiService: AIDesignService
    @State private var budgetAmount = 5000.0
    @State private var plan: BudgetPlan?
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Total Budget") {
                    HStack {
                        Text("$")
                        TextField("Amount", value: $budgetAmount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    HStack(spacing: LumaSpacing.md) {
                        ForEach([1000.0, 5000.0, 10000.0, 20000.0], id: \.self) { preset in
                            Button("$\(Int(preset/1000))K") {
                                budgetAmount = preset; LumaHaptics.selection()
                            }
                            .font(LumaFont.caption1).fontWeight(.medium)
                            .padding(.horizontal, LumaSpacing.sm).padding(.vertical, LumaSpacing.xs)
                            .background(budgetAmount == preset
                                        ? Color.Luma.accent.opacity(0.1)
                                        : Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                            .foregroundStyle(budgetAmount == preset ? Color.Luma.accent : .secondary)
                        }
                    }
                }

                if isGenerating {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: LumaSpacing.sm) {
                                ProgressView().tint(Color.Luma.accent)
                                Text("AI is generating your budget plan…")
                                    .font(LumaFont.caption1).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, LumaSpacing.md)
                            Spacer()
                        }
                    }
                }

                if let plan {
                    Section("Budget Breakdown") {
                        ForEach(plan.items) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name).font(LumaFont.subhead)
                                    Text(item.priority.rawValue.capitalized)
                                        .font(LumaFont.caption2).foregroundStyle(item.priority.color)
                                }
                                Spacer()
                                Text("$\(Int(item.estimatedCost).formatted())")
                                    .font(LumaFont.subhead).fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Budget Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(plan == nil ? "Generate" : "Save") {
                        if plan == nil {
                            Task {
                                isGenerating = true
                                let room = project.rooms.first
                                let style = project.designs.first?.style ?? .japandi
                                if let room {
                                    plan = await aiService.generateAIBudgetPlan(for: room, style: style, budget: budgetAmount)
                                } else {
                                    plan = aiService.generateBudgetPlan(
                                        for: Room(name: "Room", type: .livingRoom,
                                                  dimensions: RoomDimensions(width: 4, length: 5, ceilingHeight: 2.4),
                                                  scanDate: .now, score: 0, issues: [], furnitureItems: []),
                                        style: style, budget: budgetAmount)
                                }
                                isGenerating = false
                            }
                        } else {
                            project.budget = plan
                            onSave(project)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isGenerating)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Floor Plan Card (kept for backward compat)

struct FloorPlanCard: View {
    let room: Room
    @State private var floorPlanImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.xs) {
            Group {
                if let img = floorPlanImage {
                    Image(uiImage: img).resizable().scaledToFit()
                } else {
                    SkeletonView()
                }
            }
            .frame(width: 200, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name).font(LumaFont.caption1).fontWeight(.semibold).lineLimit(1)
                Text(room.dimensions.areaFormatted).font(LumaFont.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, LumaSpacing.xs)
        }
        .frame(width: 200)
        .padding(LumaSpacing.sm)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        .task {
            floorPlanImage = await Task.detached(priority: .userInitiated) {
                FloorPlanService.shared.generateFloorPlan(for: room)
            }.value
        }
    }
}

// MARK: - Room Score History Chart

struct RoomScoreChartView: View {
    let history: [RoomScoreEntry]
    let currentScore: Int

    private var trend: String {
        guard history.count >= 2 else { return "" }
        let delta = history.last!.score - history.first!.score
        if delta > 5  { return "↑ Improving" }
        if delta < -5 { return "↓ Declining" }
        return "→ Steady"
    }

    private var trendColor: Color {
        guard history.count >= 2 else { return .secondary }
        let delta = history.last!.score - history.first!.score
        if delta > 5  { return .green }
        if delta < -5 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack {
                LumaSectionHeader(title: "Score History")
                Spacer()
                if !trend.isEmpty {
                    Text(trend)
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(trendColor)
                }
            }

            Chart {
                ForEach(history) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(Color.Luma.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", entry.date),
                        yStart: .value("Base", 0),
                        yEnd: .value("Score", entry.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.Luma.accent.opacity(0.25), Color.Luma.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(Color.Luma.accent)
                    .symbolSize(36)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(LumaFont.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine().foregroundStyle(Color(uiColor: .separator).opacity(0.5))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .font(LumaFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .padding(.bottom, LumaSpacing.xs)
        }
        .padding(LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }
}
