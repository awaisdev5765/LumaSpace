import SwiftUI
import TipKit
import RealityKit
import ARKit
import Combine
import AVFoundation
import UIKit

// MARK: - AR Room View (Tab)

struct ARRoomView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = ARRoomViewModel()
    @State private var showFurniturePicker = false
    @State private var showLayoutSaved = false
    @State private var showCoachMarks = !UserDefaults.standard.bool(forKey: "ar_coach_marks_shown")
    @State private var showWallColorPicker = false
    @State private var lightingMode: ARLightingMode = .day
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private let arTip = ARPlacementTip()

    private var arAvailable: Bool {
        ARWorldTrackingConfiguration.isSupported
    }

    enum ARLightingMode: String, CaseIterable {
        case day = "Day"
        case evening = "Evening"
        case night = "Night"

        var icon: String {
            switch self {
            case .day:     return "sun.max"
            case .evening: return "sunset"
            case .night:   return "moon.stars"
            }
        }

        // RealityKit IBL intensity exponent — higher = brighter (default 2)
        var intensityExponent: Float {
            switch self {
            case .day:     return 2.0
            case .evening: return 0.6
            case .night:   return 0.1
            }
        }
    }

    var body: some View {
        Group {
            if !arAvailable {
                arUnavailableView
            } else if cameraPermission == .denied || cameraPermission == .restricted {
                cameraPermissionDeniedView
            } else {
                arSessionView
            }
        }
        .onAppear {
            refreshCameraPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshCameraPermission()
        }
    }

    // MARK: - Unavailability / Permission fallback views

    private var arUnavailableView: some View {
        ContentUnavailableView {
            Label("AR Not Available", systemImage: "arkit")
        } description: {
            Text("Augmented Reality requires an ARKit-compatible device. This iPhone or iPad does not support AR.")
        }
    }

    private var cameraPermissionDeniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Needed", systemImage: "camera.fill")
        } description: {
            Text("LumaSpace needs your camera to show augmented reality. Enable camera access in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Luma.accent)
        }
    }

    private var arSessionView: some View {
        ZStack {
            // AR Session
            ARViewRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            // Session error overlay
            if let error = viewModel.sessionError {
                arErrorBanner(error)
            }

            // Session interrupted overlay
            if viewModel.sessionInterrupted {
                arInterruptedBanner
            }

            // Overlay UI
            VStack {
                arTopBar
                Spacer()
                arBottomControls
            }
        }
        .sheet(isPresented: $showFurniturePicker) {
            FurniturePickerSheet { item in
                viewModel.selectForPlacement(item)
                showFurniturePicker = false
            }
        }
        .sheet(isPresented: $showWallColorPicker) {
            WallColorPickerSheet(currentColor: viewModel.wallColor) { picked in
                viewModel.applyWallColor(picked)
                LumaHaptics.selection()
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .center) {
            VStack(spacing: LumaSpacing.md) {
                if viewModel.isPlacing {
                    placementReticle
                }
                if let warning = viewModel.fitWarning {
                    fitWarningToast(warning)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .none : .lumaSpring, value: viewModel.fitWarning)
        }
        .overlay {
            if showLayoutSaved { savedConfirmation }
        }
        .overlay {
            if showCoachMarks {
                ARCoachMarksView(isShowing: $showCoachMarks)
                    .zIndex(100)
            }
        }
        .safeAreaInset(edge: .top, alignment: .leading, spacing: 0) {
            TipView(arTip, arrowEdge: .top)
                .tipBackground(.ultraThinMaterial)
                .padding()
        }
        .onAppear {
            AnalyticsService.shared.track(.arSessionStarted)
            requestCameraPermissionIfNeeded()
        }
        .onChange(of: lightingMode) { _, newMode in
            viewModel.applyLightingMode(newMode)
            LumaHaptics.selection()
        }
    }

    private func arErrorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: LumaSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(LumaFont.caption1)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(LumaSpacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .padding()
            Spacer()
        }
    }

    private var arInterruptedBanner: some View {
        VStack {
            Spacer()
            Label("AR Paused", systemImage: "pause.circle.fill")
                .font(LumaFont.subhead.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(LumaSpacing.md)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, LumaSpacing.xxxl)
        }
    }

    private func refreshCameraPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestCameraPermissionIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        Task {
            let _ = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { refreshCameraPermission() }
        }
    }

    static func placementSuccessHaptic() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            gen.impactOccurred(intensity: 0.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Top Bar

    private var arTopBar: some View {
        VStack(spacing: LumaSpacing.sm) {
            HStack {
                // Mode indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("AR Active")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, LumaSpacing.md)
                .padding(.vertical, LumaSpacing.xs + 2)
                .background(.thinMaterial, in: Capsule())

                Spacer()

                HStack(spacing: LumaSpacing.sm) {
                    // Tips — replays coach marks so users can learn gestures at any time
                    LumaIconButton(icon: "questionmark.circle", label: "Show tips") {
                        withAnimation(reduceMotion ? .none : .lumaSpring) {
                            showCoachMarks = true
                            UserDefaults.standard.removeObject(forKey: "ar_coach_marks_shown")
                        }
                        LumaHaptics.impact(.light)
                    }

                    // Wall color — paints detected wall planes with a chosen color
                    LumaIconButton(
                        icon: viewModel.wallColor == nil ? "paintbrush" : "paintbrush.fill",
                        label: "Wall color"
                    ) {
                        showWallColorPicker = true
                        LumaHaptics.impact(.light)
                    }

                    LumaIconButton(icon: "arrow.uturn.backward", label: "Undo placement") {
                        viewModel.undoLastPlacement()
                    }
                    .opacity(viewModel.canUndo ? 1 : 0.4)
                    .disabled(!viewModel.canUndo)

                    LumaIconButton(icon: "square.and.arrow.down", label: "Save layout") {
                        viewModel.saveLayout()
                        showLayoutSaved = true
                        ARRoomView.placementSuccessHaptic()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(reduceMotion ? .none : .lumaFast) { showLayoutSaved = false }
                        }
                    }
                }
            }

            // Lighting mode picker
            lightingPicker
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LumaSpacing.lg)
        .padding(.top, LumaSpacing.xl)
    }

    // MARK: - Fit Warning Toast (centre-screen)
    // Uses .regularMaterial so it reads well over both dark and light surfaces.

    private func fitWarningToast(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.hierarchical)
            .font(LumaFont.caption1)
            .fontWeight(.semibold)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .padding(.horizontal, LumaSpacing.lg)
            .padding(.vertical, LumaSpacing.md)
            .frame(maxWidth: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
    }

    // MARK: - Lighting Picker

    private var lightingPicker: some View {
        HStack(spacing: 2) {
            ForEach(ARLightingMode.allCases, id: \.self) { mode in
                Button {
                    lightingMode = mode
                    LumaHaptics.selection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .medium))
                        if lightingMode == mode {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundStyle(lightingMode == mode ? .primary : .secondary)
                    .padding(.horizontal, LumaSpacing.sm)
                    .padding(.vertical, LumaSpacing.xs + 2)
                    .background(lightingMode == mode ? Color(uiColor: .systemBackground).opacity(0.8) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.thinMaterial, in: Capsule())
    }

    // MARK: - Bottom Controls

    private var arBottomControls: some View {
        VStack(spacing: LumaSpacing.sm) {
            // Pending item banner — shown while waiting for floor tap
            if let pending = viewModel.pendingItem {
                HStack(spacing: LumaSpacing.sm) {
                    Image(systemName: pending.category.icon)
                        .font(.subheadline)
                        .foregroundStyle(Color.Luma.accent)
                    Text("Point at a flat surface, then tap to place \(pending.name)")
                        .font(LumaFont.caption1)
                        .fontWeight(.medium)
                    Spacer()
                    Button {
                        viewModel.pendingItem = nil
                        viewModel.isPlacing = false
                        LumaHaptics.impact(.light)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel placement")
                }
                .padding(.horizontal, LumaSpacing.lg)
                .padding(.vertical, LumaSpacing.sm)
                .background(.regularMaterial, in: Capsule())
                .padding(.horizontal, LumaSpacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(reduceMotion ? .none : .lumaSpring, value: viewModel.pendingItem != nil)
            }

            HStack(spacing: LumaSpacing.md) {
                // Add furniture — disabled while a placement is pending
                Button {
                    showFurniturePicker = true
                    LumaHaptics.impact(.medium)
                } label: {
                    Label(
                        viewModel.pendingItem == nil ? "Add Furniture" : "Pick Different",
                        systemImage: viewModel.pendingItem == nil ? "plus" : "arrow.left.arrow.right"
                    )
                    .font(LumaFont.subhead.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, LumaSpacing.xl)
                    .padding(.vertical, LumaSpacing.md)
                    .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add furniture to AR scene")

                Button {
                    viewModel.showMeasurements.toggle()
                    LumaHaptics.impact(.light)
                    AnalyticsService.shared.track(.measurementToggled)
                } label: {
                    Image(systemName: viewModel.showMeasurements ? "ruler.fill" : "ruler")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle measurements")

                Button { viewModel.undoAll() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset AR scene")
            }
            .padding(.horizontal, LumaSpacing.lg)
        }
        .padding(.bottom, LumaSpacing.xxl)
    }

    // MARK: - Placement Reticle

    private var placementReticle: some View {
        let onFloor = viewModel.reticleOnFloor
        let ringColor: Color = onFloor ? .green : Color.white.opacity(0.7)
        return ZStack {
            // Outer pulse ring
            Circle()
                .stroke(ringColor.opacity(0.35), lineWidth: 1)
                .frame(width: 80, height: 80)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: onFloor)
            // Main ring
            Circle()
                .stroke(ringColor, lineWidth: 2)
                .frame(width: 56, height: 56)
            // Fill
            Circle()
                .fill(ringColor.opacity(0.12))
                .frame(width: 56, height: 56)
            // Crosshair
            Image(systemName: onFloor ? "checkmark" : "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ringColor)
        }
        .animation(reduceMotion ? .none : .lumaFast, value: onFloor)
    }

    // MARK: - Saved Confirmation

    private var savedConfirmation: some View {
        Label("Layout Saved", systemImage: "checkmark.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.green)
            .font(LumaFont.headline)
            .padding(.horizontal, LumaSpacing.xl)
            .padding(.vertical, LumaSpacing.md)
            .background(.regularMaterial, in: Capsule())
            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            .animation(reduceMotion ? .none : .lumaSpring, value: showLayoutSaved)
    }
}

// MARK: - ARView Representable

struct ARViewRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: ARRoomViewModel

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        view.session.run(config)
        view.environment.sceneUnderstanding.options = [.occlusion, .physics]
        viewModel.bind(arView: view)

        // Native Apple coaching overlay — guides user to move phone until floor is detected
        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(tapGesture)

        // Session delegate drives the live reticle floor-detection indicator
        view.session.delegate = context.coordinator
        context.coordinator.arView = view

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    final class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ARRoomViewModel
        weak var arView: ARView?
        init(viewModel: ARRoomViewModel) { self.viewModel = viewModel }

        // Called every frame — update the reticle floor-detection state while placing
        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            Task { @MainActor [weak self] in
                guard let self, viewModel.isPlacing else { return }
                viewModel.updateReticle()
            }
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor [weak self] in
                self?.viewModel.sessionError = (error as NSError).localizedDescription
            }
        }

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            Task { @MainActor [weak self] in
                guard let self, let arView else { return }
                for anchor in anchors.compactMap({ $0 as? ARPlaneAnchor }) {
                    viewModel.registerWallPlane(for: anchor, in: arView)
                }
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                for anchor in anchors.compactMap({ $0 as? ARPlaneAnchor }) {
                    viewModel.updateWallPlane(for: anchor)
                }
            }
        }

        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor [weak self] in
                self?.viewModel.sessionInterrupted = true
            }
        }

        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor [weak self] in
                self?.viewModel.sessionInterrupted = false
                self?.viewModel.sessionError = nil
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: arView)
            guard let arView else { return }
            let results = arView.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard viewModel.pendingItem != nil else {
                    LumaHaptics.selection()
                    return
                }
                if let hit = results.first {
                    viewModel.confirmPlacement(at: hit.worldTransform)
                } else {
                    // No floor found — give subtle haptic and keep waiting
                    LumaHaptics.impact(.light)
                }
            }
        }
    }
}

// MARK: - Wall Color Picker Sheet

struct WallColorPickerSheet: View {
    let currentColor: UIColor?
    let onSelect: (UIColor?) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct WallSwatch: Identifiable {
        let id = UUID()
        let name: String
        let color: UIColor
    }

    private let swatches: [WallSwatch] = [
        WallSwatch(name: "Bright White",    color: UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)),
        WallSwatch(name: "Warm Cream",      color: UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 1)),
        WallSwatch(name: "Linen",           color: UIColor(red: 0.93, green: 0.88, blue: 0.82, alpha: 1)),
        WallSwatch(name: "Light Gray",      color: UIColor(red: 0.83, green: 0.84, blue: 0.85, alpha: 1)),
        WallSwatch(name: "Slate",           color: UIColor(red: 0.60, green: 0.65, blue: 0.68, alpha: 1)),
        WallSwatch(name: "Sage Green",      color: UIColor(red: 0.72, green: 0.80, blue: 0.70, alpha: 1)),
        WallSwatch(name: "Forest",          color: UIColor(red: 0.33, green: 0.50, blue: 0.40, alpha: 1)),
        WallSwatch(name: "Dusty Blue",      color: UIColor(red: 0.62, green: 0.72, blue: 0.82, alpha: 1)),
        WallSwatch(name: "Navy",            color: UIColor(red: 0.13, green: 0.22, blue: 0.40, alpha: 1)),
        WallSwatch(name: "Terracotta",      color: UIColor(red: 0.80, green: 0.47, blue: 0.35, alpha: 1)),
        WallSwatch(name: "Blush",           color: UIColor(red: 0.92, green: 0.76, blue: 0.75, alpha: 1)),
        WallSwatch(name: "Charcoal",        color: UIColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1)),
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: LumaSpacing.lg) {
                Text("Pick a wall color to preview how it looks in your room. Walls must be detected first — move your phone slowly along the wall surface.")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LumaSpacing.sm), count: 4),
                          spacing: LumaSpacing.md) {
                    // Clear/remove option
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        VStack(spacing: LumaSpacing.xs) {
                            ZStack {
                                RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .frame(height: 56)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous)
                                            .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                                    }
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .overlay(alignment: .topTrailing) {
                                if currentColor == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.Luma.accent)
                                        .offset(x: 4, y: -4)
                                }
                            }
                            Text("None")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(swatches) { swatch in
                        Button {
                            onSelect(swatch.color)
                            dismiss()
                        } label: {
                            VStack(spacing: LumaSpacing.xs) {
                                RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous)
                                    .fill(Color(uiColor: swatch.color))
                                    .frame(height: 56)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous)
                                            .strokeBorder(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if let current = currentColor,
                                           current.isApproximatelyEqual(to: swatch.color) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                                .offset(x: 4, y: -4)
                                        }
                                    }
                                Text(swatch.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, LumaSpacing.lg)
            .navigationTitle("Wall Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension UIColor {
    func isApproximatelyEqual(to other: UIColor, tolerance: CGFloat = 0.05) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < tolerance && abs(g1 - g2) < tolerance && abs(b1 - b2) < tolerance
    }
}

// MARK: - Furniture Picker Sheet

struct FurniturePickerSheet: View {
    let onSelect: (FurnitureItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FurnitureItem.Category?
    @State private var searchText = ""

    private let catalogService = FurnitureCatalogService.shared

    private var filtered: [FurnitureItem] {
        var products = catalogService.allProducts
        if let cat = selectedCategory { products = products.filter { $0.category == cat } }
        if !searchText.isEmpty {
            products = products.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
        return products.map { $0.toFurnitureItem() }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter
                    .padding()

                List(filtered) { item in
                    Button {
                        onSelect(item)
                        LumaHaptics.impact(.medium)
                        dismiss()
                    } label: {
                        ARFurnitureRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search furniture")
            .navigationTitle("Add Furniture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumaSpacing.xs) {
                LumaChip(text: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(FurnitureItem.Category.allCases, id: \.self) { cat in
                    LumaChip(
                        text: cat.rawValue.capitalized,
                        isSelected: selectedCategory == cat
                    ) { selectedCategory = cat }
                }
            }
        }
    }
}

struct ARFurnitureRow: View {
    let item: FurnitureItem

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
                Text(item.name).font(LumaFont.subhead).fontWeight(.semibold)
                Text("\(String(format: "%.0f", item.dimensions.width * 100)) × \(String(format: "%.0f", item.dimensions.depth * 100)) cm")
                    .font(LumaFont.caption1).foregroundStyle(.secondary)
            }

            Spacer()

            if let price = item.price {
                Text("$\(Int(price))")
                    .font(LumaFont.subhead)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Luma.accent)
            }

            Image(systemName: "arkit")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, LumaSpacing.xs)
    }
}
