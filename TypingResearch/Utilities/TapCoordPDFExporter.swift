import UIKit

// MARK: - TapCoordPDFExporter
//
// Page 1 — tap dots drawn to scale ON TOP of the actual keyboard layout.
//           (0,0) = top-left corner of the keyboard.
//           Key shapes are reconstructed from the stored keyScreenX/Y/W/H data.
// Page 2+ — full coordinate table (one row per tap).

final class TapCoordPDFExporter {

    private let pageW:  CGFloat = 612
    private let pageH:  CGFloat = 792
    private let margin: CGFloat = 36

    // MARK: - Entry Point

    func exportPDF(
        events: [InputEventData],
        session: Session,
        participant: Participant?
    ) async -> URL? {

        let taps = events.filter { hasCoords($0) }
        guard !taps.isEmpty else { return nil }

        // Keyboard top-left origin in screen space
        let kbOriginX = taps.map { $0.keyScreenX }.min()!
        let kbOriginY = taps.map { $0.keyScreenY }.min()!

        // Keyboard bounding box (pts)
        let kbW = taps.map { $0.keyScreenX + $0.keyWidth  - kbOriginX }.max()!
        let kbH = taps.map { $0.keyScreenY + $0.keyHeight - kbOriginY }.max()!

        // Per-tap coords relative to keyboard origin
        let coords: [TapCoord] = taps.map { e in
            TapCoord(
                x: e.keyScreenX + e.tapLocalX - kbOriginX,
                y: e.keyScreenY + e.tapLocalY - kbOriginY,
                key: e.keyLabel,
                expectedChar: e.expectedChar,
                isCorrect: e.isCorrect
            )
        }

        // Unique key outlines (one entry per key label, from first event seen)
        var keyRects: [String: CGRect] = [:]
        for e in taps where keyRects[e.keyLabel] == nil {
            keyRects[e.keyLabel] = CGRect(
                x: e.keyScreenX - kbOriginX,
                y: e.keyScreenY - kbOriginY,
                width: e.keyWidth,
                height: e.keyHeight
            )
        }

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("tap_coords_\(session.id.uuidString).pdf")

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        let data = renderer.pdfData { ctx in
            // ── Page 1: keyboard map ─────────────────────────────────────────
            ctx.beginPage()
            let headerY = drawHeader(ctx: ctx, title: "Tap Coordinate Map",
                                     session: session, participant: participant, page: 1)
            drawKeyboardMap(ctx: ctx,
                            keyRects: keyRects,
                            coords: coords,
                            kbW: kbW, kbH: kbH,
                            topY: headerY + 20)

            // ── Page 2+: coordinate table ────────────────────────────────────
            let rowH: CGFloat      = 13
            let tableTop: CGFloat  = 58
            let rowsPerPage        = Int((pageH - tableTop - margin) / rowH)
            var rowIndex  = 0
            var pageIndex = 2

            while rowIndex < coords.count {
                ctx.beginPage()
                drawHeader(ctx: ctx, title: "Tap Coordinates — List",
                           session: session, participant: participant, page: pageIndex)
                drawTableHeader(ctx: ctx, y: tableTop)
                var rowY = tableTop + rowH
                var rowsOnPage = 0
                while rowsOnPage < rowsPerPage && rowIndex < coords.count {
                    let c = coords[rowIndex]
                    drawTableRow(ctx: ctx, index: rowIndex + 1,
                                 key: c.key, x: c.x, y: c.y,
                                 isCorrect: c.isCorrect,
                                 rowY: rowY, shaded: rowIndex % 2 == 1)
                    rowY += rowH; rowIndex += 1; rowsOnPage += 1
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
        let c = ctx.cgContext
        c.setFillColor(UIColor.systemIndigo.withAlphaComponent(0.85).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: pageW, height: 40))

        drawText(title, at: CGPoint(x: margin, y: 10),
                 font: .systemFont(ofSize: 14, weight: .bold), color: .white)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let name = participant.map {
            "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces)
        } ?? "—"
        drawText("Participant: \(name)   Date: \(iso.string(from: session.startedAt))   Page \(page)",
                 at: CGPoint(x: margin, y: 44),
                 font: .systemFont(ofSize: 8), color: .secondaryLabel)
        return 56
    }

    // MARK: - Keyboard Map (Page 1)

    private func drawKeyboardMap(
        ctx: UIGraphicsPDFRendererContext,
        keyRects: [String: CGRect],
        coords: [TapCoord],
        kbW: Double, kbH: Double,
        topY: CGFloat
    ) {
        let c = ctx.cgContext

        // Plot area — leave room for axis labels and legend
        let plotLeft:   CGFloat = margin + 48
        let plotRight:  CGFloat = pageW - margin - 12
        let plotTop:    CGFloat = topY + 8
        let plotBottom: CGFloat = pageH - margin - 58

        let plotW = plotRight - plotLeft
        let plotH = plotBottom - plotTop

        // Scale uniformly so keyboard fills plot area, centered
        let scaleX = plotW / CGFloat(kbW)
        let scaleY = plotH / CGFloat(kbH)
        let scale  = min(scaleX, scaleY)

        let kbPdfW = CGFloat(kbW) * scale
        let kbPdfH = CGFloat(kbH) * scale
        let ox = plotLeft + (plotW - kbPdfW) / 2
        let oy = plotTop  + (plotH - kbPdfH) / 2

        // ── Grid lines (coordinate plane) ────────────────────────────────────
        let gridCountX = 8
        let gridCountY = 5
        c.setStrokeColor(UIColor.systemIndigo.withAlphaComponent(0.12).cgColor)
        c.setLineWidth(0.5)
        for i in 0...gridCountX {
            let gx = ox + CGFloat(i) / CGFloat(gridCountX) * kbPdfW
            c.move(to: CGPoint(x: gx, y: oy))
            c.addLine(to: CGPoint(x: gx, y: oy + kbPdfH))
            c.strokePath()
        }
        for i in 0...gridCountY {
            let gy = oy + CGFloat(i) / CGFloat(gridCountY) * kbPdfH
            c.move(to: CGPoint(x: ox, y: gy))
            c.addLine(to: CGPoint(x: ox + kbPdfW, y: gy))
            c.strokePath()
        }

        // ── Keyboard background ───────────────────────────────────────────────
        let kbBgColor = UIColor(red: 0.82, green: 0.83, blue: 0.855, alpha: 0.92)
        c.setFillColor(kbBgColor.cgColor)
        c.fill(CGRect(x: ox, y: oy, width: kbPdfW, height: kbPdfH))

        // ── Key outlines ──────────────────────────────────────────────────────
        let specialSet: Set<String> = ["space", "delete", "⇧", "⌫", "123", "return"]
        for (key, rect) in keyRects {
            let isSpecial = specialSet.contains(key) || key.count > 1
            let kx = ox + rect.minX * scale
            let ky = oy + rect.minY * scale
            let kw = rect.width  * scale
            let kh = rect.height * scale

            let keyRect = CGRect(x: kx + 1, y: ky + 1, width: kw - 2, height: kh - 2)
            let keyPath = UIBezierPath(roundedRect: keyRect, cornerRadius: max(2, kh * 0.14))

            let fill: UIColor = isSpecial
                ? UIColor(red: 0.69, green: 0.71, blue: 0.73, alpha: 1)
                : .white

            c.setFillColor(fill.cgColor)
            c.addPath(keyPath.cgPath)
            c.fillPath()

            c.setStrokeColor(UIColor(white: 0, alpha: 0.25).cgColor)
            c.setLineWidth(0.5)
            c.addPath(keyPath.cgPath)
            c.strokePath()

            let display  = keyDisplay(key)
            let fontSize = max(5, kh * 0.38)
            let textW    = max(kw - 4, 10)
            // Bottom-left corner so tap dots drawn later don't obscure the label
            drawText(display,
                     at: CGPoint(x: kx + 2, y: ky + kh - fontSize - 2),
                     font: .systemFont(ofSize: fontSize, weight: .medium),
                     color: UIColor.label.withAlphaComponent(0.65), width: textW)
        }

        // ── Axis lines (drawn over keyboard, under dots) ──────────────────────
        // X axis — along top edge of keyboard (y = 0)
        c.setStrokeColor(UIColor.systemIndigo.withAlphaComponent(0.7).cgColor)
        c.setLineWidth(1.2)
        c.move(to: CGPoint(x: ox - 8, y: oy))
        c.addLine(to: CGPoint(x: ox + kbPdfW + 4, y: oy))
        c.strokePath()
        // Y axis — along left edge of keyboard (x = 0)
        c.move(to: CGPoint(x: ox, y: oy - 8))
        c.addLine(to: CGPoint(x: ox, y: oy + kbPdfH + 4))
        c.strokePath()

        // Arrowheads
        c.setFillColor(UIColor.systemIndigo.withAlphaComponent(0.7).cgColor)
        // X arrow
        let xArrowTip = CGPoint(x: ox + kbPdfW + 4, y: oy)
        c.move(to: xArrowTip)
        c.addLine(to: CGPoint(x: xArrowTip.x - 5, y: xArrowTip.y - 3))
        c.addLine(to: CGPoint(x: xArrowTip.x - 5, y: xArrowTip.y + 3))
        c.closePath(); c.fillPath()
        // Y arrow
        let yArrowTip = CGPoint(x: ox, y: oy - 8)
        c.move(to: yArrowTip)
        c.addLine(to: CGPoint(x: yArrowTip.x - 3, y: yArrowTip.y + 5))
        c.addLine(to: CGPoint(x: yArrowTip.x + 3, y: yArrowTip.y + 5))
        c.closePath(); c.fillPath()

        // ── Keyboard border ───────────────────────────────────────────────────
        c.setStrokeColor(UIColor.systemGray3.cgColor)
        c.setLineWidth(0.8)
        c.stroke(CGRect(x: ox, y: oy, width: kbPdfW, height: kbPdfH))

        // ── Tap dots (colored by correct=green / incorrect=red) ───────────────
        let dotR: CGFloat = 3.5
        for coord in coords {
            let px = ox + CGFloat(coord.x) * scale
            let py = oy + CGFloat(coord.y) * scale
            let haloRect = CGRect(x: px - dotR - 1, y: py - dotR - 1,
                                  width: (dotR+1)*2, height: (dotR+1)*2)
            let dotRect  = CGRect(x: px - dotR, y: py - dotR, width: dotR*2, height: dotR*2)

            // White halo for contrast
            c.setFillColor(UIColor.white.withAlphaComponent(0.80).cgColor)
            c.fillEllipse(in: haloRect)

            let dotColor: UIColor = coord.isCorrect ? .systemGreen : .systemRed
            c.setFillColor(dotColor.withAlphaComponent(0.88).cgColor)
            c.fillEllipse(in: dotRect)

            // Expected char label in white inside the dot
            let label = coord.expectedChar.isEmpty ? coord.key : coord.expectedChar
            if label.count == 1 {
                drawText(label,
                         at: CGPoint(x: px - dotR + 0.5, y: py - dotR * 0.85),
                         font: .monospacedSystemFont(ofSize: dotR * 1.1, weight: .bold),
                         color: .white, width: dotR * 2, centered: true)
            }
        }

        // ── Axis tick labels ──────────────────────────────────────────────────
        let xTicks = 6
        let yTicks = 4
        let tickFont = UIFont.monospacedSystemFont(ofSize: 6.5, weight: .regular)

        // X axis ticks (below keyboard)
        for i in 0...xTicks {
            let fx  = CGFloat(i) / CGFloat(xTicks)
            let gx  = ox + fx * kbPdfW
            let val = Int(fx * CGFloat(kbW))
            c.setStrokeColor(UIColor.secondaryLabel.cgColor)
            c.setLineWidth(0.5)
            c.move(to: CGPoint(x: gx, y: oy + kbPdfH))
            c.addLine(to: CGPoint(x: gx, y: oy + kbPdfH + 4))
            c.strokePath()
            drawText("\(val)", at: CGPoint(x: gx - 12, y: oy + kbPdfH + 5),
                     font: tickFont, color: .secondaryLabel, width: 26)
        }
        // Y axis ticks (left of keyboard)
        for i in 0...yTicks {
            let fy  = CGFloat(i) / CGFloat(yTicks)
            let gy  = oy + fy * kbPdfH
            let val = Int(fy * CGFloat(kbH))
            c.setStrokeColor(UIColor.secondaryLabel.cgColor)
            c.setLineWidth(0.5)
            c.move(to: CGPoint(x: ox, y: gy))
            c.addLine(to: CGPoint(x: ox - 4, y: gy))
            c.strokePath()
            drawText("\(val)", at: CGPoint(x: ox - 38, y: gy - 5),
                     font: tickFont, color: .secondaryLabel, width: 34)
        }

        // Origin label
        drawText("(0,0)", at: CGPoint(x: ox - 30, y: oy - 14),
                 font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                 color: .systemIndigo, width: 32)

        // Axis titles
        drawText("x  (pts from keyboard left)",
                 at: CGPoint(x: ox + kbPdfW + 8, y: oy - 4),
                 font: .systemFont(ofSize: 7.5, weight: .medium),
                 color: .systemIndigo, width: 160)

        c.saveGState()
        c.translateBy(x: ox - 30, y: oy + kbPdfH / 2 + 60)
        c.rotate(by: -.pi / 2)
        drawText("y  (pts from keyboard top)",
                 at: CGPoint(x: -60, y: -4),
                 font: .systemFont(ofSize: 7.5, weight: .medium),
                 color: .systemIndigo, width: 120)
        c.restoreGState()

        // ── Legend ────────────────────────────────────────────────────────────
        let ly = oy + kbPdfH + 26
        let correctCount   = coords.filter { $0.isCorrect }.count
        let incorrectCount = coords.filter { !$0.isCorrect }.count

        c.setFillColor(UIColor.systemGreen.cgColor)
        c.fillEllipse(in: CGRect(x: ox, y: ly, width: 7, height: 7))
        drawText("correct (\(correctCount))",
                 at: CGPoint(x: ox + 10, y: ly - 1),
                 font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                 color: .secondaryLabel, width: 80)

        c.setFillColor(UIColor.systemRed.cgColor)
        c.fillEllipse(in: CGRect(x: ox + 96, y: ly, width: 7, height: 7))
        drawText("incorrect (\(incorrectCount))",
                 at: CGPoint(x: ox + 106, y: ly - 1),
                 font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                 color: .secondaryLabel, width: 90)
    }

    // MARK: - Coordinate Table

    private var colNum:  CGFloat { margin }
    private var colKey:  CGFloat { margin + 44 }
    private var colX:    CGFloat { margin + 120 }
    private var colY:    CGFloat { margin + 230 }
    private var colOK:   CGFloat { margin + 340 }

    private func drawTableHeader(ctx: UIGraphicsPDFRendererContext, y: CGFloat) {
        let c = ctx.cgContext
        c.setFillColor(UIColor.systemIndigo.withAlphaComponent(0.15).cgColor)
        c.fill(CGRect(x: margin, y: y, width: pageW - 2*margin, height: 13))

        let f = UIFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        drawText("#",         at: CGPoint(x: colNum, y: y+2), font: f, color: .label, width: 36)
        drawText("Key",       at: CGPoint(x: colKey, y: y+2), font: f, color: .label, width: 60)
        drawText("x (pts)",   at: CGPoint(x: colX,   y: y+2), font: f, color: .label, width: 80)
        drawText("y (pts)",   at: CGPoint(x: colY,   y: y+2), font: f, color: .label, width: 80)
        drawText("Correct",   at: CGPoint(x: colOK,  y: y+2), font: f, color: .label, width: 60)
    }

    private func drawTableRow(
        ctx: UIGraphicsPDFRendererContext,
        index: Int, key: String,
        x: Double, y: Double,
        isCorrect: Bool, rowY: CGFloat, shaded: Bool
    ) {
        let c = ctx.cgContext
        if shaded {
            c.setFillColor(UIColor.systemGray6.cgColor)
            c.fill(CGRect(x: margin, y: rowY, width: pageW - 2*margin, height: 13))
        }
        let f = UIFont.monospacedSystemFont(ofSize: 7.5, weight: .regular)
        drawText("\(index)",                  at: CGPoint(x: colNum, y: rowY+2), font: f, color: .secondaryLabel, width: 36)
        drawText(key,                         at: CGPoint(x: colKey, y: rowY+2), font: f, color: keyColor(key), width: 60)
        drawText(String(format: "%.2f", x),   at: CGPoint(x: colX,  y: rowY+2), font: f, color: .label, width: 80)
        drawText(String(format: "%.2f", y),   at: CGPoint(x: colY,  y: rowY+2), font: f, color: .label, width: 80)
        drawText(isCorrect ? "✓" : "✗",      at: CGPoint(x: colOK,  y: rowY+2), font: f,
                 color: isCorrect ? .systemGreen : .systemRed, width: 40)
    }

    // MARK: - Helpers

    private struct TapCoord {
        let x, y: Double
        let key: String
        let expectedChar: String
        let isCorrect: Bool
    }

    private let allKeys = ["q","w","e","r","t","y","u","i","o","p",
                           "a","s","d","f","g","h","j","k","l",
                           "z","x","c","v","b","n","m","space","delete"]

    private func keyColor(_ key: String) -> UIColor {
        let idx = Double(allKeys.firstIndex(of: key) ?? 0)
        let hue = (idx * 0.618033988749895).truncatingRemainder(dividingBy: 1.0)
        let sat: CGFloat = idx.truncatingRemainder(dividingBy: 2) == 0 ? 0.82 : 0.65
        return UIColor(hue: CGFloat(hue), saturation: sat, brightness: 0.85, alpha: 1.0)
    }

    private func hasCoords(_ e: InputEventData) -> Bool {
        !(e.tapNormX == 0 && e.tapNormY == 0 && e.tapLocalX == 0 && e.tapLocalY == 0)
    }

    private func keyDisplay(_ key: String) -> String {
        switch key {
        case "space":  return "space"
        case "delete": return "⌫"
        default:       return key
        }
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor,
        width: CGFloat = 300,
        centered: Bool = false
    ) {
        let para = NSMutableParagraphStyle()
        para.alignment = centered ? .center : .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para
        ]
        let rect = centered
            ? CGRect(x: point.x, y: point.y, width: width, height: 20)
            : CGRect(x: point.x, y: point.y, width: width, height: 20)
        text.draw(in: rect, withAttributes: attrs)
    }
}
