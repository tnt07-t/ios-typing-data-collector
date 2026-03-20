import UIKit

// MARK: - KeyReportExporter
//
// Generates a PDF with one scatter plot per key showing where
// every tap landed (tapNormX / tapNormY), plus n, mean, and σ stats.

final class KeyReportExporter {

    private let pageW:  CGFloat = 612
    private let pageH:  CGFloat = 792
    private let margin: CGFloat = 28

    private let cols:   Int     = 5
    private let cellW:  CGFloat = 107
    private let cellH:  CGFloat = 118
    private let plotW:  CGFloat = 82
    private let plotH:  CGFloat = 56
    private let dotR:   CGFloat = 2.8

    private let keyOrder: [String] = [
        "q","w","e","r","t","y","u","i","o","p",
        "a","s","d","f","g","h","j","k","l",
        "z","x","c","v","b","n","m",
        "space","delete"
    ]

    func exportPDF(
        events: [InputEventData],
        session: Session,
        participant: Participant?
    ) async -> URL? {
        let byKey: [String: [InputEventData]] = Dictionary(
            grouping: events.filter { !$0.keyLabel.isEmpty && hasCoords($0) },
            by: \.keyLabel
        )
        guard !byKey.isEmpty else { return nil }

        let keys = keyOrder.filter { byKey[$0] != nil }

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("key_report_\(session.id.uuidString).pdf")

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        let data = renderer.pdfData { ctx in
            var keyIndex = 0
            var pageIndex = 0
            let usableH = pageH - margin - margin - 52
            let rowsPerPage = Int(usableH / cellH)
            let cellsPerPage = cols * rowsPerPage

            while keyIndex < keys.count {
                ctx.beginPage()
                pageIndex += 1
                let startY = drawPageHeader(ctx: ctx, session: session,
                                            participant: participant, page: pageIndex)
                var cellOnPage = 0
                while cellOnPage < cellsPerPage && keyIndex < keys.count {
                    let col = cellOnPage % cols
                    let row = cellOnPage / cols
                    let cellX = margin + CGFloat(col) * cellW
                    let cellY = startY + CGFloat(row) * cellH
                    let key = keys[keyIndex]
                    let taps = byKey[key] ?? []
                    drawKeyCell(ctx: ctx, key: key, taps: taps,
                                origin: CGPoint(x: cellX, y: cellY))
                    keyIndex += 1
                    cellOnPage += 1
                }
            }
        }

        do {
            try data.write(to: url)
            return url
        } catch {
            print("KeyReportExporter: \(error)")
            return nil
        }
    }

    @discardableResult
    private func drawPageHeader(
        ctx: UIGraphicsPDFRendererContext,
        session: Session,
        participant: Participant?,
        page: Int
    ) -> CGFloat {
        let cgCtx = ctx.cgContext
        cgCtx.setFillColor(UIColor.systemOrange.withAlphaComponent(0.9).cgColor)
        cgCtx.fill(CGRect(x: 0, y: 0, width: pageW, height: 40))

        drawText("Tap Distribution Report — Per Key",
                 at: CGPoint(x: margin, y: 10),
                 font: UIFont.systemFont(ofSize: 14, weight: .bold),
                 color: .white)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let dateStr = iso.string(from: session.startedAt)
        let name = participant.map {
            "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces)
        } ?? "—"
        drawText("Participant: \(name)   Date: \(dateStr)   Page \(page)",
                 at: CGPoint(x: margin, y: 44),
                 font: UIFont.systemFont(ofSize: 8, weight: .regular),
                 color: .secondaryLabel)

        return 58
    }

    private func drawKeyCell(
        ctx: UIGraphicsPDFRendererContext,
        key: String,
        taps: [InputEventData],
        origin: CGPoint
    ) {
        let cgCtx = ctx.cgContext
        let plotX = origin.x + (cellW - plotW) / 2
        let plotY = origin.y + 6
        let plotRect = CGRect(x: plotX, y: plotY, width: plotW, height: plotH)

        // Key face background
        cgCtx.setFillColor(UIColor.systemGray6.cgColor)
        let path = UIBezierPath(roundedRect: plotRect, cornerRadius: 5)
        cgCtx.addPath(path.cgPath)
        cgCtx.fillPath()

        // Border
        cgCtx.setStrokeColor(UIColor.separator.cgColor)
        cgCtx.setLineWidth(0.5)
        cgCtx.addPath(path.cgPath)
        cgCtx.strokePath()

        // Tap dots
        for (idx, tap) in taps.enumerated() {
            let x = plotX + clamp(tap.tapNormX) * plotW
            let y = plotY + clamp(tap.tapNormY) * plotH
            let dotRect = CGRect(x: x - dotR, y: y - dotR, width: dotR*2, height: dotR*2)
            cgCtx.setFillColor(dotColor(key: key, index: idx, total: taps.count).cgColor)
            cgCtx.fillEllipse(in: dotRect)
        }

        // Crosshair at mean
        if taps.count > 1 {
            let (mx, my) = mean(taps)
            let cx = plotX + CGFloat(mx) * plotW
            let cy = plotY + CGFloat(my) * plotH
            cgCtx.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.7).cgColor)
            cgCtx.setLineWidth(0.8)
            cgCtx.move(to: CGPoint(x: cx - 5, y: cy))
            cgCtx.addLine(to: CGPoint(x: cx + 5, y: cy))
            cgCtx.move(to: CGPoint(x: cx, y: cy - 5))
            cgCtx.addLine(to: CGPoint(x: cx, y: cy + 5))
            cgCtx.strokePath()
        }

        // Key label
        let labelY  = plotY + plotH + 3
        let statsY  = labelY + 13
        let statsY2 = statsY + 10

        drawText(keyDisplay(key),
                 at: CGPoint(x: origin.x + cellW/2, y: labelY),
                 font: UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
                 color: .label, alignment: .center, width: cellW)

        drawText("n = \(taps.count)",
                 at: CGPoint(x: origin.x + cellW/2, y: statsY),
                 font: UIFont.monospacedSystemFont(ofSize: 7.5, weight: .regular),
                 color: .secondaryLabel, alignment: .center, width: cellW)

        if taps.count > 0 {
            let (mx, my) = mean(taps)
            let (sx, sy) = stddev(taps, mx: mx, my: my)
            let statStr = String(format: "x\u{0305}=%.2f \u{03C3}=%.2f  y\u{0305}=%.2f \u{03C3}=%.2f",
                                 mx, sx, my, sy)
            drawText(statStr,
                     at: CGPoint(x: origin.x + cellW/2, y: statsY2),
                     font: UIFont.monospacedSystemFont(ofSize: 6.5, weight: .regular),
                     color: .tertiaryLabel, alignment: .center, width: cellW)
        }
    }

    private func mean(_ taps: [InputEventData]) -> (Double, Double) {
        let n = Double(taps.count)
        return (taps.map(\.tapNormX).reduce(0, +) / n,
                taps.map(\.tapNormY).reduce(0, +) / n)
    }

    private func stddev(_ taps: [InputEventData], mx: Double, my: Double) -> (Double, Double) {
        guard taps.count > 1 else { return (0, 0) }
        let n = Double(taps.count)
        let sx = sqrt(taps.map { pow($0.tapNormX - mx, 2) }.reduce(0, +) / (n - 1))
        let sy = sqrt(taps.map { pow($0.tapNormY - my, 2) }.reduce(0, +) / (n - 1))
        return (sx, sy)
    }

    private func dotColor(key: String, index: Int, total: Int) -> UIColor {
        let allKeys = ["q","w","e","r","t","y","u","i","o","p",
                       "a","s","d","f","g","h","j","k","l",
                       "z","x","c","v","b","n","m","space","delete"]
        let idx  = Double(allKeys.firstIndex(of: key) ?? 0)
        let count = Double(allKeys.count)
        let hue  = (idx / count * 0.82 + 0.05).truncatingRemainder(dividingBy: 1.0)
        return UIColor(hue: CGFloat(hue), saturation: 0.78, brightness: 0.82, alpha: 0.80)
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        width: CGFloat = 300
    ) {
        let para = NSMutableParagraphStyle()
        para.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para
        ]
        let rect: CGRect = alignment == .center
            ? CGRect(x: point.x - width/2, y: point.y, width: width, height: 20)
            : CGRect(x: point.x, y: point.y, width: width, height: 20)
        text.draw(in: rect, withAttributes: attrs)
    }

    private func hasCoords(_ e: InputEventData) -> Bool {
        !(e.tapNormX == 0 && e.tapNormY == 0 && e.tapLocalX == 0 && e.tapLocalY == 0)
    }

    private func clamp(_ v: Double) -> CGFloat {
        CGFloat(max(0.01, min(0.99, v.isNaN ? 0.5 : v)))
    }

    private func keyDisplay(_ key: String) -> String {
        switch key {
        case "space":  return "SPACE"
        case "delete": return "DELETE"
        default:       return key.uppercased()
        }
    }
}