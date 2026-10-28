import SwiftUI

// MARK: - Room Builder (2D Floor Plan Editor)
// Works on ALL iPhones — no LiDAR required.
// Users draw room outlines by tapping, add doors/windows on wall segments,
// and place furniture from the catalog. The completed layout exports as a Room.

struct RoomBuilderView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var projectStore = ProjectStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Canvas state
    @State private var vertices: [CGPoint] = []
    @State private var isRoomClosed = false
    @State private var placedFurniture: [PlacedFurnitureItem] = []
    @State private var wallOpenings: [WallOpening] = []
    @State private var selectedVertexID: UUID?
    @State private var selectedFurnitureID: UUID?
    @State private var activeTool: BuilderTool = .draw
    @State private var scale: CGFloat = 60  // pixels per meter

    // Room metadata
    @State private var roomType: Room.RoomType = .livingRoom
    @State private var roomName = "My Room"
    @State private var saveTargetProjectID: UUID?

    // UI state
    @State private var showTemplates = false
    @State private var showFurniturePicker = false
    @State private var showSaveConfirm = false
    @State private var showHelp = false
    @State private var dragOffset: CGSize = .zero
    @State private var canvasOffset: CGSize = .zero

    // Computed
    private var canvasSize: CGSize { CGSize(width: 900, height: 900) }
    private let snapThreshold: CGFloat = 18
    private let minRoomVertices = 3

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    toolPicker
                    Divider()
                    canvas
                    Divider()
                    bottomBar
                }
            }
            .navigationTitle("Room Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showTemplates) {
            RoomTemplatePickerView { template in
                applyTemplate(template)
                showTemplates = false
            }
        }
        .sheet(isPresented: $showFurniturePicker) {
            CatalogPickerSheet { product in
                placeFurnitureFromCatalog(product)
                showFurniturePicker = false
            }
        }
        .alert("Name Your Room", isPresented: $showSaveConfirm) {
            TextField("Room name", text: $roomName)
            Picker("Type", selection: $roomType) {
                ForEach(Room.RoomType.allCases, id: \.self) {
                    Label($0.rawValue, systemImage: $0.icon).tag($0)
                }
            }
            if projectStore.projects.count > 1 {
                Picker("Project", selection: $saveTargetProjectID) {
                    ForEach(projectStore.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
            }
            Button("Save Room") { saveRoom() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if projectStore.projects.count > 1 {
                Text("Choose which project this room belongs to.")
            } else {
                Text("This floor plan will be saved to your project.")
            }
        }
        .onAppear {
            saveTargetProjectID = projectStore.projects.first?.id
        }
        .sheet(isPresented: $showHelp) { BuilderHelpView() }
    }

    // MARK: - Tool Picker

    private var toolPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumaSpacing.xs) {
                ForEach(BuilderTool.allCases, id: \.self) { tool in
                    Button {
                        withAnimation(reduceMotion ? .none : .lumaFast) { activeTool = tool }
                        LumaHaptics.selection()
                    } label: {
                        VStack(spacing: LumaSpacing.xs) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 18, weight: .medium))
                            Text(tool.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(activeTool == tool ? .white : Color.Luma.accent)
                        .frame(width: 64, height: 54)
                        .background(activeTool == tool ? Color.Luma.accent : Color.Luma.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, LumaSpacing.sm)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                // Grid background
                Canvas { ctx, size in
                    drawGrid(ctx: ctx, size: size)
                }
                .allowsHitTesting(false)

                // Room polygon
                Canvas { ctx, size in
                    drawRoom(ctx: ctx)
                }
                .allowsHitTesting(false)

                // Wall openings
                Canvas { ctx, size in
                    drawOpenings(ctx: ctx)
                }
                .allowsHitTesting(false)

                // Placed furniture
                ForEach($placedFurniture) { $item in
                    FurnitureItemView(
                        item: $item,
                        isSelected: item.id == selectedFurnitureID,
                        activeTool: activeTool
                    ) {
                        if activeTool == .select {
                            selectedFurnitureID = item.id == selectedFurnitureID ? nil : item.id
                            LumaHaptics.selection()
                        } else if activeTool == .erase {
                            placedFurniture.removeAll { $0.id == item.id }
                            LumaHaptics.notification(.success)
                        }
                    }
                }

                // Vertices (interactive)
                ForEach(vertices.indices, id: \.self) { i in
                    vertexHandle(index: i)
                }

                // Vertex preview while drawing
                if activeTool == .draw && !vertices.isEmpty && !isRoomClosed {
                    let last = vertices[vertices.count - 1]
                    Circle()
                        .fill(Color.Luma.accent.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .position(last)
                        .allowsHitTesting(false)
                }

                // Dimension overlay
                if isRoomClosed {
                    ForEach(0..<vertices.count, id: \.self) { i in
                        wallDimensionLabel(index: i)
                    }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .offset(canvasOffset)
            .gesture(canvasTapGesture(in: geo))
            .gesture(canvasDragGesture)
            .clipped()
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: LumaSpacing.md) {
            // Undo
            Button {
                undo()
                LumaHaptics.impact(.light)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(vertices.isEmpty && placedFurniture.isEmpty ? .tertiary : .primary)
            .disabled(vertices.isEmpty && placedFurniture.isEmpty)

            Spacer()

            // Status label
            statusLabel

            Spacer()

            // Action button (context-sensitive)
            actionButton
        }
        .padding(.horizontal, LumaSpacing.base)
        .padding(.vertical, LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var statusLabel: some View {
        VStack(spacing: 2) {
            if !isRoomClosed && activeTool == .draw {
                Text(vertices.isEmpty ? "Tap to start drawing" : "Tap corners to draw room")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.primary)
                if vertices.count >= minRoomVertices {
                    Text("Tap first point to close")
                        .font(LumaFont.caption2)
                        .foregroundStyle(Color.Luma.accent)
                }
            } else if isRoomClosed {
                Text(roomAreaDescription)
                    .font(LumaFont.caption1)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(roomType.rawValue)
                    .font(LumaFont.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(activeTool.hint)
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var actionButton: some View {
        Group {
            if isRoomClosed {
                Button {
                    showSaveConfirm = true
                    LumaHaptics.notification(.success)
                } label: {
                    Label("Save Room", systemImage: "square.and.arrow.down")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, LumaSpacing.base)
                        .frame(height: 44)
                        .background(Color.Luma.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else if activeTool == .furniture {
                Button {
                    showFurniturePicker = true
                    LumaHaptics.impact(.medium)
                } label: {
                    Label("Add Item", systemImage: "plus")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, LumaSpacing.base)
                        .frame(height: 44)
                        .background(Color.Luma.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: LumaSpacing.md) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }

                Button {
                    showTemplates = true
                    LumaHaptics.impact(.light)
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .accessibilityLabel("Room Templates")
            }
        }
    }

    // MARK: - Canvas Drawing

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let step: CGFloat = scale * 0.5  // 0.5m grid lines
        let major: CGFloat = scale        // 1m major lines

        let minorStyle = ctx.resolve(Image(systemName: "circle.fill"))  // placeholder
        _ = minorStyle

        for x in stride(from: CGFloat(0), through: size.width, by: step) {
            let isMajor = (x / major).truncatingRemainder(dividingBy: 1) < 0.01
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(path, with: .color(.gray.opacity(isMajor ? 0.15 : 0.06)), lineWidth: isMajor ? 0.8 : 0.4)
        }
        for y in stride(from: CGFloat(0), through: size.height, by: step) {
            let isMajor = (y / major).truncatingRemainder(dividingBy: 1) < 0.01
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(path, with: .color(.gray.opacity(isMajor ? 0.15 : 0.06)), lineWidth: isMajor ? 0.8 : 0.4)
        }
    }

    private func drawRoom(ctx: GraphicsContext) {
        guard vertices.count >= 2 else {
            // Draw individual points
            for v in vertices {
                let r: CGFloat = 5
                ctx.fill(Path(ellipseIn: CGRect(x: v.x - r, y: v.y - r, width: r*2, height: r*2)),
                         with: .color(Color.Luma.accent))
            }
            return
        }

        var path = Path()
        path.move(to: vertices[0])
        for v in vertices.dropFirst() { path.addLine(to: v) }
        if isRoomClosed { path.closeSubpath() }

        // Fill
        if isRoomClosed {
            ctx.fill(path, with: .color(Color.Luma.accent.opacity(0.06)))
        }

        // Walls
        ctx.stroke(path, with: .color(Color.Luma.accent.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        // Vertex dots
        for (i, v) in vertices.enumerated() {
            let isFirst = i == 0
            let r: CGFloat = isFirst && !isRoomClosed ? 9 : 6
            let color: Color = isFirst && !isRoomClosed && vertices.count >= minRoomVertices
                ? Color.green
                : Color.Luma.accent
            ctx.fill(Path(ellipseIn: CGRect(x: v.x - r, y: v.y - r, width: r*2, height: r*2)),
                     with: .color(color))
            ctx.stroke(Path(ellipseIn: CGRect(x: v.x - r, y: v.y - r, width: r*2, height: r*2)),
                       with: .color(.white), lineWidth: 2)
        }
    }

    private func drawOpenings(ctx: GraphicsContext) {
        for opening in wallOpenings {
            guard opening.wallIndex < vertices.count else { continue }
            let start = vertices[opening.wallIndex]
            let end = vertices[(opening.wallIndex + 1) % vertices.count]
            let p = CGPoint(
                x: start.x + (end.x - start.x) * opening.t,
                y: start.y + (end.y - start.y) * opening.t
            )
            let widthPx = CGFloat(opening.widthMeters) * scale
            let wallAngle = atan2(end.y - start.y, end.x - start.x)
            let perp = wallAngle + .pi / 2

            let p1 = CGPoint(x: p.x - cos(wallAngle) * widthPx / 2, y: p.y - sin(wallAngle) * widthPx / 2)
            let p2 = CGPoint(x: p.x + cos(wallAngle) * widthPx / 2, y: p.y + sin(wallAngle) * widthPx / 2)

            if opening.type == .door {
                // Door arc
                var arcPath = Path()
                arcPath.move(to: p1)
                arcPath.addArc(center: p1, radius: widthPx,
                               startAngle: .radians(Double(wallAngle)),
                               endAngle: .radians(Double(perp)), clockwise: false)
                ctx.stroke(arcPath, with: .color(.blue.opacity(0.7)), lineWidth: 1.5)
                var doorPath = Path()
                doorPath.move(to: p1)
                doorPath.addLine(to: p2)
                ctx.stroke(doorPath, with: .color(Color(uiColor: .systemBackground)), lineWidth: 5)
                ctx.stroke(doorPath, with: .color(.blue.opacity(0.7)), lineWidth: 2)
            } else {
                // Window: double line
                let offset: CGFloat = 4
                var wPath1 = Path()
                wPath1.move(to: CGPoint(x: p1.x + cos(perp) * offset, y: p1.y + sin(perp) * offset))
                wPath1.addLine(to: CGPoint(x: p2.x + cos(perp) * offset, y: p2.y + sin(perp) * offset))
                var wPath2 = Path()
                wPath2.move(to: CGPoint(x: p1.x - cos(perp) * offset, y: p1.y - sin(perp) * offset))
                wPath2.addLine(to: CGPoint(x: p2.x - cos(perp) * offset, y: p2.y - sin(perp) * offset))
                ctx.stroke(wPath1, with: .color(Color(uiColor: .systemBackground)), lineWidth: 5)
                ctx.stroke(wPath1, with: .color(.cyan.opacity(0.8)), lineWidth: 1.5)
                ctx.stroke(wPath2, with: .color(Color(uiColor: .systemBackground)), lineWidth: 5)
                ctx.stroke(wPath2, with: .color(.cyan.opacity(0.8)), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Vertex Handle

    private func vertexHandle(index: Int) -> some View {
        let v = vertices[index]
        return Circle()
            .fill(Color.clear)
            .frame(width: 36, height: 36)
            .position(x: v.x + canvasOffset.width, y: v.y + canvasOffset.height)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard activeTool == .select else { return }
                        let newPos = CGPoint(
                            x: value.location.x - canvasOffset.width,
                            y: value.location.y - canvasOffset.height
                        )
                        vertices[index] = snapToGrid(newPos)
                    }
                    .onEnded { _ in LumaHaptics.impact(.light) }
            )
    }

    // MARK: - Dimension Label

    private func wallDimensionLabel(index: Int) -> some View {
        let start = vertices[index]
        let end = vertices[(index + 1) % vertices.count]
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x, dy = end.y - start.y
        let lengthPx = sqrt(dx * dx + dy * dy)
        let lengthM = Double(lengthPx / scale)
        let angle = atan2(Double(dy), Double(dx))
        let perpOffset: CGFloat = 16
        let offset = CGPoint(x: -sin(CGFloat(angle)) * perpOffset, y: cos(CGFloat(angle)) * perpOffset)

        return Text(String(format: "%.1fm", lengthM))
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.Luma.accent)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(uiColor: .systemBackground).opacity(0.85))
            .clipShape(Capsule())
            .position(
                x: mid.x + offset.x + canvasOffset.width,
                y: mid.y + offset.y + canvasOffset.height
            )
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private func canvasTapGesture(in geo: GeometryProxy) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let pt = CGPoint(
                    x: value.location.x - canvasOffset.width,
                    y: value.location.y - canvasOffset.height
                )
                handleTap(at: pt)
            }
    }

    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard activeTool == .pan else { return }
                canvasOffset = CGSize(
                    width: canvasOffset.width + value.translation.width - dragOffset.width,
                    height: canvasOffset.height + value.translation.height - dragOffset.height
                )
                dragOffset = value.translation
            }
            .onEnded { _ in dragOffset = .zero }
    }

    private func handleTap(at point: CGPoint) {
        let snapped = snapToGrid(point)

        switch activeTool {
        case .draw:
            if isRoomClosed { return }
            if !vertices.isEmpty, vertices.count >= minRoomVertices {
                let distToFirst = distance(snapped, vertices[0])
                if distToFirst < snapThreshold {
                    withAnimation(reduceMotion ? .none : .lumaFast) { isRoomClosed = true }
                    LumaHaptics.notification(.success)
                    return
                }
            }
            vertices.append(snapped)
            LumaHaptics.impact(.light)

        case .door:
            if !isRoomClosed { return }
            if let wall = nearestWall(to: point) {
                wallOpenings.append(WallOpening(wallIndex: wall.index, t: wall.t, type: .door, widthMeters: 0.9))
                LumaHaptics.impact(.medium)
            }

        case .window:
            if !isRoomClosed { return }
            if let wall = nearestWall(to: point) {
                wallOpenings.append(WallOpening(wallIndex: wall.index, t: wall.t, type: .window, widthMeters: 1.2))
                LumaHaptics.impact(.medium)
            }

        case .erase:
            // Remove nearest vertex or opening
            if let idx = nearestVertex(to: point, threshold: 20) {
                vertices.remove(at: idx)
                if vertices.count < minRoomVertices { isRoomClosed = false }
                LumaHaptics.impact(.light)
            } else if let idx = nearestOpening(to: point) {
                wallOpenings.remove(at: idx)
                LumaHaptics.impact(.light)
            }

        case .select:
            selectedFurnitureID = nil
            selectedVertexID = nil

        case .pan, .furniture:
            break
        }
    }

    // MARK: - Helpers

    private func snapToGrid(_ point: CGPoint) -> CGPoint {
        let step = scale * 0.5 / 2  // snap to 0.25m grid
        return CGPoint(
            x: round(point.x / step) * step,
            y: round(point.y / step) * step
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return sqrt(dx*dx + dy*dy)
    }

    private func nearestVertex(to point: CGPoint, threshold: CGFloat) -> Int? {
        for (i, v) in vertices.enumerated() {
            if distance(point, v) < threshold { return i }
        }
        return nil
    }

    private func nearestWall(to point: CGPoint) -> (index: Int, t: Double)? {
        guard isRoomClosed, vertices.count >= 3 else { return nil }
        var best: (index: Int, t: Double, dist: CGFloat)?
        for i in 0..<vertices.count {
            let start = vertices[i]
            let end = vertices[(i + 1) % vertices.count]
            let (t, d) = pointToSegmentDistance(point, start, end)
            if d < 30 {
                if best == nil || d < best!.dist {
                    best = (i, t, d)
                }
            }
        }
        return best.map { (index: $0.index, t: $0.t) }
    }

    private func nearestOpening(to point: CGPoint) -> Int? {
        for (i, opening) in wallOpenings.enumerated() {
            guard opening.wallIndex < vertices.count else { continue }
            let start = vertices[opening.wallIndex]
            let end = vertices[(opening.wallIndex + 1) % vertices.count]
            let p = CGPoint(
                x: start.x + (end.x - start.x) * opening.t,
                y: start.y + (end.y - start.y) * opening.t
            )
            if distance(point, p) < 20 { return i }
        }
        return nil
    }

    private func pointToSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> (t: Double, dist: CGFloat) {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let len2 = ab.x * ab.x + ab.y * ab.y
        guard len2 > 0 else { return (0, distance(p, a)) }
        let t = max(0, min(1, Double((ap.x * ab.x + ap.y * ab.y) / len2)))
        let proj = CGPoint(x: a.x + CGFloat(t) * ab.x, y: a.y + CGFloat(t) * ab.y)
        return (t, distance(p, proj))
    }

    private var roomAreaDescription: String {
        guard isRoomClosed, vertices.count >= 3 else { return "" }
        let areaPx = polygonArea(vertices)
        let areaM2 = Double(areaPx) / Double(scale * scale)
        return String(format: "%.1f m² · approx %.0f × %.0f m", areaM2, sqrt(areaM2), sqrt(areaM2))
    }

    private func polygonArea(_ pts: [CGPoint]) -> CGFloat {
        var area: CGFloat = 0
        let n = pts.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += pts[i].x * pts[j].y
            area -= pts[j].x * pts[i].y
        }
        return abs(area) / 2
    }

    private func undo() {
        if !placedFurniture.isEmpty {
            placedFurniture.removeLast()
        } else if !wallOpenings.isEmpty {
            wallOpenings.removeLast()
        } else if isRoomClosed {
            isRoomClosed = false
        } else if !vertices.isEmpty {
            vertices.removeLast()
        }
        LumaHaptics.impact(.light)
    }

    private func applyTemplate(_ template: RoomTemplate) {
        vertices = template.vertices(scale: scale)
        isRoomClosed = true
        placedFurniture = []
        wallOpenings = []
        roomType = template.roomType
        roomName = template.name
        LumaHaptics.notification(.success)
    }

    private func placeFurnitureFromCatalog(_ product: CatalogProduct) {
        let center = CGPoint(
            x: canvasSize.width / 2 - canvasOffset.width,
            y: canvasSize.height / 2 - canvasOffset.height
        )
        placedFurniture.append(PlacedFurnitureItem(
            product: product,
            position: snapToGrid(center),
            widthPx: CGFloat(product.dimensions.width) * scale,
            depthPx: CGFloat(product.dimensions.depth) * scale
        ))
        LumaHaptics.notification(.success)
    }

    private func saveRoom() {
        guard isRoomClosed, vertices.count >= 3 else { return }
        let areaPx = polygonArea(vertices)
        let areaM2 = Double(areaPx) / Double(scale * scale)
        let side = sqrt(areaM2)
        let dimensions = RoomDimensions(width: side, length: side, ceilingHeight: 2.7)

        let furniture = placedFurniture.map { item in
            var fi = item.product.toFurnitureItem()
            fi.position = SIMD3<Float>(
                Float(item.position.x / scale),
                0,
                Float(item.position.y / scale)
            )
            fi.isPlaced = true
            return fi
        }

        let walls: [CapturedWall] = zip(vertices, vertices.dropFirst() + [vertices[0]]).map { start, end in
            CapturedWall(
                centerX: Float((start.x + end.x) / 2 / scale),
                centerZ: Float((start.y + end.y) / 2 / scale),
                width: Float(distance(start, end) / scale),
                height: 2.7,
                angle: Float(atan2(end.y - start.y, end.x - start.x))
            )
        }

        let room = Room(
            name: roomName,
            type: roomType,
            dimensions: dimensions,
            scanDate: .now,
            score: 75,
            issues: [],
            furnitureItems: furniture,
            capturedWalls: walls
        )

        let target = projectStore.projects.first { $0.id == saveTargetProjectID }
        var project = target ?? projectStore.projects.first ?? projectStore.create(name: "My Home")
        project.rooms.append(room)
        projectStore.update(project)

        LumaHaptics.notification(.success)
        dismiss()
    }
}

// MARK: - Furniture Item View (on canvas)

struct FurnitureItemView: View {
    @Binding var item: PlacedFurnitureItem
    var isSelected: Bool
    var activeTool: BuilderTool
    let onTap: () -> Void

    @State private var dragStart: CGSize = .zero

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.Luma.accent.opacity(isSelected ? 0.25 : 0.12))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(isSelected ? Color.Luma.accent : Color.Luma.accent.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            VStack(spacing: 2) {
                Image(systemName: item.product.category.icon)
                    .font(.system(size: min(item.widthPx, item.depthPx) * 0.3))
                    .foregroundStyle(Color.Luma.accent)
                Text(item.product.name)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.Luma.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: item.widthPx, height: item.depthPx)
        .rotationEffect(.radians(item.rotation))
        .position(item.position)
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    guard activeTool == .select else { return }
                    let px = item.position.x
                    let py = item.position.y
                    item.position = CGPoint(
                        x: px + v.translation.width - dragStart.width,
                        y: py + v.translation.height - dragStart.height
                    )
                    dragStart = v.translation
                }
                .onEnded { _ in
                    dragStart = .zero
                    LumaHaptics.impact(.light)
                }
        )
        .onTapGesture { onTap() }
    }
}

// MARK: - Supporting Types

struct PlacedFurnitureItem: Identifiable {
    var id = UUID()
    var product: CatalogProduct
    var position: CGPoint
    var rotation: Double = 0
    var widthPx: CGFloat
    var depthPx: CGFloat
}

struct WallOpening: Identifiable {
    var id = UUID()
    var wallIndex: Int
    var t: Double       // 0.0–1.0 position along the wall segment
    var type: OpeningType
    var widthMeters: Double

    enum OpeningType { case door, window }
}

enum BuilderTool: CaseIterable {
    case draw, door, window, furniture, select, erase, pan

    var icon: String {
        switch self {
        case .draw:      return "pencil.tip"
        case .door:      return "door.left.hand.open"
        case .window:    return "window.vertical.closed"
        case .furniture: return "sofa.fill"
        case .select:    return "cursorarrow"
        case .erase:     return "eraser.fill"
        case .pan:       return "hand.draw"
        }
    }

    var label: String {
        switch self {
        case .draw:      return "Draw"
        case .door:      return "Door"
        case .window:    return "Window"
        case .furniture: return "Add Item"
        case .select:    return "Select"
        case .erase:     return "Erase"
        case .pan:       return "Pan"
        }
    }

    var hint: String {
        switch self {
        case .draw:      return "Tap to add room corners"
        case .door:      return "Tap a wall to add a door"
        case .window:    return "Tap a wall to add a window"
        case .furniture: return "Tap 'Add Item' to place furniture"
        case .select:    return "Tap or drag to move items"
        case .erase:     return "Tap vertices or items to erase"
        case .pan:       return "Drag to pan the canvas"
        }
    }
}

// MARK: - Room Template

struct RoomTemplate: Identifiable {
    var id: String
    var name: String
    var roomType: Room.RoomType
    var widthMeters: Double
    var lengthMeters: Double
    var description: String

    func vertices(scale: CGFloat) -> [CGPoint] {
        let w = CGFloat(widthMeters) * scale
        let l = CGFloat(lengthMeters) * scale
        let origin = CGPoint(x: 200, y: 200)
        return [
            CGPoint(x: origin.x,     y: origin.y),
            CGPoint(x: origin.x + w, y: origin.y),
            CGPoint(x: origin.x + w, y: origin.y + l),
            CGPoint(x: origin.x,     y: origin.y + l)
        ]
    }

    static let all: [RoomTemplate] = [
        RoomTemplate(id: "small_bed", name: "Small Bedroom", roomType: .bedroom, widthMeters: 3, lengthMeters: 3.5, description: "3 × 3.5 m"),
        RoomTemplate(id: "master_bed", name: "Master Bedroom", roomType: .bedroom, widthMeters: 4, lengthMeters: 5, description: "4 × 5 m"),
        RoomTemplate(id: "living_sm", name: "Living Room", roomType: .livingRoom, widthMeters: 4.5, lengthMeters: 5.5, description: "4.5 × 5.5 m"),
        RoomTemplate(id: "living_lg", name: "Large Living Room", roomType: .livingRoom, widthMeters: 6, lengthMeters: 8, description: "6 × 8 m"),
        RoomTemplate(id: "kitchen", name: "Kitchen", roomType: .kitchen, widthMeters: 3, lengthMeters: 4, description: "3 × 4 m"),
        RoomTemplate(id: "dining", name: "Dining Room", roomType: .diningRoom, widthMeters: 3.5, lengthMeters: 4, description: "3.5 × 4 m"),
        RoomTemplate(id: "office", name: "Home Office", roomType: .homeOffice, widthMeters: 3, lengthMeters: 3.5, description: "3 × 3.5 m"),
        RoomTemplate(id: "studio", name: "Studio", roomType: .studio, widthMeters: 6, lengthMeters: 6, description: "6 × 6 m"),
        RoomTemplate(id: "nursery", name: "Nursery", roomType: .nursery, widthMeters: 3, lengthMeters: 3, description: "3 × 3 m"),
        RoomTemplate(id: "bathroom", name: "Bathroom", roomType: .bathroom, widthMeters: 2.5, lengthMeters: 3, description: "2.5 × 3 m"),
    ]
}

// MARK: - Template Picker

struct RoomTemplatePickerView: View {
    let onSelect: (RoomTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(RoomTemplate.all) { template in
                Button {
                    onSelect(template)
                    LumaHaptics.impact(.medium)
                } label: {
                    HStack(spacing: LumaSpacing.md) {
                        Image(systemName: template.roomType.icon)
                            .font(.title3)
                            .foregroundStyle(Color.Luma.accent)
                            .frame(width: 40, height: 40)
                            .background(Color.Luma.accent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(LumaFont.subhead)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(template.description)
                                .font(LumaFont.caption1)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, LumaSpacing.xs)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Room Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Catalog Picker Sheet

struct CatalogPickerSheet: View {
    let onSelect: (CatalogProduct) -> Void
    @StateObject private var catalog = FurnitureCatalogService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FurnitureItem.Category?

    var filtered: [CatalogProduct] {
        guard let cat = selectedCategory else { return catalog.allProducts }
        return catalog.allProducts.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LumaSpacing.xs) {
                        LumaChip(text: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(FurnitureItem.Category.allCases, id: \.self) { cat in
                            LumaChip(text: cat.rawValue.capitalized, isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, LumaSpacing.sm)
                }
                Divider()
                List(filtered) { product in
                    Button {
                        onSelect(product)
                    } label: {
                        HStack(spacing: LumaSpacing.md) {
                            Image(systemName: product.category.icon)
                                .font(.title3)
                                .foregroundStyle(Color.Luma.accent)
                                .frame(width: 44, height: 44)
                                .background(Color.Luma.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(LumaFont.subhead)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(product.brand) · \(Int(product.dimensions.width * 100))W × \(Int(product.dimensions.depth * 100))D cm")
                                    .font(LumaFont.caption1)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$\(Int(product.price))")
                                .font(LumaFont.subhead)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.Luma.accent)
                        }
                        .padding(.vertical, LumaSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add Furniture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Builder Help View

struct BuilderHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, title: String, detail: String)] = [
        ("pencil.tip", "Draw Room", "Select the Draw tool and tap corners to outline your room. Tap the first point to close."),
        ("door.left.hand.open", "Add Doors", "Select Door tool, then tap on any wall to place a door opening."),
        ("window.vertical.closed", "Add Windows", "Select Window tool, then tap on any wall to mark a window."),
        ("sofa.fill", "Place Furniture", "Select the Furniture tool and tap 'Add Item' to pick items from the catalog."),
        ("cursorarrow", "Move Items", "Select the Select tool to drag vertices or furniture to reposition."),
        ("square.and.arrow.down", "Save Room", "Tap 'Save Room' to add this floor plan to your project."),
    ]

    var body: some View {
        NavigationStack {
            List(steps, id: \.title) { step in
                HStack(alignment: .top, spacing: LumaSpacing.md) {
                    Image(systemName: step.icon)
                        .font(.title3)
                        .foregroundStyle(Color.Luma.accent)
                        .frame(width: 44, height: 44)
                        .background(Color.Luma.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(LumaFont.subhead)
                            .fontWeight(.semibold)
                        Text(step.detail)
                            .font(LumaFont.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, LumaSpacing.xs)
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
