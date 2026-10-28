import PDFKit
import UIKit
import SwiftUI

final class PDFExportService {
    static let shared = PDFExportService()

    func exportProject(_ project: Project, watermark: Bool = false) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)     // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            // MARK: Cover Page
            ctx.beginPage()
            drawCoverPage(project: project, in: pageRect)
            if watermark { drawWatermark(in: pageRect) }

            // MARK: Floor Plan Pages
            for room in project.rooms {
                ctx.beginPage()
                drawFloorPlanPage(room: room, in: pageRect)
                if watermark { drawWatermark(in: pageRect) }
            }

            // MARK: Room Analysis Pages
            for room in project.rooms {
                ctx.beginPage()
                drawRoomPage(room: room, in: pageRect)
                if watermark { drawWatermark(in: pageRect) }
            }

            // MARK: Design Concepts Page
            if !project.designs.isEmpty {
                ctx.beginPage()
                drawDesignsPage(designs: project.designs, in: pageRect)
                if watermark { drawWatermark(in: pageRect) }
            }

            // MARK: Budget Page
            if let budget = project.budget {
                ctx.beginPage()
                drawBudgetPage(budget: budget, in: pageRect)
                if watermark { drawWatermark(in: pageRect) }
            }
        }
    }

    private func drawWatermark(in rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: -.pi / 5)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 52, weight: .bold),
            .foregroundColor: UIColor(red: 0.102, green: 0.478, blue: 0.431, alpha: 0.08)
        ]
        let text = "LumaSpace Free" as NSString
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
        ctx.restoreGState()
    }

    // MARK: - Cover Page

    private func drawCoverPage(project: Project, in rect: CGRect) {
        // Teal header band
        UIColor(Color.Luma.accent).setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: rect.width, height: 200)).fill()

        // App logo area
        let logoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        "LumaSpace".draw(at: CGPoint(x: 48, y: 80), withAttributes: logoAttrs)

        let tagAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        "Interior Design Report".draw(at: CGPoint(x: 48, y: 116), withAttributes: tagAttrs)

        // Project name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        project.name.draw(at: CGPoint(x: 48, y: 240), withAttributes: nameAttrs)

        // Meta info
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let dateStr = project.createdAt.formatted(date: .long, time: .omitted)
        "Created \(dateStr)".draw(at: CGPoint(x: 48, y: 288), withAttributes: metaAttrs)
        "\(project.roomCount) room\(project.roomCount == 1 ? "" : "s")  ·  \(String(format: "%.0f m² total area", project.totalArea))".draw(at: CGPoint(x: 48, y: 308), withAttributes: metaAttrs)

        // Room list
        var y: CGFloat = 380
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        "Rooms".draw(at: CGPoint(x: 48, y: y), withAttributes: sectionAttrs)
        y += 28

        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.secondaryLabel
        ]
        for room in project.rooms {
            "•  \(room.name)  (\(room.dimensions.areaFormatted))".draw(at: CGPoint(x: 64, y: y), withAttributes: rowAttrs)
            y += 22
        }

        // Footer
        drawFooter(pageNumber: 1, in: rect)
    }

    // MARK: - Floor Plan Page

    private func drawFloorPlanPage(room: Room, in rect: CGRect) {
        drawPageHeader("Floor Plan: \(room.name)", in: rect)

        let scale: CGFloat = min(
            (rect.width  - 96) / CGFloat(room.dimensions.width),
            (rect.height - 180) / CGFloat(room.dimensions.length)
        )
        let planImage = FloorPlanService.shared.generateFloorPlan(for: room, scale: scale)
        let planW = planImage.size.width
        let planH = planImage.size.height
        let planX = (rect.width - planW) / 2
        let planY: CGFloat = 80
        planImage.draw(in: CGRect(x: planX, y: planY, width: planW, height: planH))

        drawFooter(pageNumber: 0, in: rect)
    }

    // MARK: - Room Page

    private func drawRoomPage(room: Room, in rect: CGRect) {
        drawPageHeader("Room Analysis: \(room.name)", in: rect)

        var y: CGFloat = 100

        // Dimensions table
        let pairs: [(String, String)] = [
            ("Width",          room.dimensions.widthFormatted),
            ("Length",         room.dimensions.lengthFormatted),
            ("Area",           room.dimensions.areaFormatted),
            ("Ceiling Height", String(format: "%.1f m", room.dimensions.ceilingHeight)),
            ("Room Type",      room.type.rawValue),
            ("Room Score",     "\(room.score) / 100")
        ]

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.label
        ]

        for (label, value) in pairs {
            UIColor.systemGray5.setFill()
            UIBezierPath(roundedRect: CGRect(x: 48, y: y, width: 516, height: 28), cornerRadius: 6).fill()
            label.draw(at: CGPoint(x: 60, y: y + 7), withAttributes: labelAttrs)
            value.draw(at: CGPoint(x: 300, y: y + 7), withAttributes: valueAttrs)
            y += 34
        }

        y += 24

        // Issues
        if !room.issues.isEmpty {
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            "Issues & Recommendations".draw(at: CGPoint(x: 48, y: y), withAttributes: sectionAttrs)
            y += 28

            for issue in room.issues {
                let issueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor(issue.severity.color)
                ]
                issue.title.draw(at: CGPoint(x: 48, y: y), withAttributes: issueAttrs)
                y += 18
                let suggAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let suggRect = CGRect(x: 60, y: y, width: 490, height: 40)
                issue.suggestion.draw(in: suggRect, withAttributes: suggAttrs)
                y += 44
            }
        }

        drawFooter(pageNumber: 2, in: rect)
    }

    // MARK: - Designs Page

    private func drawDesignsPage(designs: [DesignConcept], in rect: CGRect) {
        drawPageHeader("Design Concepts", in: rect)
        var y: CGFloat = 100

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let descAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let costAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor(Color.Luma.accent)
        ]

        for design in designs.prefix(4) {
            UIColor.systemGray6.setFill()
            UIBezierPath(roundedRect: CGRect(x: 48, y: y, width: 516, height: 90), cornerRadius: 10).fill()

            let colorRect = CGRect(x: 48, y: y, width: 8, height: 90)
            let palette = design.style.palette
            if let first = palette.first { UIColor(first).setFill() }
            UIBezierPath(roundedRect: colorRect, cornerRadius: 4).fill()

            "\(design.style.emoji)  \(design.title)".draw(at: CGPoint(x: 68, y: y + 12), withAttributes: titleAttrs)

            let descRect = CGRect(x: 68, y: y + 32, width: 380, height: 36)
            design.description.draw(in: descRect, withAttributes: descAttrs)

            "Est. $\(Int(design.estimatedCost).formatted())".draw(at: CGPoint(x: 440, y: y + 12), withAttributes: costAttrs)

            y += 104
        }

        drawFooter(pageNumber: 3, in: rect)
    }

    // MARK: - Budget Page

    private func drawBudgetPage(budget: BudgetPlan, in rect: CGRect) {
        drawPageHeader("Budget Plan", in: rect)
        var y: CGFloat = 100

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.secondaryLabel
        ]

        "Total: $\(Int(budget.total).formatted())".draw(at: CGPoint(x: 48, y: y), withAttributes: headerAttrs)
        y += 32
        "Estimated: $\(Int(budget.spent).formatted())   ·   Remaining: $\(Int(budget.remaining).formatted())"
            .draw(at: CGPoint(x: 48, y: y), withAttributes: subAttrs)
        y += 40

        for item in budget.items {
            UIColor.systemGray5.setFill()
            UIBezierPath(roundedRect: CGRect(x: 48, y: y, width: 516, height: 32), cornerRadius: 6).fill()

            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            let priceAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            item.name.draw(at: CGPoint(x: 60, y: y + 9), withAttributes: rowAttrs)
            item.priority.rawValue.capitalized.draw(at: CGPoint(x: 280, y: y + 9), withAttributes: rowAttrs)
            "$\(Int(item.estimatedCost).formatted())".draw(at: CGPoint(x: 490, y: y + 9), withAttributes: priceAttrs)
            y += 38
        }

        drawFooter(pageNumber: 4, in: rect)
    }

    // MARK: - Helpers

    private func drawPageHeader(_ title: String, in rect: CGRect) {
        UIColor(Color.Luma.accent).setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: rect.width, height: 60)).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        title.draw(at: CGPoint(x: 48, y: 18), withAttributes: attrs)
    }

    private func drawFooter(pageNumber: Int, in rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        "Generated by LumaSpace  ·  Page \(pageNumber)".draw(
            at: CGPoint(x: 48, y: rect.height - 36),
            withAttributes: attrs
        )
        UIColor.separator.setFill()
        UIBezierPath(rect: CGRect(x: 48, y: rect.height - 48, width: 516, height: 0.5)).fill()
    }

    // Async wrapper — renders on a background thread so the main thread stays free
    func exportProjectAsync(_ project: Project, watermark: Bool = false) async -> Data {
        await Task.detached(priority: .userInitiated) {
            PDFExportService.shared.exportProject(project, watermark: watermark)
        }.value
    }

    // MARK: - Share / Save

    @MainActor
    func shareAsync(_ project: Project) async {
        let watermark = StoreService.shared.currentTier.watermarksExports
        let data = await exportProjectAsync(project, watermark: watermark)
        guard let url = saveToTemp(data: data) else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }

    func share(_ data: Data, from viewController: UIViewController?) {
        guard let url = saveToTemp(data: data) else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController?.present(vc, animated: true)
    }

    private func saveToTemp(data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumaSpace_Report_\(Date().timeIntervalSince1970).pdf")
        try? data.write(to: url)
        return url
    }
}
