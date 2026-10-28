import SwiftUI
import RealityKit
import ARKit

@MainActor
final class ARRoomViewModel: ObservableObject {
    @Published var isPlacing = false
    @Published var showMeasurements = false
    @Published var fitWarning: String?
    @Published var placedItems: [FurnitureItem] = []
    @Published var canUndo = false
    @Published var pendingItem: FurnitureItem?
    @Published var sessionError: String?
    @Published var sessionInterrupted = false
    @Published var reticleOnFloor = false
    @Published var wallColor: UIColor? = nil

    private var arView: ARView?
    private var undoStack: [(item: FurnitureItem, anchor: AnchorEntity, label: AnchorEntity?)] = []
    private var wallPlaneEntities: [UUID: (AnchorEntity, ModelEntity)] = [:]

    // MARK: - Wall Color

    func applyWallColor(_ color: UIColor?) {
        wallColor = color
        for (_, (_, entity)) in wallPlaneEntities {
            if let color {
                var mat = SimpleMaterial(color: color.withAlphaComponent(0.40), isMetallic: false)
                mat.roughness = 1.0
                entity.model?.materials = [mat]
                entity.isEnabled = true
            } else {
                entity.isEnabled = false
            }
        }
        AnalyticsService.shared.track(.wallColorChanged, properties: ["applied": color != nil])
    }

    func registerWallPlane(for planeAnchor: ARPlaneAnchor, in arView: ARView) {
        guard planeAnchor.alignment == .vertical else { return }
        let extent = planeAnchor.planeExtent
        let mesh = MeshResource.generatePlane(width: extent.width, depth: extent.height)
        var material = SimpleMaterial(color: UIColor.clear, isMetallic: false)
        if let color = wallColor {
            material = SimpleMaterial(color: color.withAlphaComponent(0.40), isMetallic: false)
            material.roughness = 1.0
        }
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.isEnabled = wallColor != nil
        let anchor = AnchorEntity(anchor: planeAnchor)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        wallPlaneEntities[planeAnchor.identifier] = (anchor, entity)
    }

    func updateWallPlane(for planeAnchor: ARPlaneAnchor) {
        guard let (_, entity) = wallPlaneEntities[planeAnchor.identifier] else { return }
        let extent = planeAnchor.planeExtent
        entity.model?.mesh = MeshResource.generatePlane(width: extent.width, depth: extent.height)
    }

    // MARK: - Reticle

    func updateReticle() {
        guard let arView else { reticleOnFloor = false; return }
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let hits = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)
        reticleOnFloor = !hits.isEmpty
    }

    func bind(arView: ARView) { self.arView = arView }

    func applyLightingMode(_ mode: ARRoomView.ARLightingMode) {
        arView?.environment.lighting.intensityExponent = mode.intensityExponent
    }

    func selectForPlacement(_ item: FurnitureItem) {
        pendingItem = item
        isPlacing = true
        LumaHaptics.impact(.light)
    }

    func confirmPlacement(at worldTransform: simd_float4x4) {
        guard let item = pendingItem, let arView else { return }
        pendingItem = nil
        isPlacing = false
        placeItem(item, at: worldTransform, in: arView)
    }

    func placeFurniture(_ item: FurnitureItem) {
        guard let arView else { return }
        var transform = matrix_identity_float4x4
        if let frame = arView.session.currentFrame {
            let camTransform = frame.camera.transform
            let forward = SIMD4<Float>(0, 0, -1.5, 1)
            let worldPos = camTransform * forward
            transform.columns.3 = worldPos
        }
        placeItem(item, at: transform, in: arView)
    }

    private func placeItem(_ item: FurnitureItem, at worldTransform: simd_float4x4, in arView: ARView) {
        let anchor = AnchorEntity(world: worldTransform)
        let root = makeProceduralEntity(for: item)
        root.name = item.name
        root.generateCollisionShapes(recursive: true)
        arView.installGestures([.translation, .rotation], for: root)

        anchor.addChild(root)
        arView.scene.addAnchor(anchor)

        let labelAnchor: AnchorEntity? = showMeasurements ? makeMeasurementLabel(for: item, parent: anchor) : nil
        undoStack.append((item: item, anchor: anchor, label: labelAnchor))
        placedItems.append(item)
        canUndo = true

        checkFitWarning(for: item)
        AnalyticsService.shared.track(.furniturePlaced, properties: ["name": item.name, "category": item.category.rawValue])
        placementSuccessHaptic()
    }

    private func placementSuccessHaptic() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { gen.impactOccurred(intensity: 0.6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Procedural Furniture Shapes

    private func makeProceduralEntity(for item: FurnitureItem) -> ModelEntity {
        let w = Float(item.dimensions.width)
        let h = Float(item.dimensions.height)
        let d = Float(item.dimensions.depth)

        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: item.category.arColor)
        mat.roughness = .init(floatLiteral: item.category.arRoughness)
        mat.metallic  = .init(floatLiteral: item.category.arMetallic)

        var darkMat = mat
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        item.category.arColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let darkened = UIColor(red: r * 0.70, green: g * 0.70, blue: b * 0.70, alpha: a)
        darkMat.baseColor = .init(tint: darkened)

        switch item.category {
        case .sofa:    return makeSofa(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .chair:   return makeChair(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .table:   return makeTable(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .bed:     return makeBed(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .desk:    return makeTable(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .storage: return makeStorage(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .rug:     return makeRug(w: w, h: h, d: d, mat: mat)
        case .lighting: return makeLamp(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .plant:   return makePlant(w: w, h: h, d: d, mat: mat, darkMat: darkMat)
        case .decor:   return makeSingleBox(w: w, h: h, d: d, r: 0.02, mat: mat)
        }
    }

    private func makeSingleBox(w: Float, h: Float, d: Float, r: Float = 0.01, mat: PhysicallyBasedMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateBox(width: w, height: h, depth: d, cornerRadius: r), materials: [mat])
    }

    private func makeSofa(w: Float, h: Float, d: Float,
                          mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root  = ModelEntity()
        let seatH = h * 0.45
        let backH = h
        let armW  = w * 0.08
        let backD = d * 0.18

        let seat = ModelEntity(mesh: .generateBox(width: w, height: seatH, depth: d, cornerRadius: 0.03), materials: [mat])
        seat.position = [0, seatH / 2, 0]
        let back = ModelEntity(mesh: .generateBox(width: w, height: backH, depth: backD, cornerRadius: 0.02), materials: [mat])
        back.position = [0, backH / 2, -(d / 2) + backD / 2]
        let armMesh = MeshResource.generateBox(width: armW, height: h * 0.7, depth: d - backD, cornerRadius: 0.02)
        let leftArm  = ModelEntity(mesh: armMesh, materials: [mat])
        let rightArm = ModelEntity(mesh: armMesh, materials: [mat])
        leftArm.position  = [-(w / 2) + armW / 2, h * 0.35, backD / 2]
        rightArm.position = [ (w / 2) - armW / 2, h * 0.35, backD / 2]
        [seat, back, leftArm, rightArm].forEach { root.addChild($0) }
        return root
    }

    private func makeChair(w: Float, h: Float, d: Float,
                           mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root  = ModelEntity()
        let seatH = h * 0.40
        let legH  = seatH * 0.85
        let legW  = w * 0.07
        let backH = h - seatH

        let seat = ModelEntity(mesh: .generateBox(width: w * 0.9, height: seatH * 0.3, depth: d * 0.9, cornerRadius: 0.02), materials: [mat])
        seat.position = [0, legH + seatH * 0.15, 0]
        let back = ModelEntity(mesh: .generateBox(width: w * 0.9, height: backH, depth: d * 0.12, cornerRadius: 0.02), materials: [mat])
        back.position = [0, legH + seatH * 0.3 + backH / 2, -(d / 2) + d * 0.06]

        let legMesh = MeshResource.generateBox(width: legW, height: legH, depth: legW, cornerRadius: 0.005)
        let offX = w * 0.35
        let offZ = d * 0.35
        [(-offX, -offZ), (offX, -offZ), (-offX, offZ), (offX, offZ)].forEach { ox, oz in
            let leg = ModelEntity(mesh: legMesh, materials: [darkMat])
            leg.position = [ox, legH / 2, oz]
            root.addChild(leg)
        }
        [seat, back].forEach { root.addChild($0) }
        return root
    }

    private func makeTable(w: Float, h: Float, d: Float,
                           mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root = ModelEntity()
        let topH = h * 0.06
        let legH = h - topH
        let legW = w * 0.05
        let offX = w * 0.42
        let offZ = d * 0.42

        let top = ModelEntity(mesh: .generateBox(width: w, height: topH, depth: d, cornerRadius: 0.01), materials: [mat])
        top.position = [0, h - topH / 2, 0]
        let legMesh = MeshResource.generateBox(width: legW, height: legH, depth: legW, cornerRadius: 0.005)
        [(-offX, -offZ), (offX, -offZ), (-offX, offZ), (offX, offZ)].forEach { ox, oz in
            let leg = ModelEntity(mesh: legMesh, materials: [darkMat])
            leg.position = [ox, legH / 2, oz]
            root.addChild(leg)
        }
        root.addChild(top)
        return root
    }

    private func makeBed(w: Float, h: Float, d: Float,
                         mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root      = ModelEntity()
        let frameH    = h * 0.20
        let mattressH = h * 0.35
        let headH     = h * 1.6
        let headD     = d * 0.07

        let frame = ModelEntity(mesh: .generateBox(width: w, height: frameH, depth: d, cornerRadius: 0.02), materials: [darkMat])
        frame.position = [0, frameH / 2, 0]
        let mattress = ModelEntity(mesh: .generateBox(width: w * 0.95, height: mattressH, depth: d * 0.93, cornerRadius: 0.04), materials: [mat])
        mattress.position = [0, frameH + mattressH / 2, 0]
        let headboard = ModelEntity(mesh: .generateBox(width: w, height: headH, depth: headD, cornerRadius: 0.03), materials: [darkMat])
        headboard.position = [0, headH / 2, -(d / 2) + headD / 2]
        [frame, mattress, headboard].forEach { root.addChild($0) }
        return root
    }

    private func makeStorage(w: Float, h: Float, d: Float,
                             mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root  = ModelEntity()
        let shell = ModelEntity(mesh: .generateBox(width: w, height: h, depth: d, cornerRadius: 0.01), materials: [mat])
        shell.position = [0, h / 2, 0]
        root.addChild(shell)
        let shelfH: Float = 0.015
        let shelfD = d * 0.9
        [0.33, 0.66].forEach { frac in
            let shelf = ModelEntity(mesh: .generateBox(width: w * 0.96, height: shelfH, depth: shelfD, cornerRadius: 0.005), materials: [darkMat])
            shelf.position = [0, h * Float(frac), 0]
            root.addChild(shelf)
        }
        return root
    }

    private func makeRug(w: Float, h: Float, d: Float, mat: PhysicallyBasedMaterial) -> ModelEntity {
        let thickness: Float = max(h, 0.012)
        return ModelEntity(mesh: .generateBox(width: w, height: thickness, depth: d, cornerRadius: 0.005), materials: [mat])
    }

    private func makeLamp(w: Float, h: Float, d: Float,
                          mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root   = ModelEntity()
        let baseH  = h * 0.06
        let baseW  = w * 0.55
        let poleW  = w * 0.10
        let poleH  = h * 0.72
        let shadeH = h * 0.22
        let shadeW = w

        let base  = ModelEntity(mesh: .generateBox(width: baseW, height: baseH, depth: baseW, cornerRadius: 0.02), materials: [darkMat])
        base.position = [0, baseH / 2, 0]
        let pole  = ModelEntity(mesh: .generateBox(width: poleW, height: poleH, depth: poleW, cornerRadius: 0.005), materials: [darkMat])
        pole.position = [0, baseH + poleH / 2, 0]
        let shade = ModelEntity(mesh: .generateBox(width: shadeW, height: shadeH, depth: shadeW * 0.85, cornerRadius: 0.03), materials: [mat])
        shade.position = [0, baseH + poleH + shadeH / 2, 0]
        [base, pole, shade].forEach { root.addChild($0) }
        return root
    }

    private func makePlant(w: Float, h: Float, d: Float,
                           mat: PhysicallyBasedMaterial, darkMat: PhysicallyBasedMaterial) -> ModelEntity {
        let root = ModelEntity()
        let potH = h * 0.38
        let potW = w * 0.75

        var potMat = PhysicallyBasedMaterial()
        potMat.baseColor = .init(tint: UIColor(red: 0.72, green: 0.38, blue: 0.22, alpha: 1))
        potMat.roughness = .init(floatLiteral: 0.9)

        let pot = ModelEntity(mesh: .generateBox(width: potW, height: potH, depth: potW, cornerRadius: 0.04), materials: [potMat])
        pot.position = [0, potH / 2, 0]
        let foliageH = h - potH
        let foliage = ModelEntity(mesh: .generateBox(width: w, height: foliageH, depth: w, cornerRadius: min(w, foliageH) * 0.45), materials: [mat])
        foliage.position = [0, potH + foliageH / 2, 0]
        [pot, foliage].forEach { root.addChild($0) }
        return root
    }

    // MARK: - Undo / Reset

    func undoLastPlacement() {
        guard let last = undoStack.last else { return }
        arView?.scene.removeAnchor(last.anchor)
        if let label = last.label { arView?.scene.removeAnchor(label) }
        undoStack.removeLast()
        placedItems.removeAll { $0.id == last.item.id }
        canUndo = !undoStack.isEmpty
        AnalyticsService.shared.track(.furnitureRemoved)
        LumaHaptics.impact(.medium)
    }

    func undoAll() {
        for entry in undoStack {
            arView?.scene.removeAnchor(entry.anchor)
            if let label = entry.label { arView?.scene.removeAnchor(label) }
        }
        undoStack.removeAll()
        placedItems.removeAll()
        canUndo = false
        LumaHaptics.impact(.heavy)
    }

    func saveLayout() {
        guard !placedItems.isEmpty else { return }
        let store = ProjectStore.shared
        if var project = store.projects.first {
            if !project.rooms.isEmpty {
                project.rooms[0].furnitureItems = placedItems
            } else {
                let room = Room(
                    name: "AR Layout",
                    type: .livingRoom,
                    dimensions: RoomDimensions(width: 4.8, length: 6.2, ceilingHeight: 2.7),
                    scanDate: .now, score: 0, issues: [], furnitureItems: placedItems
                )
                project.rooms.append(room)
            }
            store.update(project)
        }
        AnalyticsService.shared.track(.layoutSaved, properties: ["item_count": placedItems.count])
        LumaHaptics.notification(.success)
    }

    func reset() {
        for entry in undoStack {
            arView?.scene.removeAnchor(entry.anchor)
            if let label = entry.label { arView?.scene.removeAnchor(label) }
        }
        undoStack.removeAll()
        placedItems.removeAll()
        canUndo = false
        fitWarning = nil
        LumaHaptics.impact(.heavy)
    }

    // MARK: - Fit Warning

    private func checkFitWarning(for item: FurnitureItem) {
        let room = ProjectStore.shared.projects.flatMap(\.rooms).first
        let noMotion = UIAccessibility.isReduceMotionEnabled

        Task { @MainActor in
            if let room {
                if let result = try? await AIDesignService.shared.checkFit(item: item, room: room) {
                    if result.warningLevel != "none" {
                        withAnimation(noMotion ? .none : .lumaSpring) { fitWarning = result.message }
                        try? await Task.sleep(for: .seconds(5))
                        withAnimation(noMotion ? .none : .lumaFast) { fitWarning = nil }
                    }
                    return
                }
            }
            let roomWidth  = room?.dimensions.width  ?? 4.0
            let roomLength = room?.dimensions.length ?? 5.0
            let placedWidths = placedItems.reduce(0.0) { $0 + $1.dimensions.width }
            let placedDepths = placedItems.reduce(0.0) { $0 + $1.dimensions.depth }
            let usedWidth = (placedWidths + item.dimensions.width) / roomWidth
            let usedDepth = (placedDepths + item.dimensions.depth) / roomLength

            if usedWidth > 0.65 || usedDepth > 0.65 {
                withAnimation(noMotion ? .none : .lumaSpring) {
                    fitWarning = "\(item.name) may leave insufficient clearance. Recommended walkway: ≥ 0.9 m."
                }
                AnalyticsService.shared.track(.fitWarningShown, properties: ["item": item.name])
                try? await Task.sleep(for: .seconds(4))
                withAnimation(noMotion ? .none : .lumaFast) { fitWarning = nil }
            }
        }
    }

    // MARK: - Measurement Label

    private func makeMeasurementLabel(for item: FurnitureItem, parent: AnchorEntity) -> AnchorEntity? {
        let label = AnchorEntity()
        let text = MeshResource.generateText(
            "\(Int(item.dimensions.width * 100))×\(Int(item.dimensions.depth * 100))cm",
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.04),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let mat = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: text, materials: [mat])
        textEntity.position = [0, Float(item.dimensions.height) + 0.05, 0]
        label.addChild(textEntity)
        parent.addChild(label)
        return label
    }
}
