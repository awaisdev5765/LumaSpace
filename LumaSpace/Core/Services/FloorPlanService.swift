import UIKit
import CoreGraphics

// MARK: - Floor Plan Service
// Generates a clean architectural-style top-down floor plan from a Room's
// dimensions and placed furniture. Designed to be readable at A4 / letter size.

final class FloorPlanService {
    static let shared = FloorPlanService()

    // MARK: - Public API

    func generateFloorPlan(for room: Room, scale: CGFloat = 60) -> UIImage {
        let padding: CGFloat = 80
        let roomW  = CGFloat(room.dimensions.width)  * scale
        let roomL  = CGFloat(room.dimensions.length) * scale
        let canvasW = roomW + padding * 2
        let canvasH = roomL + padding * 2 + 60

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasW, height: canvasH))
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            drawBackground(cgCtx, size: CGSize(width: canvasW, height: canvasH))
            let origin = CGPoint(x: padding, y: padding)

            if room.capturedWalls.isEmpty {
                // Fallback: estimated rectangle from dimensions
                drawRoomPerimeter(cgCtx, origin: origin, width: roomW, length: roomL)
            } else {
                // Real geometry from LiDAR scan
                drawRealWalls(cgCtx, walls: room.capturedWalls,
                              origin: origin, scale: scale,
                              roomW: roomW, roomL: roomL)
            }

            drawFurniture(cgCtx, items: room.furnitureItems, roomOrigin: origin, scale: scale)
            drawDimensions(cgCtx, origin: origin, width: roomW, length: roomL,
                           roomDims: room.dimensions, padding: padding)
            drawCompass(cgCtx, in: CGRect(x: canvasW - 52, y: 12, width: 40, height: 40))
            drawScaleBar(cgCtx, scale: scale, at: CGPoint(x: padding, y: canvasH - 32))
            drawRoomLabel(cgCtx, room: room,
                          rect: CGRect(x: 0, y: canvasH - 56, width: canvasW, height: 24))
        }
    }

    // MARK: - Drawing Layers

    private func drawBackground(_ ctx: CGContext, size: CGSize) {
        ctx.setFillColor(UIColor.systemBackground.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
    }

    // MARK: - Real wall geometry (from LiDAR CapturedRoom)

    private func drawRealWalls(_ ctx: CGContext,
                                walls: [CapturedWall],
                                origin: CGPoint,
                                scale: CGFloat,
                                roomW: CGFloat,
                                roomL: CGFloat) {
        // Compute bounding box so we can centre the plan
        let xs = walls.map { $0.centerX }
        let zs = walls.map { $0.centerZ }
        let minX = CGFloat(xs.min() ?? 0)
        let minZ = CGFloat(zs.min() ?? 0)

        // Light floor fill first
        ctx.setFillColor(UIColor.systemGray6.cgColor)
        ctx.fill(CGRect(x: origin.x, y: origin.y, width: roomW, height: roomL))

        // Subtle 1m grid
        ctx.setStrokeColor(UIColor.separator.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        var gx = origin.x + scale
        while gx < origin.x + roomW { ctx.move(to: CGPoint(x: gx, y: origin.y)); ctx.addLine(to: CGPoint(x: gx, y: origin.y + roomL)); ctx.strokePath(); gx += scale }
        var gz = origin.y + scale
        while gz < origin.y + roomL { ctx.move(to: CGPoint(x: origin.x, y: gz)); ctx.addLine(to: CGPoint(x: origin.x + roomW, y: gz)); ctx.strokePath(); gz += scale }
        ctx.setLineDash(phase: 0, lengths: [])

        // Draw each wall as a filled oriented rectangle
        let wallThickness: CGFloat = max(6, scale * 0.12)
        ctx.setFillColor(UIColor.label.withAlphaComponent(0.82).cgColor)

        for wall in walls {
            let cx = origin.x + (CGFloat(wall.centerX) - minX) * scale
            let cz = origin.y + (CGFloat(wall.centerZ) - minZ) * scale
            let ww = CGFloat(wall.width) * scale
            let wt = wallThickness

            ctx.saveGState()
            ctx.translateBy(x: cx, y: cz)
            ctx.rotate(by: CGFloat(wall.angle))
            ctx.fill(CGRect(x: -ww / 2, y: -wt / 2, width: ww, height: wt))
            ctx.restoreGState()
        }
    }

    // MARK: - Estimated rectangle fallback

    private func drawRoomPerimeter(_ ctx: CGContext, origin: CGPoint, width: CGFloat, length: CGFloat) {
        let wallThickness: CGFloat = 8
        let rect = CGRect(x: origin.x, y: origin.y, width: width, height: length)

        // Outer wall fill (dark)
        ctx.setFillColor(UIColor.label.withAlphaComponent(0.85).cgColor)
        ctx.fill(rect.insetBy(dx: -wallThickness, dy: -wallThickness))

        // Inner floor fill (light warm)
        ctx.setFillColor(UIColor.systemGray6.cgColor)
        ctx.fill(rect)

        // Grid lines (subtle 1m grid)
        ctx.setStrokeColor(UIColor.separator.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        // Vertical grid lines (every 60 pts = 1 m)
        var x = origin.x + 60
        while x < origin.x + width {
            ctx.move(to: CGPoint(x: x, y: origin.y))
            ctx.addLine(to: CGPoint(x: x, y: origin.y + length))
            ctx.strokePath()
            x += 60
        }
        // Horizontal grid lines
        var y = origin.y + 60
        while y < origin.y + length {
            ctx.move(to: CGPoint(x: origin.x, y: y))
            ctx.addLine(to: CGPoint(x: origin.x + width, y: y))
            ctx.strokePath()
            y += 60
        }
        ctx.setLineDash(phase: 0, lengths: [])
    }

    private func drawFurniture(_ ctx: CGContext, items: [FurnitureItem],
                               roomOrigin: CGPoint, scale: CGFloat) {
        guard !items.isEmpty else { return }

        // Lay out items in a simple grid from the top-left corner
        let margin: CGFloat = 10
        var cursor = CGPoint(x: roomOrigin.x + margin, y: roomOrigin.y + margin)
        let rowHeight = items.map { CGFloat($0.dimensions.depth) * scale }.max() ?? 40

        for item in items {
            let w = CGFloat(item.dimensions.width)  * scale
            let d = CGFloat(item.dimensions.depth)  * scale
            let itemRect = CGRect(x: cursor.x, y: cursor.y, width: w, height: d)

            // Fill
            let accentFill = UIColor(red: 0.102, green: 0.478, blue: 0.431, alpha: 0.18)
            ctx.setFillColor(accentFill.cgColor)
            ctx.addRect(itemRect)
            ctx.fillPath()

            // Border
            ctx.setStrokeColor(UIColor(red: 0.102, green: 0.478, blue: 0.431, alpha: 0.7).cgColor)
            ctx.setLineWidth(1.0)
            ctx.addRect(itemRect)
            ctx.strokePath()

            // Label
            let label = item.name as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7, weight: .medium),
                .foregroundColor: UIColor(red: 0.102, green: 0.478, blue: 0.431, alpha: 1)
            ]
            let labelSize = label.size(withAttributes: attrs)
            let labelOrigin = CGPoint(
                x: itemRect.midX - labelSize.width / 2,
                y: itemRect.midY - labelSize.height / 2
            )
            label.draw(at: labelOrigin, withAttributes: attrs)

            cursor.x += w + margin
        }
        _ = rowHeight  // used for layout logic if extended
    }

    private func drawDimensions(_ ctx: CGContext, origin: CGPoint, width: CGFloat, length: CGFloat,
                                roomDims: RoomDimensions, padding: CGFloat) {
        let tickLen: CGFloat = 6
        let offset: CGFloat  = 28
        let lineColor = UIColor.secondaryLabel.cgColor
        let textColor = UIColor.label

        ctx.setStrokeColor(lineColor)
        ctx.setLineWidth(1.0)

        // ── Width dimension (top)
        let topY = origin.y - offset
        ctx.move(to: CGPoint(x: origin.x, y: topY - tickLen))
        ctx.addLine(to: CGPoint(x: origin.x, y: topY + tickLen))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: origin.x + width, y: topY - tickLen))
        ctx.addLine(to: CGPoint(x: origin.x + width, y: topY + tickLen))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: origin.x, y: topY))
        ctx.addLine(to: CGPoint(x: origin.x + width, y: topY))
        ctx.strokePath()
        drawCentredText(roomDims.widthFormatted, at: CGPoint(x: origin.x + width / 2, y: topY - 14),
                        color: textColor, size: 11, bold: true, ctx: ctx)

        // ── Length dimension (right)
        let rightX = origin.x + width + offset
        ctx.move(to: CGPoint(x: rightX - tickLen, y: origin.y))
        ctx.addLine(to: CGPoint(x: rightX + tickLen, y: origin.y))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: rightX - tickLen, y: origin.y + length))
        ctx.addLine(to: CGPoint(x: rightX + tickLen, y: origin.y + length))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: rightX, y: origin.y))
        ctx.addLine(to: CGPoint(x: rightX, y: origin.y + length))
        ctx.strokePath()

        // Rotated length text
        ctx.saveGState()
        ctx.translateBy(x: rightX + 14, y: origin.y + length / 2)
        ctx.rotate(by: .pi / 2)
        drawCentredText(roomDims.lengthFormatted, at: .zero,
                        color: textColor, size: 11, bold: true, ctx: ctx)
        ctx.restoreGState()

        // ── Area label inside room
        let areaText = roomDims.areaFormatted
        drawCentredText(areaText,
                        at: CGPoint(x: origin.x + width / 2, y: origin.y + length / 2),
                        color: .secondaryLabel, size: 12, bold: false, ctx: ctx)
    }

    private func drawCompass(_ ctx: CGContext, in rect: CGRect) {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2 - 2
        ctx.setStrokeColor(UIColor.label.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        ctx.addEllipse(in: rect.insetBy(dx: 2, dy: 2))
        ctx.strokePath()

        // North arrow
        ctx.setFillColor(UIColor.label.withAlphaComponent(0.7).cgColor)
        ctx.move(to: CGPoint(x: centre.x, y: centre.y - r))
        ctx.addLine(to: CGPoint(x: centre.x - 4, y: centre.y))
        ctx.addLine(to: CGPoint(x: centre.x + 4, y: centre.y))
        ctx.fillPath()

        drawCentredText("N", at: CGPoint(x: centre.x, y: centre.y - r - 10),
                        color: .secondaryLabel, size: 9, bold: true, ctx: ctx)
    }

    private func drawScaleBar(_ ctx: CGContext, scale: CGFloat, at origin: CGPoint) {
        // Draw a 2m scale bar
        let barW = scale * 2
        let barH: CGFloat = 4
        let segments = 2
        for i in 0..<segments {
            let fill: UIColor = i.isMultiple(of: 2) ? .label : .systemGray3
            ctx.setFillColor(fill.withAlphaComponent(0.7).cgColor)
            ctx.fill(CGRect(x: origin.x + CGFloat(i) * (barW / CGFloat(segments)),
                            y: origin.y, width: barW / CGFloat(segments), height: barH))
        }
        drawCentredText("2 m", at: CGPoint(x: origin.x + barW / 2, y: origin.y + 10),
                        color: .secondaryLabel, size: 9, bold: false, ctx: ctx)
    }

    private func drawRoomLabel(_ ctx: CGContext, room: Room, rect: CGRect) {
        let text = "\(room.name)  ·  \(room.type.rawValue)  ·  \(room.dimensions.areaFormatted)"
        drawCentredText(text, at: CGPoint(x: rect.midX, y: rect.midY),
                        color: .secondaryLabel, size: 11, bold: false, ctx: ctx)
    }

    // MARK: - Helpers

    private func drawCentredText(_ text: String, at point: CGPoint,
                                 color: UIColor, size: CGFloat, bold: Bool,
                                 ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bold ? UIFont.systemFont(ofSize: size, weight: .semibold)
                        : UIFont.systemFont(ofSize: size, weight: .regular),
            .foregroundColor: color
        ]
        let ns = text as NSString
        let sz = ns.size(withAttributes: attrs)
        ns.draw(at: CGPoint(x: point.x - sz.width / 2, y: point.y - sz.height / 2),
                withAttributes: attrs)
    }
}
