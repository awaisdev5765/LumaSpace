import SwiftUI
import TipKit
import PhotosUI

struct DesignDetailView: View {
    let concept: DesignConcept
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @State private var isFavorite: Bool
    @State private var showFutureVision = false
    @State private var copiedHex: String?
    @State private var beforePhotoItem: PhotosPickerItem?
    @State private var localBeforePhotoData: Data?

    init(concept: DesignConcept) {
        self.concept = concept
        self._isFavorite = State(initialValue: concept.isFavorite)
        self._localBeforePhotoData = State(initialValue: concept.roomBeforePhotoData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection

                    // All content flows in a single vertical scroll — no nested tab picker
                    VStack(spacing: LumaSpacing.xxl) {
                        overviewSection
                        furnitureSection
                        budgetSection
                        shoppingSection
                    }
                    .padding()
                    .padding(.bottom, LumaSpacing.xxxl)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            isFavorite.toggle()
                            persistFavorite(isFavorite)
                            LumaHaptics.impact(.light)
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(isFavorite ? .red : .primary)
                        }
                        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                        Menu {
                            Button("Share for Stories / Social", systemImage: "square.and.arrow.up") { shareDesign() }
                            Button("Export PDF Report", systemImage: "doc.fill") { exportPDF() }
                            Divider()
                            Button("Future Vision", systemImage: "sparkles") { showFutureVision = true }
                            Button("Place in AR", systemImage: "arkit") { openAR() }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showFutureVision) {
            if let room = ProjectStore.shared.projects.flatMap(\.rooms).first {
                FutureVisionView(room: room)
                    .environmentObject(store)
                    .environmentObject(appState)
                    .environmentObject(AIDesignService.shared)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            if let image = concept.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
            } else {
                LinearGradient(
                    colors: concept.style.palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 280)
            }

            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                Text(concept.style.emoji + " " + concept.style.rawValue)
                    .font(LumaFont.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))
                Text(concept.title)
                    .font(LumaFont.title1)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LumaSpacing.xxl)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Overview

    @State private var beforeAfterTip = BeforeAfterTip()

    private var overviewSection: some View {
        VStack(spacing: LumaSpacing.xl) {
            // Before / After slider — uses scan photo or a photo added here
            if let imageData = concept.imageData, let afterImage = UIImage(data: imageData) {
                let beforeImage = localBeforePhotoData.flatMap(UIImage.init)
                VStack(alignment: .leading, spacing: LumaSpacing.md) {
                    LumaSectionHeader(
                        title: beforeImage != nil ? "Before / After" : "AI Design Preview"
                    )
                    BeforeAfterSlider(beforeImage: beforeImage, afterImage: afterImage)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                    if beforeImage == nil {
                        PhotosPicker(selection: $beforePhotoItem, matching: .images) {
                            Label("Add Before Photo", systemImage: "photo.badge.plus")
                                .font(LumaFont.caption1)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.Luma.accent)
                                .padding(.horizontal, LumaSpacing.md)
                                .padding(.vertical, LumaSpacing.xs + 2)
                                .background(Color.Luma.accent.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .onChange(of: beforePhotoItem) { _, item in
                            Task {
                                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                                localBeforePhotoData = data
                                saveBeforePhoto(data)
                                LumaHaptics.notification(.success)
                            }
                        }
                    } else {
                        HStack {
                            TipView(beforeAfterTip, arrowEdge: .top)
                                .tipBackground(Color(uiColor: .secondarySystemGroupedBackground))
                            Spacer()
                            PhotosPicker(selection: $beforePhotoItem, matching: .images) {
                                Label("Change Photo", systemImage: "arrow.triangle.2.circlepath")
                                    .font(LumaFont.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .onChange(of: beforePhotoItem) { _, item in
                                Task {
                                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                                    localBeforePhotoData = data
                                    saveBeforePhoto(data)
                                }
                            }
                        }
                    }
                }
            }

            // Description
            VStack(alignment: .leading, spacing: LumaSpacing.md) {
                LumaSectionHeader(title: "About This Design")
                Text(concept.description)
                    .font(LumaFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Color palette with hex copy
            colorPaletteSection

            // Tags
            if !concept.tags.isEmpty {
                VStack(alignment: .leading, spacing: LumaSpacing.md) {
                    LumaSectionHeader(title: "Tags")
                    FlowLayout(concept.tags) { tag in LumaChip(text: tag) }
                }
            }

            // AR CTA
            LumaPrimaryButton("Place in AR", icon: "arkit") { openAR() }
        }
    }

    // MARK: - Color Palette (with hex copy)

    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(title: "Color Palette")
                .overlay(alignment: .trailing) {
                    if let hex = copiedHex {
                        Text("\(hex) copied!")
                            .font(LumaFont.caption2)
                            .foregroundStyle(Color.Luma.accent)
                            .transition(.opacity)
                    }
                }

            HStack(spacing: 0) {
                ForEach(concept.style.palette.prefix(4).indices, id: \.self) { i in
                    let color = concept.style.palette[i]
                    color
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .overlay(alignment: .bottom) {
                            Text(color.hexString)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.bottom, 4)
                        }
                        .onTapGesture {
                            let hex = color.hexString
                            UIPasteboard.general.string = hex
                            withAnimation(reduceMotion ? .none : .lumaFast) { copiedHex = hex }
                            LumaHaptics.notification(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(reduceMotion ? .none : .lumaFast) { copiedHex = nil }
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            .animation(reduceMotion ? .none : .lumaFast, value: copiedHex)

            Text("Tap a colour to copy its hex code")
                .font(LumaFont.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Furniture

    private var furnitureSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(title: "Furniture Suggestions", subtitle: "\(concept.furnitureSuggestions.count) items")
            ForEach(concept.furnitureSuggestions) { item in
                FurnitureRow(item: item)
            }
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(title: "Estimated Budget")

            HStack {
                VStack(alignment: .leading) {
                    Text("Total")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(concept.estimatedCost).formatted())")
                        .font(LumaFont.title1)
                        .fontWeight(.bold)
                }
                Spacer()
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.Luma.goldFallback)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding()
            .lumaCard()

            ForEach(concept.furnitureSuggestions) { item in
                if let price = item.price {
                    HStack {
                        Label(item.name, systemImage: item.category.icon)
                            .font(LumaFont.subhead)
                        Spacer()
                        Text("$\(Int(price).formatted())")
                            .font(LumaFont.subhead)
                            .fontWeight(.semibold)
                    }
                    .padding(LumaSpacing.md)
                    .lumaCard(padding: LumaSpacing.md)
                }
            }

            if !store.currentTier.hasBudgetPlanner {
                premiumBudgetTeaser
            }
        }
    }

    private var premiumBudgetTeaser: some View {
        VStack(spacing: LumaSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.Luma.goldFallback)
                .symbolRenderingMode(.hierarchical)
            Text("Full Budget Planner")
                .font(LumaFont.headline)
            Text("Set a total budget and get a prioritized AI-generated shopping list.")
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            LumaPrimaryButton("Upgrade to Premium") {
                appState.isShowingSubscription = true
            }
        }
        .padding()
        .lumaCard()
    }

    // MARK: - Shopping (inline, not a tab)

    private var shoppingSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(
                title: "Shop This Look",
                action: { appState.activeTab = .designs },
                actionLabel: "View All"
            )
            ForEach(concept.furnitureSuggestions.prefix(3)) { item in
                FurnitureRow(item: item)
            }
            if concept.furnitureSuggestions.count > 3 {
                Button("See all \(concept.furnitureSuggestions.count) items") {
                    appState.activeTab = .designs
                    dismiss()
                }
                .font(LumaFont.subhead)
                .foregroundStyle(Color.Luma.accent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func persistFavorite(_ value: Bool) {
        let store = ProjectStore.shared
        for var project in store.projects {
            if let idx = project.designs.firstIndex(where: { $0.id == concept.id }) {
                project.designs[idx].isFavorite = value
                store.update(project)
                return
            }
        }
    }

    private func shareDesign() {
        // Render a full 9:16 social card and share it
        let beforePhoto = concept.roomBeforePhotoData.flatMap(UIImage.init)
        if let card = DesignShareCardRenderer.render(concept: concept, beforePhoto: beforePhoto) {
            let vc = UIActivityViewController(activityItems: [card], applicationActivities: nil)
            UIApplication.shared.topViewController?.present(vc, animated: true)
            AnalyticsService.shared.track(.designShared, properties: ["style": concept.style.rawValue])
        }
    }

    private func shareAsImage() {
        // Same social card — shown as a separate menu item for explicit image share
        shareDesign()
    }

    private func exportPDF() {
        var project = Project.empty(name: concept.title)
        project.designs = [concept]
        Task { await PDFExportService.shared.shareAsync(project) }
    }

    private func openAR() {
        NotificationCenter.default.post(name: .launchAR, object: nil)
        dismiss()
    }

    private func saveBeforePhoto(_ data: Data) {
        let store = ProjectStore.shared
        for var project in store.projects {
            var changed = false
            for di in project.designs.indices
            where project.designs[di].id == concept.id {
                project.designs[di].roomBeforePhotoData = data
                changed = true
            }
            if changed { store.update(project); break }
        }
    }

}

// MARK: - Furniture Row

struct FurnitureRow: View {
    let item: FurnitureItem
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous)
                    .fill(Color.Luma.accent.opacity(0.08))
                    .frame(width: 52, height: 52)
                Image(systemName: item.category.icon)
                    .font(.title3)
                    .foregroundStyle(Color.Luma.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(LumaFont.subhead).fontWeight(.semibold)
                if let brand = item.brand {
                    Text(brand).font(LumaFont.caption1).foregroundStyle(.secondary)
                }
                Text(
                    "\(String(format: "%.0f", item.dimensions.width * 100)) × \(String(format: "%.0f", item.dimensions.depth * 100)) cm"
                )
                .font(LumaFont.caption2).foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let price = item.price {
                    Text("$\(Int(price).formatted())")
                        .font(LumaFont.subhead).fontWeight(.bold)
                }
                Button("View") {
                    LumaHaptics.impact(.light)
                    showDetail = true
                }
                .font(LumaFont.caption1)
                .foregroundStyle(Color.Luma.accent)
            }
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
        .sheet(isPresented: $showDetail) {
            FurnitureDetailSheet(item: item)
                .environmentObject(AppState.shared)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(data), id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}

// MARK: - UIApplication top VC helper

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes.first as? UIWindowScene
        var vc = scene?.windows.first?.rootViewController
        while let presented = vc?.presentedViewController {
            vc = presented
        }
        return vc
    }
}

