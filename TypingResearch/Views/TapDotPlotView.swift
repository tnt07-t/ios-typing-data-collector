import SwiftUI

// MARK: - Key Color Palette

extension Color {
    static func dotColor(forKey key: String) -> Color {
        let allKeys: [String] = [
            "q","w","e","r","t","y","u","i","o","p",
            "a","s","d","f","g","h","j","k","l",
            "z","x","c","v","b","n","m",
            "space","delete"
        ]
        let idx    = Double(allKeys.firstIndex(of: key) ?? 0)
        let total  = Double(allKeys.count)
        return Color(hue: (idx / total * 0.82 + 0.05).truncatingRemainder(dividingBy: 1.0),
                     saturation: 0.78, brightness: 0.9)
    }

    static func dotColor(forTimeIndex idx: Int, total: Int) -> Color {
        let t = total > 1 ? Double(idx) / Double(total - 1) : 0
        return Color(hue: 0.62 - t * 0.55, saturation: 0.8, brightness: 0.9)
    }
}

// MARK: - TapDotPlotView

struct TapDotPlotView: View {

    let events: [InputEventData]

    var colorMode:   DotColorMode = .byKey
    var dotRadius:   CGFloat      = 3.5
    var showHeader:  Bool         = true
    var showLegend:  Bool         = true
    var transparent: Bool         = false

    enum DotColorMode: String, CaseIterable, Identifiable {
        case byKey = "By Key"
        var id: String { rawValue }
    }

    enum LayoutMode: String, CaseIterable, Identifiable {
        case alpha   = "ABC"
        case numeric = "123"
        var id: String { rawValue }
    }

    var layoutMode: LayoutMode = .alpha

    private let sidePad:    CGFloat = 3
    private let keyGap:     CGFloat = 6
    private let rowGap:     CGFloat = 11
    private let topPad:     CGFloat = 11
    private let bottomPad:  CGFloat = 3
    private let keyH:       CGFloat = 42

    // Alpha layout keys
    private let row0 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row1 = ["a","s","d","f","g","h","j","k","l"]
    private let row2 = ["z","x","c","v","b","n","m"]

    // Numeric layout keys (mirrors CustomKeyboardView)
    private let numRow0  = ["1","2","3","4","5","6","7","8","9","0"]
    private let numRow1  = ["-","/",":",";","(",")","\u{0024}","&","@","\""]
    private let numRow2p = [".",",","?","!","'"]

    // Keys that belong to each layout (for filtering dots)
    private var alphaKeys: Set<String> {
        Set(row0 + row1 + row2 + ["space", "delete"])
    }
    private var numericKeys: Set<String> {
        Set(numRow0 + numRow1 + numRow2p + ["space"])
    }

    private var canvasHeight: CGFloat {
        topPad + 4 * keyH + 3 * rowGap + bottomPad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader { headerRow }
            keyboardCanvas
            if showLegend { legend }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Tap Distribution")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text("\(validDots.count) taps")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private var keyboardCanvas: some View {
        GeometryReader { geo in
            let W  = geo.size.width
            let kw = (W - 2*sidePad - 9*keyGap) / 10
            let sp = (W - 2*sidePad - 7*kw  - 8*keyGap) / 2
            let frames = buildFrames(W: W, kw: kw, sp: sp)
            let dots   = validDots

            Canvas { ctx, _ in
                if !transparent {
                    for (_, rect) in frames {
                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: 5),
                            with: .color(Color(.systemGray5))
                        )
                    }
                }

                for (idx, event) in dots.enumerated() {
                    guard let frame = frames[event.keyLabel] else { continue }
                    let x = frame.minX + clamp(event.tapNormX) * frame.width
                    let y = frame.minY + clamp(event.tapNormY) * frame.height
                    let r = dotRadius
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2)),
                        with: .color(dotColor(event: event, index: idx, total: dots.count).opacity(0.85))
                    )
                }

                for (_, rect) in frames {
                    ctx.stroke(
                        Path(roundedRect: rect, cornerRadius: 5),
                        with: .color(Color(.separator).opacity(transparent ? 0.0 : 0.4)),
                        lineWidth: 0.5
                    )
                }

                if !transparent {
                    for (label, rect) in frames {
                        ctx.draw(
                            Text(keyDisplay(label))
                                .font(.system(size: label.count > 1 ? 7.5 : 9,
                                              weight: .regular, design: .monospaced))
                                .foregroundColor(Color(.tertiaryLabel)),
                            at: CGPoint(x: rect.midX, y: rect.midY)
                        )
                    }
                }
            }
        }
        .frame(height: canvasHeight)
        .background(transparent ? Color.clear : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: transparent ? 0 : 10))
    }

    private var legend: some View {
        let shownKeys = Set(validDots.map(\.keyLabel)).sorted()
        guard !shownKeys.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shownKeys, id: \.self) { key in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.dotColor(forKey: key))
                                .frame(width: 7, height: 7)
                            Text(keyDisplay(key))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        )
    }

    private var validDots: [InputEventData] {
        let allowedKeys = layoutMode == .alpha ? alphaKeys : numericKeys
        return events.filter {
            !$0.keyLabel.isEmpty &&
            allowedKeys.contains($0.keyLabel) &&
            !($0.tapNormX == 0 && $0.tapNormY == 0 &&
              $0.tapLocalX == 0 && $0.tapLocalY == 0)
        }
    }

    private func clamp(_ v: Double) -> CGFloat {
        CGFloat(max(0.01, min(0.99, v.isNaN ? 0.5 : v)))
    }

    private func keyDisplay(_ label: String) -> String {
        switch label {
        case "delete": return "⌫"
        case "space":  return "⎵"
        default:       return label
        }
    }

    private func dotColor(event: InputEventData, index: Int, total: Int) -> Color {
        return .dotColor(forKey: event.keyLabel)
    }

    private func buildFrames(W: CGFloat, kw: CGFloat, sp: CGFloat) -> [String: CGRect] {
        layoutMode == .alpha
            ? buildAlphaFrames(W: W, kw: kw, sp: sp)
            : buildNumericFrames(W: W, kw: kw, sp: sp)
    }

    private func buildAlphaFrames(W: CGFloat, kw: CGFloat, sp: CGFloat) -> [String: CGRect] {
        var f = [String: CGRect]()
        let y0 = topPad
        for (i, k) in row0.enumerated() {
            f[k] = CGRect(x: sidePad + CGFloat(i)*(kw+keyGap), y: y0, width: kw, height: keyH)
        }
        let y1 = y0 + keyH + rowGap
        let row1Start = (W - 9*kw - 8*keyGap) / 2
        for (i, k) in row1.enumerated() {
            f[k] = CGRect(x: row1Start + CGFloat(i)*(kw+keyGap), y: y1, width: kw, height: keyH)
        }
        let y2 = y1 + keyH + rowGap
        let row2Start = sidePad + sp + keyGap
        for (i, k) in row2.enumerated() {
            f[k] = CGRect(x: row2Start + CGFloat(i)*(kw+keyGap), y: y2, width: kw, height: keyH)
        }
        f["delete"] = CGRect(x: W - sidePad - sp, y: y2, width: sp, height: keyH)
        let y3 = y2 + keyH + rowGap
        f["space"] = CGRect(x: sidePad + sp + keyGap, y: y3,
                            width: W - 2*sidePad - 2*sp - 2*keyGap, height: keyH)
        return f
    }

    private func buildNumericFrames(W: CGFloat, kw: CGFloat, sp: CGFloat) -> [String: CGRect] {
        var f = [String: CGRect]()
        // Row 0: digits — same grid as alpha row 0
        let y0 = topPad
        for (i, k) in numRow0.enumerated() {
            f[k] = CGRect(x: sidePad + CGFloat(i)*(kw+keyGap), y: y0, width: kw, height: keyH)
        }
        // Row 1: symbols — same grid (10 keys)
        let y1 = y0 + keyH + rowGap
        for (i, k) in numRow1.enumerated() {
            f[k] = CGRect(x: sidePad + CGFloat(i)*(kw+keyGap), y: y1, width: kw, height: keyH)
        }
        // Row 2: 5 punctuation keys between specials
        let y2 = y1 + keyH + rowGap
        let puncW = (W - 2*sidePad - 2*sp - 6*keyGap) / 5
        let puncStart = sidePad + sp + keyGap
        for (i, k) in numRow2p.enumerated() {
            f[k] = CGRect(x: puncStart + CGFloat(i)*(puncW+keyGap), y: y2, width: puncW, height: keyH)
        }
        // Row 3: space
        let y3 = y2 + keyH + rowGap
        f["space"] = CGRect(x: sidePad + sp + keyGap, y: y3,
                            width: W - 2*sidePad - 2*sp - 2*keyGap, height: keyH)
        return f
    }
}