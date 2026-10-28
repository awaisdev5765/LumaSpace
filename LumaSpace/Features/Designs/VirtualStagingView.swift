import SwiftUI
import PhotosUI

struct VirtualStagingView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var stagedImage: UIImage?
    @State private var isGenerating = false
    @State private var selectedStyle: DesignStyle = .japandi
    @State private var showUpgrade = false
    @State private var errorMessage: String?
    @State private var roomDescription: String?   // GPT-4o Vision analysis of the uploaded photo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    if !store.canAccessFeature(requiring: .pro) {
                        stagingGate
                    } else {
                        photoSection
                        styleSection
                        if let source = sourceImage {
                            generateButton(source: source)
                        }
                        resultSection
                    }
                }
                .padding()
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Virtual Staging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .sheet(isPresented: $showUpgrade) {
            SubscriptionView(context: .featureGate("Virtual Staging"))
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(title: "Upload Room Photo")

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(height: 200)
                    if let img = sourceImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                    } else {
                        VStack(spacing: LumaSpacing.sm) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundStyle(Color.Luma.accent)
                            Text("Tap to add an empty room photo")
                                .font(LumaFont.subhead)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        sourceImage = UIImage(data: data)
                        stagedImage = nil
                        roomDescription = nil
                    }
                }
            }
        }
    }

    // MARK: - Style Section

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(title: "Furnishing Style")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.sm) {
                    ForEach(DesignStyle.allCases) { style in
                        LumaChip(
                            text: "\(style.emoji) \(style.rawValue)",
                            isSelected: selectedStyle == style
                        ) { selectedStyle = style }
                    }
                }
            }
        }
    }

    // MARK: - Generate Button

    private func generateButton(source: UIImage) -> some View {
        LumaPrimaryButton(
            "Stage This Room",
            icon: "wand.and.stars",
            isLoading: isGenerating
        ) {
            Task { await generateStaging(source: source) }
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        if isGenerating {
            VStack(spacing: LumaSpacing.md) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Color.Luma.accent)
                Text("AI is furnishing your room…")
                    .font(LumaFont.subhead)
                    .foregroundStyle(.secondary)
                Text("DALL·E 3 rendering in progress")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, LumaSpacing.xxxl)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if let staged = stagedImage, let source = sourceImage {
            VStack(spacing: LumaSpacing.md) {
                LumaSectionHeader(title: "Before / After")
                BeforeAfterSlider(beforeImage: source, afterImage: staged)
                    .frame(height: 260)

                // Show what GPT-4o understood about the room
                if let desc = roomDescription {
                    DisclosureGroup {
                        Text(desc)
                            .font(LumaFont.caption1)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, LumaSpacing.xs)
                    } label: {
                        Label("AI Room Analysis", systemImage: "brain")
                            .font(LumaFont.caption1)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.Luma.accent)
                    }
                    .padding(LumaSpacing.md)
                    .lumaCard(padding: LumaSpacing.md)
                }

                HStack(spacing: LumaSpacing.md) {
                    LumaSecondaryButton("Save to Project", icon: "square.and.arrow.down") {
                        saveToProject(image: staged)
                    }
                    LumaPrimaryButton("Share", icon: "square.and.arrow.up") {
                        shareImage(staged)
                    }
                }
            }
        } else if let error = errorMessage {
            LumaEmptyState(
                icon: "exclamationmark.triangle",
                title: "Generation Failed",
                message: error
            )
        }
    }

    // MARK: - Gate

    private var stagingGate: some View {
        VStack(spacing: LumaSpacing.xxl) {
            // Before → After illustration
            HStack(spacing: LumaSpacing.md) {
                stagingPreviewPanel(label: "Empty Room", icon: "photo", isBefore: true)
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(Color.Luma.accent)
                stagingPreviewPanel(label: "AI Staged", icon: "house.fill", isBefore: false)
            }
            .padding(.horizontal)
            .padding(.top, LumaSpacing.xl)

            VStack(spacing: LumaSpacing.md) {
                Text("Virtual Staging")
                    .font(LumaFont.title2.weight(.bold))
                Text("Upload a photo of any empty room and AI furnishes it in your chosen style — perfect for visualising layouts or real estate listings.")
                    .font(LumaFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                stagingFeatureRow(icon: "photo.badge.plus", text: "Upload any room photo")
                stagingFeatureRow(icon: "paintpalette", text: "Choose from 10 design styles")
                stagingFeatureRow(icon: "square.and.arrow.up", text: "Export & share results")
            }
            .padding(.horizontal, LumaSpacing.xl)

            LumaPrimaryButton("Unlock with Pro", icon: "crown.fill") {
                showUpgrade = true
            }
            .padding(.bottom, LumaSpacing.xl)
        }
    }

    private func stagingPreviewPanel(label: String, icon: String, isBefore: Bool) -> some View {
        VStack(spacing: LumaSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                    .fill(isBefore
                          ? Color(uiColor: .secondarySystemGroupedBackground)
                          : Color.Luma.accent.opacity(0.15))
                    .frame(width: 120, height: 90)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .thin))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isBefore ? Color.secondary : Color.Luma.accent)
            }
            Text(label)
                .font(LumaFont.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func stagingFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: LumaSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.Luma.accent)
                .frame(width: 24)
            Text(text)
                .font(LumaFont.subhead)
        }
    }

    // MARK: - Actions

    private func generateStaging(source: UIImage) async {
        withAnimation(.lumaSpring) { isGenerating = true }
        errorMessage = nil
        AnalyticsService.shared.track(.virtualStagingStarted, properties: ["style": selectedStyle.rawValue])

        do {
            // Step 1 — GPT-4o Vision reads the real room
            let description = try await OpenAIService.shared.describeRoomFromPhoto(source)
            roomDescription = description

            // Step 2 — DALL·E 3 stages the room grounded in the description
            let result = try await OpenAIService.shared.generateVirtualStagingFromPhoto(
                source,
                style: selectedStyle
            )
            withAnimation(.lumaSpring) { stagedImage = result }
        } catch {
            withAnimation(.lumaSpring) { errorMessage = error.localizedDescription }
        }
        withAnimation(.lumaSpring) { isGenerating = false }
    }

    private func saveToProject(image: UIImage) {
        // Save to the most recently updated project; create a new one if none exist
        let store = ProjectStore.shared
        let project = store.projects.sorted(by: { $0.updatedAt > $1.updatedAt }).first
        guard var target = project else {
            LumaHaptics.notification(.error)
            return
        }
        let item = MoodboardItem(
            type: .image,
            title: "Virtual Staging — \(selectedStyle.rawValue)",
            imageData: image.jpegData(compressionQuality: 0.85)
        )
        target.moodboardItems.append(item)
        store.update(target)
        LumaHaptics.notification(.success)
    }

    private func shareImage(_ image: UIImage) {
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }
}
