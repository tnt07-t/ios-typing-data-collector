import UIKit

// MARK: - TapCoordPDFExporter
//
// Generates a PDF with:
//   Page 1  — scatter plot on a coordinate plane where (0,0) is the
//             top-left corner of the keyboard.
//   Page 2+ — table of every tap's coordinates (keyboard-relative, in points).

final class TapCoordPDFExporter {

    private let pageW:  CGFloat = 612
    private let pageH:  CGFloat = 792
    private let margin: CGFloat = 36

    func exportPDF(
        events: [InputEventData],
        session: Session,
        participant: Participant?
    ) async -> URL? {

        // Only events that have real coordinates
        let taps = events.filter { hasCoords($0) }
        guard !taps.isEmpty else { return nil }

        // Compute keyboard origin = min screen position across all keys
        let kbOriginX = taps.map { $0.keyScreenX }.min()!
        let kbOriginY = taps.map { $0.keyScreenY }.min()!

        // Each tap's position relative to keyboard top-left
        let coords: [(x: Double, y: Double, key: String, isCorrect: Bool)] = taps.map { e in
            (x: e.keyScreenX + e.tapLocalX - kbOriginX,
             y: e.keyScreenY + e.tapLocalY - kbOriginY,
             key: e.keyLabel,
             isCorrect: e.isCorrect)
        }

        // Keyboard bounding box in points (used for axis limits)
        let maxKbX = taps.map { $0.keyScreenX + $0.keyWidth  - kbOriginX }.max()!
        let maxKbY = taps.map { $0.keyScreenY + $0.keyHeight - kbOriginY }.max()!

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("tap_coords_\(session.id.uuidString).pdf")

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        let data = renderer.pdfData { ctx in
            // ── Page 1: scatter plot ─────────────────────────────────────────
            ctx.beginPage()
            let headerBottom = drawHeader(
                ctx: ctx, title: "Tap Coordinate Map",
                session: session, participant: participant, page: 1)

            drawScatterPlot(
                ctx: ctx,
                coords: coords,
                maxX: maxKbX,
                maxY: maxKbY,
                topY: headerBottom + 12)

            // ── Page 2+: coordinate table ────────────────────────────────────
            let rowH: CGFloat   = 13
            let tableTop: CGFloat = 58
            let usableH: CGFloat  = pageH - tableTop - margin
            let rowsPerPage = Int(usableH / rowH)

            var rowIndex  = 0
            var pageIndex = 2

            while rowIndex < coords.count {
                ctx.beginPage()
                drawHeader(ctx: ctx,
                           title: "Tap Coordinates — List",
                           session: session, participant: participant,
                           page: pageIndex)
                drawTableHeader(ctx: ctx, y: tableTop)
                var rowY = tableTop + rowH
                var rowsOnPage = 0
                while rowsOnPage < rowsPerPage && rowIndex < coords.count {
                    let c = coords[rowIndex]
                    drawTableRow(ctx: ctx,
                                 index: rowIndex + 1,
                                 key: c.key,
                                 x: c.x, y: c.y,
                                 isCorrect: c.isCorrect,
                                 y: rowY,
                                 shaded: rowIndex % 2 == 1)
                    rowY     += rowH
                    rowIndex += 1
                    rowsOnPage += 1
                }
                pageIndex += 1
            }
        }

        do {
            try data.write(to: url)
            return url
        } catch {
            print("TapCoordPDFExporter: \(error)")
            return nil
        }
    }

    // MARK: - Header

    @discardableResult
    private func drawHeader(
        ctx: UIGraphicsPDFRendererContext,
        title: String,
        session: Session,
        participant: Participant?,
        page: Int
    ) -> CGFloat {
        let cgCtx = ctx.cgContext
        cgCtx.setFillColor(UIColor.systemIndigo.withAlphaComponent(0.85).cgColor)
        cgCtx.fill(CGRect(x: 0, y: 0, width: pageW, height: 40))

        drawText(title,
                 at: CGPoint(x: margin, y: 10),
                 font: .systemFont(ofSize: 14, weight: .bold),
                 color: .white)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let dateStr = iso.string(from: session.startedAt)
        let name = participant.map {
            "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces)
        } ?? "—"
        drawText("Participant: \(name)   Date: \(dateStr)   Page \(page)",
                 at: CGPoint(x: margin, y: 44),
                 font: .systemFont(ofSize: 8, weight: .regular),
                 color: .secondaryLabel)

        return 56
    }

    // MARK: - Scatter Plot

    private func drawScatterPlot(
        ctx: UIGraphicsPDFRendererContext,
        coords: [(x: Double, y: Double, key: String, isCorrect: Bool)],
        maxX: Double,
        maxY: Double,
        topY: CGFloat
    ) {
        let cgCtx = ctx.cgContext

        let plotLeft:   CGFloat = margin + 48   // room for y-axis labels
        let plotRight:  CGFloat = pageW - margin - 16
        let plotBottom: CGFloat = pageH - margin - 32  // room for x-axis labels
        let plotTop:    CGFloat = topY

        let plotW = plotRight  - plotLeft
        let plotH = plotBottom - plotTop

        // Background
        cgCtx.setFillColor(UIColor.systemGray6.cgColor)
        cgCtx.fill(CGRect(x: plotLeft, y: plotTop, width: plotW, height: plotH))

        // Grid lines
        let gridCount = 5
        cgCtx.setStrokeColor(UIColor.separator.cgColor)
        cgCtx.setLineWidth(0.4)
        for i in 0...gridCount {
            let fx = CGFloat(i) / CGFloat(gridCount)
            let fy = CGFloat(i) / CGFloat(gridCount)

            // Vertical
            let gx = plotLeft + fx * plotW
            cgCtx.move(to: CGPoint(x: gx, y: plotTop))
            cgCtx.addLine(to: CGPoint(x: gx, y: plotBottom))

            // Horizontal
            let gy = plotTop + fy * plotH
            cgCtx.move(to: CGPoint(x: plotLeft, y: gy))
            cgCtx.addLine(to: CGPoint(x: plotRight, y: gy))
        }
        cgCtx.strokePath()

        // Axis tick labels — X
        for i in 0...gridCount {
            let fx = CGFloat(i) / CGFloat(gridCount)
            let val = Int((Double(i) / Double(gridCount)) * maxX)
            let gx = plotLeft + fx * plotW
            drawText("\(val)pt",
                     at: CGPoint(x: gx - 16, y: plotBottom + 4),
                     font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                     color: .secondaryLabel, width: 34)
        }

        // Axis tick labels — Y
        for i in 0...gridCount {
            let fy = CGFloat(i) / CGFloat(gridCount)
            let val = Int((Double(i) / Double(gridCount)) * maxY)
            let gy = plotTop + fy * plotH
            drawText("\(val)pt",
                     at: CGPoint(x: margin, y: gy - 5),
                     font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                     color: .secondaryLabel, width: 40)
        }

        // Axis border
        cgCtx.setStrokeColor(UIColor.label.cgColor)
        cgCtx.setLineWidth(0.8)
        cgCtx.stroke(CGRect(x: plotLeft, y: plotTop, width: plotW, height: plotH))

        // Origin label
        drawText("(0, 0)",
                 at: CGPoint(x: plotLeft + 3, y: plotTop + 3),
                 font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                 color: .tertiaryLabel, width: 40)

        // Axis titles
        drawText("x (pts from keyboard left edge)",
                 at: CGPoint(x: plotLeft + plotW/2 - 100, y: plotBottom + 18),
                 font: .systemFont(ofSize: 8, weight: .medium),
                 color: .label, width: 200)

        // Y axis title (rotated)
        cgCtx.saveGState()
        cgCtx.translateBy(x: margin - 10, y: plotTop + plotH/2)
        cgCtx.rotate(by: -.pi / 2)
        drawText("y (pts from keyboard top edge)",
                 at: CGPoint(x: -90, y: -5),
                 font: .systemFont(ofSize: 8, weight: .medium),
                 color: .label, width: 180)
        cgCtx.restoreGState()

        // Tap dots
        let dotR: CGFloat = 3.5
        for c in coords {
            guard maxX > 0, maxY > 0 else { continue }
            let px = plotLeft + CGFloat(c.x / maxX) * plotW
            let py = plotTop  + CGFloat(c.y / maxY) * plotH
            let dotRect = CGRect(x: px - dotR, y: py - dotR,
                                 width: dotR * 2, height: dotR * 2)
            cgCtx.setFillColor(keyColor(c.key).cgColor)
            cgCtx.fillEllipse(in: dotRect)
        }

        // Legend
        let legendKeys: [String] = ["q","w","e","r","t","y","u","i","o","p",
                                    "a","s","d","f","g","h","j","k","l",
                                    "z","x","c","v","b","n","m","space","delete"]
        var lx: CGFloat = plotLeft
        let ly: CGFloat = plotBottom + 30
        for k in legendKeys {
            cgCtx.setFillColor(keyColor(k).cgColor)
            cgCtx.fillEllipse(in: CGRect(x: lx, y: ly, width: 6, height: 6))
            drawText(k == "space" ? "sp" : k == "delete" ? "del" : k,
                     at: CGPoint(x: lx + 8, y: ly - 1),
                     font: .monospacedSystemFont(ofSize: 6.5, weight: .regular),
                     color: .secondaryLabel, width: 24)
            lx += 20
            if lx + 20 > plotRight { break }
        }
    }

    // MARK: - Table

    private let colX:     CGFloat = 36
    private let colKey:   CGFloat = 96
    private let colTapX:  CGFloat = 200
    private let colTapY:  CGFloat = 320
    private let colOK:    CGFloat = 440

    private func drawTableHeader(ctx: UIGraphicsPDFRendererContext, y: CGFloat) {
        let cgCtx = ctx.cgContext
        cgCtx.setFillColor(UIColor.systemIndigo.withAlphaComponent(0.15).cgColor)
        cgCtx.fill(CGRect(x: margin, y: y, width: pageW - 2*margin, height: 13))

        let hFont = UIFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        drawText("#",       at: CGPoint(x: colX,    y: y + 2), font: hFont, color: .label, width: 30)
        drawText("Key",     at: CGPoint(x: colKey,  y: y + 2), font: hFont, color: .label, width: 60)
        drawText("x (pts)", at: CGPoint(x: colTapX, y: y + 2), font: hFont, color: .label, width: 80)
        drawText("y (pts)", at: CGPoint(x: colTapY, y: y + 2), font: hFont, color: .label, width: 80)
        drawText("Correct", at: CGPoint(x: colOK,   y: y + 2), font: hFont, color: .label, width: 60)
    }

    private func drawTableRow(
        ctx: UIGraphicsPDFRendererContext,
        index: Int,
        key: String,
        x: Double, y: Double,
        isCorrect: Bool,
        y rowY: CGFloat,
        shaded: Bool
    ) {
        let cgCtx = ctx.cgContext
        if shaded {
            cgCtx.setFillColor(UIColor.systemGray6.cgColor)
            cgCtx.fill(CGRect(x: margin, y: rowY, width: pageW - 2*margin, height: 13))
        }

        let rFont  = UIFont.monospacedSystemFont(ofSize: 7.5, weight: .regular)
        let keyCol = keyColor(key).withAlphaComponent(1.0)

        drawText("\(index)",
                 at: CGPoint(x: colX,    y: rowY + 2), font: rFont, color: .secondaryLabel, width: 30)
        drawText(key,
                 at: CGPoint(x: colKey,  y: rowY + 2), font: rFont, color: keyCol, width: 60)
        drawText(String(format: "%.2f", x),
                 at: CGPoint(x: colTapX, y: rowY + 2), font: rFont, color: .label, width: 80)
        drawText(String(format: "%.2f", y),
                 at: CGPoint(x: colTapY, y: rowY + 2), font: rFont, color: .label, width: 80)
        drawText(isCorrect ? "✓" : "✗",
                 at: CGPoint(x: colOK,   y: rowY + 2), font: rFont,
                 color: isCorrect ? .systemGreen : .systemRed, width: 60)
    }

    // MARK: - Helpers

    private let allKeys = ["q","w","e","r","t","y","u","i","o","p",
                           "a","s","d","f","g","h","j","k","l",
                           "z","x","c","v","b","n","m","space","delete"]

    private func keyColor(_ key: String) -> UIColor {
        let idx   = Double(allKeys.firstIndex(of: key) ?? 0)
        let count = Double(allKeys.count)
        let hue   = (idx / count * 0.82 + 0.05).truncatingRemainder(dividingBy: 1.0)
        return UIColor(hue: CGFloat(hue), saturation: 0.78, brightness: 0.75, alpha: 0.85)
    }

    private func hasCoords(_ e: InputEventData) -> Bool {
        !(e.tapNormX == 0 && e.tapNormY == 0 && e.tapLocalX == 0 && e.tapLocalY == 0)
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor,
        width: CGFloat = 300
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        text.draw(in: CGRect(x: point.x, y: point.y, width: width, height: 20),
                  withAttributes: attrs)
    }
}
