import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var showCreateProject = false
    @State private var selectedStyle: DesignStyle?
    @State private var renameProject: Project?
    @State private var renameDraft = ""
    @State private var showRenameAlert = false
    @State private var showCatalog = false
    @State private var showExplore = false
    @State private var projectToDelete: Project?

    var body: some View {
        NavigationStack {
            Group {
                if projectStore.projects.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Your Spaces")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search projects"
            )
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(for: Project.self) { ProjectDetailView(project: $0) }
        }
        .sheet(isPresented: $showCreateProject) { CreateProjectSheet() }
        .sheet(item: $selectedStyle) { StyleInspirationSheet(style: $0) }
        .sheet(isPresented: $showCatalog) {
            FurnitureCatalogView()
                .environmentObject(appState)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchCatalogSearch)) { note in
            if let query = note.object as? String {
                FurnitureCatalogService.shared.searchText = query
            }
            showCatalog = true
        }
        .sheet(isPresented: $showExplore) {
            ExploreView()
                .environmentObject(appState)
                .environmentObject(store)
        }
        .confirmationDialog(
            "Delete \"\(projectToDelete?.name ?? "Project")\"?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    withAnimation(reduceMotion ? .none : .lumaSpring) { projectStore.delete(project) }
                    LumaHaptics.notification(.success)
                }
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project name", text: $renameDraft)
                .autocorrectionDisabled()
            Button("Rename") {
                guard var project = renameProject,
                      !renameDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                project.name = renameDraft.trimmingCharacters(in: .whitespaces)
                projectStore.update(project)
                LumaHaptics.notification(.success)
                renameProject = nil
            }
            Button("Cancel", role: .cancel) { renameProject = nil }
        }
        .onChange(of: searchText) { _, q in
            if !q.isEmpty { AnalyticsService.shared.track(.searchPerformed) }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                LumaHaptics.impact(.medium)
                showCreateProject = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("New project")
        }
    }

    // MARK: - Empty State (iOS 17 ContentUnavailableView)

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                ContentUnavailableView {
                    Label("No Spaces Yet", systemImage: "house")
                } description: {
                    Text("Create a project, scan a room, and let AI design your perfect space.")
                } actions: {
                    Button {
                        showCreateProject = true
                        LumaHaptics.impact(.medium)
                    } label: {
                        Label("Create Project", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Luma.accent)
                }
                .padding(.top, LumaSpacing.xxxl)

                howItWorksSection
                    .padding(.top, LumaSpacing.xxl)

                inspirationSection
                    .padding(.top, LumaSpacing.md)
                    .padding(.bottom, LumaSpacing.xxxl)
            }
        }
    }

    // MARK: - Project List

    private var projectList: some View {
        List {
            // Quick actions — first thing users see so they always know what to do
            Section {
                quickActionsRow
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Quick Actions")
            }

            // Stats row
            Section {
                statsRow
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Upgrade banner (free tier only)
            if store.currentTier == .free {
                Section {
                    FreeUpgradeBanner()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: LumaSpacing.base, bottom: 0, trailing: LumaSpacing.base))
            }

            // Referral nudge after 2nd scan
            if UsageTracker.shared.totalScansCompleted >= 2 && !appState.hasSeenReferralBanner {
                Section {
                    ReferralNudgeBanner {
                        withAnimation(reduceMotion ? .none : .lumaSpring) { appState.hasSeenReferralBanner = true }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: LumaSpacing.base, bottom: 0, trailing: LumaSpacing.base))
            }

            // Projects
            Section {
                if searchText.isEmpty {
                    ForEach(sortedProjects) { project in
                        NavigationLink(value: project) {
                            ProjectListRow(project: project)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectToDelete = project
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                projectStore.toggleFavorite(project)
                                LumaHaptics.impact(.light)
                            } label: {
                                Label(
                                    project.isFavorite ? "Unfavourite" : "Favourite",
                                    systemImage: project.isFavorite ? "heart.slash" : "heart.fill"
                                )
                            }
                            .tint(Color.Luma.accent)
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                renameProject = project
                                renameDraft = project.name
                                showRenameAlert = true
                            }
                            Button(
                                project.isFavorite ? "Unfavourite" : "Favourite",
                                systemImage: project.isFavorite ? "heart.slash" : "heart"
                            ) { projectStore.toggleFavorite(project) }
                            Divider()
                            Button("Export PDF", systemImage: "doc") {
                                Task { await PDFExportService.shared.shareAsync(project) }
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                projectToDelete = project
                            }
                        }
                    }
                    .onDelete { offsets in projectStore.delete(at: offsets) }
                } else {
                    let results = projectStore.projects(matching: searchText)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(results) { project in
                            NavigationLink(value: project) { ProjectListRow(project: project) }
                        }
                    }
                }
            } header: {
                HStack {
                    Text(searchText.isEmpty
                         ? "Projects (\(projectStore.projects.count))"
                         : "Results")
                    Spacer()
                    if searchText.isEmpty {
                        Button("New") { showCreateProject = true }
                            .font(.caption)
                            .foregroundStyle(Color.Luma.accent)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }

            // Design Styles — only shown to users who haven't generated designs yet
            // Once they've used AI Design, they know the styles well enough
            let totalDesigns = projectStore.projects.flatMap(\.designs).count
            if searchText.isEmpty && totalDesigns == 0 {
                Section {
                    inspirationScroll
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Design Styles — tap to explore")
                }
            }

            // Explore entry point
            if searchText.isEmpty {
                Section {
                    exploreEntryRow
                        .listRowInsets(EdgeInsets(top: 0, leading: LumaSpacing.base, bottom: 0, trailing: LumaSpacing.base))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Discover")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            // Sync/refresh projects — store refresh is local so this is a no-op
            LumaHaptics.impact(.light)
        }
        .animation(reduceMotion ? .none : .lumaSpring, value: projectStore.projects.map(\.id))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatTile(
                value: projectStore.projects.count,
                label: "Projects",
                icon: "folder.fill",
                color: Color.Luma.accent
            )
            Divider().frame(height: 32)
            StatTile(
                value: projectStore.projects.flatMap(\.rooms).count,
                label: "Rooms",
                icon: "square.3.layers.3d",
                color: Color.Luma.purple
            )
            Divider().frame(height: 32)
            StatTile(
                value: projectStore.projects.flatMap(\.designs).count,
                label: "Designs",
                icon: "paintbrush.fill",
                color: Color.Luma.gold
            )
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
        .padding(.horizontal, LumaSpacing.base)
        .padding(.top, LumaSpacing.xs)
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        HStack(spacing: LumaSpacing.sm) {
            QuickActionButton(
                icon: "camera.viewfinder",
                label: "Scan",
                color: Color.Luma.accent
            ) { appState.activeTab = .scan }

            QuickActionButton(
                icon: "wand.and.stars",
                label: "AI Design",
                color: Color.Luma.purple
            ) { appState.activeTab = .designs }

            QuickActionButton(
                icon: "chair",
                label: "Furnish",
                color: Color.Luma.navy
            ) { appState.activeTab = .ar }

            QuickActionButton(
                icon: "storefront.fill",
                label: "Shop",
                color: Color.Luma.gold
            ) {
                showCatalog = true
                LumaHaptics.impact(.medium)
            }
        }
        .padding(.horizontal, LumaSpacing.base)
        .padding(.vertical, LumaSpacing.xs)
    }

    // MARK: - Inspiration Scroll

    private var inspirationScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumaSpacing.md) {
                ForEach(DesignStyle.allCases) { style in
                    DesignStyleCard(style: style) { selectedStyle = style }
                }
            }
            .padding(.horizontal, LumaSpacing.base)
            .padding(.vertical, LumaSpacing.sm)
        }
    }

    // MARK: - How it Works (empty state)

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            Text("How It Works")
                .font(LumaFont.headline)
                .padding(.horizontal, LumaSpacing.base)
            VStack(spacing: LumaSpacing.sm) {
                ForEach(HowItWorksStep.all) { HowItWorksRow(step: $0) }
            }
            .padding(.horizontal, LumaSpacing.base)
        }
    }

    // MARK: - Inspiration (empty state)

    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
            Text("Design Styles")
                .font(LumaFont.headline)
                .padding(.horizontal, LumaSpacing.base)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.md) {
                    ForEach(DesignStyle.allCases) { style in
                        DesignStyleCard(style: style) { selectedStyle = style }
                    }
                }
                .padding(.horizontal, LumaSpacing.base)
            }
        }
    }

    // MARK: - Explore Entry Row

    private var exploreEntryRow: some View {
        HStack(spacing: LumaSpacing.md) {
            Button {
                showExplore = true
                LumaHaptics.impact(.light)
            } label: {
                HStack(spacing: LumaSpacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Luma.goldFallback)
                        .frame(width: 44, height: 44)
                        .background(Color.Luma.goldFallback.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explore Styles & Trends")
                            .font(LumaFont.subhead).fontWeight(.semibold)
                        Text("Style quiz · trending products · seasonal picks")
                            .font(LumaFont.caption1).foregroundStyle(.secondary)
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
    }

    // MARK: - Helpers

    private var sortedProjects: [Project] {
        projectStore.projects.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.updatedAt > $1.updatedAt
        }
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: LumaSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(LumaFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LumaSpacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(LumaFont.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

// MARK: - Project List Row

struct ProjectListRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            // Thumbnail / gradient avatar
            ZStack {
                RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                    .fill(projectGradient)
                    .frame(width: 52, height: 52)
                if let img = project.thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                } else {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: LumaSpacing.xs) {
                    Text(project.name)
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if project.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                HStack(spacing: LumaSpacing.xs) {
                    if project.roomCount > 0 {
                        Label(
                            "\(project.roomCount) room\(project.roomCount == 1 ? "" : "s")",
                            systemImage: "square.3.layers.3d"
                        )
                    }
                    if !project.designs.isEmpty {
                        Text("·")
                        Label(
                            "\(project.designs.count) design\(project.designs.count == 1 ? "" : "s")",
                            systemImage: "paintbrush"
                        )
                    }
                }
                .font(LumaFont.caption1)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Text(project.updatedAt, style: .relative)
                    .font(LumaFont.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, LumaSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(project.name). \(project.roomCount) rooms. \(project.designs.count) designs."
        )
    }

    private var projectGradient: LinearGradient {
        let hue = Double(project.id.hashValue & 0xFFFF) / Double(0xFFFF)
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.5, brightness: 0.6),
                Color(hue: hue, saturation: 0.4, brightness: 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            LumaHaptics.impact(.medium)
            action()
        }) {
            VStack(spacing: LumaSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                Text(label)
                    .font(LumaFont.caption1)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LumaSpacing.xs)
            // Explicit 44pt minimum touch area
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Design Style Card

struct DesignStyleCard: View {
    let style: DesignStyle
    let action: () -> Void

    var body: some View {
        Button(action: { LumaHaptics.impact(.light); action() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Palette swatch strip — 4 colours side by side
                HStack(spacing: 0) {
                    ForEach(style.palette.prefix(4).indices, id: \.self) { i in
                        style.palette[i]
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                    }
                }
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: LumaRadius.lg,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: LumaRadius.lg
                ))

                // Name + description
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.rawValue)
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(style.description)
                        .font(LumaFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(LumaSpacing.sm)
            }
            .frame(width: 148)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.rawValue) design style")
    }
}

// MARK: - Issue Row (used in ProjectDetailView)

struct IssueRow: View {
    let issue: RoomIssue

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: issue.severity.icon)
                .foregroundStyle(issue.severity.color)
                .font(.title3)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(LumaFont.subhead).fontWeight(.semibold)
                Text(issue.suggestion)
                    .font(LumaFont.caption1).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
    }
}

// MARK: - Free Upgrade Banner

struct FreeUpgradeBanner: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.multicolor)
                .frame(width: 36, height: 36)
                .background(Color.Luma.goldFallback.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Upgrade to Pro")
                    .font(LumaFont.subhead).fontWeight(.semibold)
                Text("Unlimited scans · HD exports · cloud sync")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
            }

            Spacer()

            Button("See Plans") {
                appState.isShowingSubscription = true
                LumaHaptics.impact(.light)
            }
            .font(LumaFont.caption1)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, LumaSpacing.md)
            .padding(.vertical, LumaSpacing.xs + 2)
            .background(Color.Luma.goldFallback)
            .clipShape(Capsule())
        }
        .padding(LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }
}

// MARK: - Referral Nudge Banner

struct ReferralNudgeBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: "gift.fill")
                .foregroundStyle(Color.Luma.accent)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color.Luma.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Share LumaSpace")
                    .font(LumaFont.subhead).fontWeight(.semibold)
                Text("Invite friends to LumaSpace")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Living Room Refresh", text: $name)
                        .autocorrectionDisabled()
                        .focused($focused)
                } header: {
                    Text("Project Name")
                } footer: {
                    Text("You can rename this at any time.")
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        let _ = projectStore.create(name: trimmed.isEmpty ? "Untitled Project" : trimmed)
                        dismiss()
                        LumaHaptics.notification(.success)
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Style Inspiration Sheet

struct StyleInspirationSheet: View {
    let style: DesignStyle
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    // Palette swatch
                    HStack(spacing: 0) {
                        ForEach(Array(style.palette.enumerated()), id: \.offset) { _, color in
                            color.frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                    .padding(.horizontal)

                    VStack(spacing: LumaSpacing.lg) {
                        Text(style.description)
                            .font(LumaFont.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        LumaPrimaryButton("Design in This Style", hint: "Opens the AI Design tab with this style selected") {
                            dismiss()
                            appState.activeTab = .designs
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .navigationTitle(style.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - How It Works

struct HowItWorksStep: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let detail: String
    let color: Color

    static let all: [HowItWorksStep] = [
        HowItWorksStep(
            id: 1, icon: "camera.viewfinder", title: "Scan Your Room",
            detail: "Walk around the room — LiDAR captures precise dimensions in under a minute.",
            color: Color.Luma.accent
        ),
        HowItWorksStep(
            id: 2, icon: "wand.and.stars", title: "Generate AI Designs",
            detail: "Pick a style and let GPT-4o + DALL·E 3 create beautiful, personalised concepts.",
            color: Color.Luma.purple
        ),
        HowItWorksStep(
            id: 3, icon: "chair", title: "Furnish Your Room",
            detail: "Tap Furnish, pick a piece, then tap the floor to place it at true scale. Pinch to resize, drag to move.",
            color: Color.Luma.navy
        ),
        HowItWorksStep(
            id: 4, icon: "doc.richtext.fill", title: "Export & Buy",
            detail: "Export a PDF with measurements and a shopping list — no surprises, no returns.",
            color: Color.Luma.goldFallback
        )
    ]
}

struct HowItWorksRow: View {
    let step: HowItWorksStep

    var body: some View {
        HStack(alignment: .top, spacing: LumaSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                    .fill(step.color.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: step.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(step.color)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(LumaFont.subhead).fontWeight(.semibold)
                Text(step.detail)
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }
}
