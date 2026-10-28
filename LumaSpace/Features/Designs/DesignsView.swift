import SwiftUI
import TipKit
import UserNotifications

struct DesignsView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = DesignsViewModel()
    @StateObject private var network = NetworkMonitor.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedConcept: DesignConcept?
    @State private var activeSegment: DesignSegment = .concepts
    @State private var showHelp = false
    @State private var showVirtualStaging = false
    @State private var showShopping = false
    @State private var showFutureVision = false
    @State private var quickRefineText = ""
    @FocusState private var refineFocused: Bool

    private let arTip = ARPlacementTip()
    private let beforeAfterTip = BeforeAfterTip()

    enum DesignSegment: String, CaseIterable {
        case concepts  = "Concepts"
        case moodboard = "Moodboard"
        case palette   = "Colors"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !network.isConnected { offlineBanner }
                segmentPicker
                    .padding(.horizontal)
                    .padding(.vertical, LumaSpacing.sm)
                Divider()
                content
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Designs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
        }
        .sheet(item: $selectedConcept) { concept in
            DesignDetailView(concept: concept)
        }
        .sheet(isPresented: $vm.showComparison) {
            if let a = vm.compareFirst, let b = vm.compareSecond {
                ConceptComparisonView(conceptA: a, conceptB: b)
            }
        }
        .sheet(isPresented: $showVirtualStaging) {
            VirtualStagingView()
                .environmentObject(store)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFutureVision) {
            if let room = vm.selectedRoom ?? vm.availableRooms.first {
                FutureVisionView(room: room)
                    .environmentObject(store)
                    .environmentObject(appState)
                    .environmentObject(AIDesignService.shared)
            } else {
                NavigationStack {
                    LumaEmptyState(
                        icon: "sparkles",
                        title: "Scan a Room First",
                        message: "Future Vision needs a scanned room to work with."
                    )
                    .navigationTitle("Future Vision")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showFutureVision = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showShopping) {
            NavigationStack {
                ShoppingView(
                    furnitureItems: vm.generatedConcepts.flatMap(\.furnitureSuggestions),
                    title: "Shop This Look"
                )
                .navigationTitle("Shop This Look")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showShopping = false }
                    }
                }
                .environmentObject(appState)
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView().environmentObject(appState)
        }
        .sheet(isPresented: $vm.showRedoSheet) {
            if let concept = vm.redoConcept {
                RedoWithChangesSheet(
                    concept: concept,
                    prompt: $vm.redoPrompt,
                    isLoading: vm.isRedoing
                ) {
                    Task { await vm.redoWithChanges(concept: concept) }
                }
                .environmentObject(store)
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $vm.showNotifPrePrompt) {
            NotificationPrePromptSheet {
                Task {
                    await NotificationService.shared.requestPermission()
                    NotificationService.shared.schedulePostDesignNudge()
                    NotificationService.shared.scheduleWeeklyInspiration()
                }
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(LumaRadius.xl)
        }
        .onAppear {
            appState.hasNewDesignsReady = false
        }
        .onChange(of: appState.pendingDesignStyles) { _, styles in
            guard let styles else { return }
            vm.selectedStyles = styles
            appState.pendingDesignStyles = nil
        }
        .onChange(of: appState.activeProject) { _, project in
            guard let project else { return }
            if let room = project.rooms.first {
                vm.selectedRoom = room
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: LumaSpacing.sm) {
            Image(systemName: "wifi.slash").font(.caption)
            Text("Offline — cached designs shown when available")
                .font(LumaFont.caption1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, LumaSpacing.xs + 2)
        .background(Color.orange)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.lumaSpring, value: network.isConnected)
    }

    // MARK: - Segment

    private var segmentPicker: some View {
        Picker("View", selection: $activeSegment) {
            ForEach(DesignSegment.allCases, id: \.self) { s in
                Text(s.rawValue).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: activeSegment) { _, _ in LumaHaptics.selection() }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch activeSegment {
            case .concepts:
                ZStack(alignment: .bottom) {
                    conceptsContent
                    if !vm.generatedConcepts.isEmpty && !AIDesignService.shared.isGenerating {
                        quickRefineBar
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
            case .moodboard: MoodboardView()
            case .palette:   ColorPaletteView(selectedStyle: vm.selectedStyles.first ?? .japandi)
            }
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        .id(activeSegment)
        .animation(reduceMotion ? .none : .lumaSpring, value: activeSegment)
    }

    // MARK: - Quick Refine Bar

    private var quickRefineBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: LumaSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.Luma.accent)
                    .accessibilityHidden(true)

                TextField("Refine your design…", text: $quickRefineText)
                    .font(LumaFont.subhead)
                    .submitLabel(.send)
                    .focused($refineFocused)
                    .onSubmit { submitQuickRefine() }
                    .accessibilityLabel("Refinement prompt")
                    .accessibilityHint("Type what to change and press return to regenerate")

                if !quickRefineText.isEmpty {
                    Button { submitQuickRefine() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.Luma.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Apply refinement")
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, LumaSpacing.base)
            .padding(.vertical, LumaSpacing.md)
            .background(.regularMaterial)
        }
        .animation(reduceMotion ? .none : .lumaFast, value: quickRefineText.isEmpty)
    }

    private func submitQuickRefine() {
        let trimmed = quickRefineText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        quickRefineText = ""
        refineFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        LumaHaptics.impact(.medium)
        Task { await vm.startQuickRefine(with: trimmed) }
    }

    // MARK: - Concepts Content

    private var conceptsContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    Color.clear.frame(height: 0).id("concepts-top")

                    if let errorMsg = AIDesignService.shared.error {
                        generationErrorBanner(errorMsg)
                    }

                    roomAndStyleSelector

                    if AIDesignService.shared.isGenerating {
                        generatingView
                    } else if vm.generatedConcepts.isEmpty {
                        emptyConceptsState
                    } else {
                        if vm.generatedConcepts.count >= 2 { compareHint }
                        if let prompt = vm.lastAppliedPrompt { appliedPromptBanner(prompt) }
                        conceptsGrid

                        let allFurniture = vm.generatedConcepts.flatMap(\.furnitureSuggestions)
                        if !allFurniture.isEmpty {
                            Button {
                                showShopping = true
                                LumaHaptics.impact(.light)
                                AnalyticsService.shared.track(.furnitureViewed, properties: ["source": "designs_tab"])
                            } label: {
                                HStack(spacing: LumaSpacing.sm) {
                                    Image(systemName: "cart").font(.subheadline)
                                    Text("Shop This Look — \(allFurniture.count) items")
                                        .font(LumaFont.subhead).fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .foregroundStyle(Color.Luma.accent)
                                .padding(LumaSpacing.md)
                                .background(Color.Luma.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(LumaSpacing.base)
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .refreshable {
                if !AIDesignService.shared.isGenerating {
                    await vm.generateConcepts()
                }
            }
            .onChange(of: vm.generatedConcepts.first?.id) { _, _ in
                withAnimation(.lumaSpring) { proxy.scrollTo("concepts-top", anchor: .top) }
            }
        }
    }

    // MARK: - Sub-views

    private var roomAndStyleSelector: some View {
        VStack(spacing: LumaSpacing.md) {
            Menu {
                ForEach(vm.availableRooms) { room in
                    Button { vm.selectedRoom = room } label: {
                        Label(room.name, systemImage: room.type.icon)
                    }
                }
                if vm.availableRooms.isEmpty { Text("No rooms scanned yet") }
            } label: {
                HStack {
                    Image(systemName: vm.selectedRoom?.type.icon ?? "camera.viewfinder")
                    Text(vm.selectedRoom?.name ?? "Select a Room")
                        .font(LumaFont.subhead).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(LumaSpacing.md)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            }
            .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.xs) {
                    ForEach(DesignStyle.allCases) { style in
                        LumaChip(
                            text: "\(style.emoji) \(style.rawValue)",
                            isSelected: vm.selectedStyles.contains(style)
                        ) {
                            if vm.selectedStyles.contains(style) {
                                vm.selectedStyles.remove(style)
                            } else if store.currentTier == .free && vm.selectedStyles.count >= 1 {
                                appState.isShowingSubscription = true
                            } else {
                                vm.selectedStyles.insert(style)
                            }
                        }
                    }
                }
                .padding(.vertical, LumaSpacing.xs)
            }

            if let style = vm.selectedStyles.first {
                Text(style.description)
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.lumaFast, value: vm.selectedStyles)
            }

            let noRoom = vm.selectedRoom == nil && vm.availableRooms.isEmpty
            let noStyle = vm.selectedStyles.isEmpty
            LumaPrimaryButton(
                "Generate Designs",
                icon: "wand.and.stars",
                isLoading: AIDesignService.shared.isGenerating
            ) {
                Task { await vm.generateConcepts() }
            }
            .disabled(noRoom || noStyle)

            if noRoom {
                Label("Scan a room first, then come back here.", systemImage: "camera.viewfinder")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if noStyle {
                Label("Pick at least one style above.", systemImage: "paintpalette")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var generatingView: some View {
        VStack(spacing: LumaSpacing.xl) {
            SkeletonConceptGrid()
            VStack(spacing: LumaSpacing.sm) {
                ProgressView(value: AIDesignService.shared.generationProgress)
                    .tint(Color.Luma.accent).padding(.horizontal)
                Text("Generating \(Int(AIDesignService.shared.generationProgress * 100))%")
                    .font(LumaFont.subhead).foregroundStyle(.secondary)
                Text("Creating personalised designs for your space…")
                    .font(LumaFont.footnote).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, LumaSpacing.lg)
    }

    @ViewBuilder
    private var emptyConceptsState: some View {
        if vm.availableRooms.isEmpty {
            ContentUnavailableView {
                Label("Scan a Room First", systemImage: "camera.viewfinder")
            } description: {
                Text("Go to the Scan tab and capture your room — AI design requires a scanned space.")
            } actions: {
                Button { appState.activeTab = .scan } label: {
                    Label("Go to Scan", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderedProminent).tint(Color.Luma.accent)
                Button { showHelp = true } label: {
                    Label("Why do I need to scan?", systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered).tint(.secondary)
            }
        } else {
            ContentUnavailableView {
                Label("Ready to Generate", systemImage: "paintbrush.pointed")
            } description: {
                Text("Select a room above, pick a style, then tap Generate Designs.")
            } actions: {
                Button { showHelp = true } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered).tint(.secondary)
            }
        }
    }

    private var conceptsGrid: some View {
        VStack(spacing: LumaSpacing.md) {
            conceptSearchAndFilter

            if vm.filteredConcepts.isEmpty {
                ContentUnavailableView(
                    "No Matching Designs",
                    systemImage: "magnifyingglass",
                    description: Text("Try changing the search or filter.")
                )
                .padding(.vertical, LumaSpacing.xxxl)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: LumaSpacing.md
                ) {
                    ForEach(vm.filteredConcepts) { concept in
                        ConceptCard(
                            concept: concept,
                            isSelectedForCompare: concept.id == vm.compareFirst?.id || concept.id == vm.compareSecond?.id
                        ) {
                            selectedConcept = concept
                        } onLongPress: {
                            vm.selectForCompare(concept)
                        } onRate: { rating in
                            vm.rateConceptLocally(concept, rating: rating)
                        } onRedo: {
                            vm.redoConcept = concept
                            vm.redoPrompt = ""
                            vm.showRedoSheet = true
                            LumaHaptics.impact(.medium)
                        }
                    }
                }
            }
        }
    }

    private var conceptSearchAndFilter: some View {
        VStack(spacing: LumaSpacing.sm) {
            HStack(spacing: LumaSpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.subheadline)
                TextField("Search designs…", text: $vm.conceptSearchText)
                    .font(LumaFont.subhead).submitLabel(.search)
                if !vm.conceptSearchText.isEmpty {
                    Button { vm.conceptSearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LumaSpacing.md)
            .padding(.vertical, LumaSpacing.xs + 2)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.xs) {
                    ForEach(ConceptFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation(.lumaFast) { vm.conceptFilter = filter }
                            LumaHaptics.selection()
                        } label: {
                            Text(filter.rawValue)
                                .font(LumaFont.caption1)
                                .fontWeight(vm.conceptFilter == filter ? .semibold : .regular)
                                .padding(.horizontal, LumaSpacing.md)
                                .padding(.vertical, LumaSpacing.xs + 2)
                                .foregroundStyle(vm.conceptFilter == filter ? .white : .primary)
                                .background(vm.conceptFilter == filter ? Color.Luma.accent : Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .animation(.lumaFast, value: vm.conceptFilter)
                    }
                }
            }
        }
    }

    private var compareHint: some View {
        HStack(spacing: LumaSpacing.sm) {
            Image(systemName: "arrow.left.arrow.right").font(.caption).foregroundStyle(Color.Luma.accent)
            Text("Long-press two cards to compare side by side")
                .font(LumaFont.caption1).foregroundStyle(.secondary)
            Spacer()
            if vm.compareFirst != nil {
                Button("Compare") {
                    if vm.compareFirst != nil && vm.compareSecond != nil { vm.showComparison = true }
                }
                .font(LumaFont.caption1).fontWeight(.semibold).foregroundStyle(Color.Luma.accent)
                .disabled(vm.compareSecond == nil)
            }
        }
        .padding(LumaSpacing.md)
        .background(Color.Luma.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
    }

    private func appliedPromptBanner(_ prompt: String) -> some View {
        HStack(spacing: LumaSpacing.sm) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.Luma.accent).font(.subheadline)
            Text("Applied: \"\(prompt)\"")
                .font(LumaFont.caption1).fontWeight(.medium).lineLimit(1)
            Spacer()
            Button { withAnimation(.lumaFast) { vm.lastAppliedPrompt = nil } } label: {
                Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, LumaSpacing.md)
        .padding(.vertical, LumaSpacing.sm + 2)
        .background(Color.Luma.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func generationErrorBanner(_ message: String) -> some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: "wifi.exclamationmark").foregroundStyle(.red).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Generation issue").font(LumaFont.subhead).fontWeight(.semibold)
                Text(message).font(LumaFont.caption1).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button("Retry") { Task { await vm.generateConcepts() } }
                .font(LumaFont.caption1).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, LumaSpacing.md).padding(.vertical, LumaSpacing.xs + 2)
                .background(.red).clipShape(Capsule())
        }
        .padding(LumaSpacing.md)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: LumaSpacing.sm) {
                Button {
                    showFutureVision = true
                    LumaHaptics.impact(.light)
                } label: {
                    Image(systemName: "sparkles")
                }
                .accessibilityLabel("Future Vision")

                Button {
                    showVirtualStaging = true
                    LumaHaptics.impact(.light)
                } label: {
                    Image(systemName: "house.and.flag")
                }
                .accessibilityLabel("Virtual Staging")

                if let firstRoom = vm.availableRooms.first {
                    NavigationLink {
                        DesignHistoryView(room: firstRoom)
                            .environmentObject(ProjectStore.shared)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .accessibilityLabel("Design history")
                    }
                }

                if !vm.generatedConcepts.isEmpty {
                    Button {
                        withAnimation(.lumaSpring) { activeSegment = .moodboard }
                    } label: {
                        Image(systemName: "photo.stack")
                    }
                    .accessibilityLabel("Open Moodboard")
                }
            }
        }
    }
}
