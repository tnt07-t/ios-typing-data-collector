import SwiftUI

struct SessionView: View {
    var sessionManager: SessionManager

    var body: some View {
        Group {
            if sessionManager.isSessionComplete {
                SummaryView(sessionManager: sessionManager)
            } else if sessionManager.isTrialActive {
                TrialView(
                    sessionManager: sessionManager,
                    onTrialComplete: handleTrialComplete
                )
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading next phrase...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func handleTrialComplete() {
        if !sessionManager.isSessionComplete {
            sessionManager.startNextTrial()
        }
    }
}

// MARK: - SummaryView

struct SummaryView: View {
    var sessionManager: SessionManager
    @State private var shareItem: ShareItem? = nil
    @State private var showResetConfirm: Bool = false
    @State private var isGeneratingReport: Bool = false
    @State private var isGeneratingCoordPDF: Bool = false
    @State private var isGeneratingKeyboardView: Bool = false
    @State private var plotLayout: TapDotPlotView.LayoutMode = .alpha

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summaryStats
                    Divider()
                    tapPlotSection
                    Divider()
                    exportButtons
                }
                .padding()
            }
            .navigationTitle("Session Complete")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Session") { showResetConfirm = true }
                        .foregroundColor(.orange)
                }
            }
            .confirmationDialog("Start a new session?",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Same participant & duration") { sessionManager.restartSameSession() }
                Button("New participant", role: .destructive) { sessionManager.reset() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        VStack(spacing: 12) {
            Text("Session Summary")
                .font(.title2).fontWeight(.bold)

            if let session = sessionManager.currentSession {
                let meanWPM = sessionManager.completedTrials.isEmpty ? 0.0
                    : sessionManager.completedTrials.map(\.wpm).reduce(0, +) / Double(sessionManager.completedTrials.count)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "Duration",        value: sessionManager.formattedDuration)
                    statCard(title: "Phrases",          value: "\(session.completedTrials)")
                    statCard(title: "Mean Accuracy",    value: String(format: "%.1f%%", session.meanAccuracy * 100))
                    statCard(title: "Mean WPM",         value: String(format: "%.1f", meanWPM))
                    statCard(title: "Chars / Sec",      value: String(format: "%.2f", session.meanCharsPerSecond))
                    statCard(title: "Total Backspaces", value: "\(session.totalBackspaces)")
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2).fontWeight(.bold).foregroundColor(.orange)
            Text(title)
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }

    // MARK: - Tap Plot Section

    private var tapPlotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tap Distribution")
                    .font(.headline)
                Spacer()
                Picker("Layout", selection: $plotLayout) {
                    ForEach(TapDotPlotView.LayoutMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            TapDotPlotView(
                events: sessionManager.allEvents,
                colorMode: .byKey,
                layoutMode: plotLayout
            )
        }
    }

    // MARK: - Export Buttons

    private var exportButtons: some View {
        VStack(spacing: 12) {

            Button(action: exportKeyReport) {
                HStack {
                    if isGeneratingReport {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "chart.scatter")
                    }
                    Text(isGeneratingReport ? "Generating\u{2026}" : "Export Per-Key Tap Report (PDF)")
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.orange)
                .foregroundColor(.white).cornerRadius(10)
            }
            .disabled(isGeneratingReport)

            Button(action: exportCoordPDF) {
                HStack {
                    if isGeneratingCoordPDF {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "chart.dots.scatter")
                    }
                    Text(isGeneratingCoordPDF ? "Generating\u{2026}" : "Export Tap Coordinate Map (PDF)")
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.indigo)
                .foregroundColor(.white).cornerRadius(10)
            }
            .disabled(isGeneratingCoordPDF)

            Button(action: exportKeyboardViewPDF) {
                HStack {
                    if isGeneratingKeyboardView {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "keyboard.badge.eye")
                    }
                    Text(isGeneratingKeyboardView ? "Generating\u{2026}" : "Export Keyboard View PDF")
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.purple)
                .foregroundColor(.white).cornerRadius(10)
            }
            .disabled(isGeneratingKeyboardView)

            Divider()

            Button(action: exportCSV) {
                Label("Export Session CSV", systemImage: "doc.text")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary).cornerRadius(10)
            }

            Button(action: exportJSON) {
                Label("Export Session JSON", systemImage: "doc.badge.gearshape")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary).cornerRadius(10)
            }

            Button(action: exportKeystrokes) {
                Label("Export Keystrokes CSV", systemImage: "keyboard")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary).cornerRadius(10)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    // MARK: - Export Actions

    private func exportKeyReport() {
        guard let session = sessionManager.currentSession else { return }
        isGeneratingReport = true
        Task.detached(priority: .userInitiated) {
            let exporter = KeyReportExporter()
            let url = await exporter.exportPDF(
                events: sessionManager.allEvents,
                session: session,
                participant: sessionManager.participant
            )
            await MainActor.run {
                isGeneratingReport = false
                if let url { shareItem = ShareItem(url: url) }
            }
        }
    }

    private func exportCoordPDF() {
        guard let session = sessionManager.currentSession else { return }
        isGeneratingCoordPDF = true
        Task.detached(priority: .userInitiated) {
            let exporter = TapCoordPDFExporter()
            let url = await exporter.exportPDF(
                events: sessionManager.allEvents,
                session: session,
                participant: sessionManager.participant
            )
            await MainActor.run {
                isGeneratingCoordPDF = false
                if let url { shareItem = ShareItem(url: url) }
            }
        }
    }

    private func exportKeyboardViewPDF() {
        guard let session = sessionManager.currentSession else { return }
        isGeneratingKeyboardView = true
        Task.detached(priority: .userInitiated) {
            let exporter = KeyboardViewPDFExporter()
            let url = await exporter.exportPDF(
                events: sessionManager.allEvents,
                session: session,
                participant: sessionManager.participant
            )
            await MainActor.run {
                isGeneratingKeyboardView = false
                if let url { shareItem = ShareItem(url: url) }
            }
        }
    }

    private func exportCSV() {
        guard let session = sessionManager.currentSession else { return }
        if let url = DataExporter().exportEventsCSV(
            session: session,
            trials: sessionManager.completedTrials,
            participant: sessionManager.participant) {
            shareItem = ShareItem(url: url)
        }
    }

    private func exportJSON() {
        guard let session = sessionManager.currentSession else { return }
        if let url = DataExporter().exportSessionJSON(
            session: session,
            trials: sessionManager.completedTrials,
            participant: sessionManager.participant) {
            shareItem = ShareItem(url: url)
        }
    }

    private func exportKeystrokes() {
        guard let session = sessionManager.currentSession else { return }
        if let url = DataExporter().exportKeystrokesCSV(
            session: session,
            events: sessionManager.allEvents,
            participant: sessionManager.participant) {
            shareItem = ShareItem(url: url)
        }
    }
}

// MARK: - Helpers

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - KeyboardViewPDFExporter
//
// Exports the same keyboard-layout dot plot shown on screen, with:
//   - Participant/date header
//   - Keyboard key outlines
//   - Normalized coordinate axes grid (0.00–1.00)
//   - Colored dots at per-key normalized tap positions
//   - Legend

final class KeyboardViewPDFExporter {

    private let pageW:  CGFloat = 612
    private let pageH:  CGFloat = 792
    private let margin: CGFloat = 36

    private let allKeys = ["q","w","e","r","t","y","u","i","o","p",
                           "a","s","d","f","g","h","j","k","l",
                           "z","x","c","v","b","n","m","space","delete"]

    // Layout constants (mirrors TapDotPlotView)
    private let row0 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row1 = ["a","s","d","f","g","h","j","k","l"]
    private let row2 = ["z","x","c","v","b","n","m"]

    private let sidePad: CGFloat = 3
    private let keyGap:  CGFloat = 6
    private let rowGap:  CGFloat = 13
    private let topPad:  CGFloat = 11

    func exportPDF(
        events: [InputEventData],
        session: Session,
        participant: Participant?
    ) async -> URL? {

        let validEvents = events.filter {
            !$0.keyLabel.isEmpty &&
            Set(row0 + row1 + row2 + ["space", "delete"]).contains($0.keyLabel) &&
            !($0.tapNormX == 0 && $0.tapNormY == 0 && $0.tapLocalX == 0 && $0.tapLocalY == 0)
        }
        guard !validEvents.isEmpty else { return nil }

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("keyboard_view_\(session.id.uuidString).pdf")

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let headerBottom = drawHeader(ctx: ctx, session: session,
                                          participant: participant, tapCount: validEvents.count)
            let cgCtx = ctx.cgContext

            // Canvas area
            let canvasLeft   = margin + sidePad
            let canvasRight  = pageW - margin - sidePad
            let canvasTop    = headerBottom + 16
            let canvasW      = canvasRight - canvasLeft

            let kw   = (canvasW - 2 * sidePad - 9 * keyGap) / 10
            let sp   = (canvasW - 2 * sidePad - 7 * kw - 8 * keyGap) / 2
            let keyH = (kw * 1.35).rounded()
            let canvasH = topPad + 4 * keyH + 3 * rowGap + 8

            let frames = buildFrames(ox: canvasLeft, plotTop: canvasTop,
                                     kw: kw, sp: sp, keyH: keyH, plotW: canvasW)

            // ── Background (light mode) ─────────────────────────────────────────
            cgCtx.setFillColor(UIColor(red: 0.816, green: 0.827, blue: 0.851, alpha: 1).cgColor)
            cgCtx.fill(CGRect(x: canvasLeft, y: canvasTop, width: canvasW, height: canvasH))

            // ── Normalized grid (0.00 → 1.00) ──────────────────────────────────
            let gridSteps: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
            cgCtx.setStrokeColor(UIColor.black.withAlphaComponent(0.08).cgColor)
            cgCtx.setLineWidth(0.4)

            for t in gridSteps {
                // Vertical
                let gx = canvasLeft + t * canvasW
                cgCtx.move(to: CGPoint(x: gx, y: canvasTop))
                cgCtx.addLine(to: CGPoint(x: gx, y: canvasTop + canvasH))
                // Horizontal
                let gy = canvasTop + t * canvasH
                cgCtx.move(to: CGPoint(x: canvasLeft, y: gy))
                cgCtx.addLine(to: CGPoint(x: canvasLeft + canvasW, y: gy))
            }
            cgCtx.strokePath()

            // Grid labels — X axis (below canvas)
            let axisFont = UIFont.monospacedSystemFont(ofSize: 6.5, weight: .regular)
            for t in gridSteps {
                let label = String(format: "%.2f", t)
                drawText(label,
                         at: CGPoint(x: canvasLeft + t * canvasW - 10, y: canvasTop + canvasH + 3),
                         font: axisFont, color: .secondaryLabel, width: 24)
            }
            // Grid labels — Y axis (left of canvas)
            for t in gridSteps {
                let label = String(format: "%.2f", t)
                drawText(label,
                         at: CGPoint(x: canvasLeft - 28, y: canvasTop + t * canvasH - 5),
                         font: axisFont, color: .secondaryLabel, width: 26)
            }

            // Canvas border
            cgCtx.setStrokeColor(UIColor.separator.cgColor)
            cgCtx.setLineWidth(0.6)
            cgCtx.stroke(CGRect(x: canvasLeft, y: canvasTop, width: canvasW, height: canvasH))

            // ── Key outlines (light mode) ─────────────────────────────────────
            for (key, rect) in frames {
                let isSpecial = key.count > 1
                let keyPath = UIBezierPath(roundedRect: rect, cornerRadius: 5)

                let fill: UIColor = isSpecial
                    ? UIColor(red: 0.69, green: 0.71, blue: 0.73, alpha: 1)
                    : .white
                cgCtx.setFillColor(fill.cgColor)
                cgCtx.addPath(keyPath.cgPath); cgCtx.fillPath()

                cgCtx.setStrokeColor(UIColor(white: 0, alpha: 0.10).cgColor)
                cgCtx.setLineWidth(0.4)
                cgCtx.addPath(keyPath.cgPath); cgCtx.strokePath()

                // Shadow under key
                cgCtx.setStrokeColor(UIColor(white: 0, alpha: 0.25).cgColor)
                cgCtx.setLineWidth(1.0)
                cgCtx.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
                cgCtx.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY))
                cgCtx.strokePath()

                // Key label — centered
                let display = key == "delete" ? "\u{232B}" : key == "space" ? "\u{23B5}" : key
                let fontSize: CGFloat = key.count > 1 ? 6 : max(5, keyH * 0.22)
                drawTextCentered(display,
                         in: rect,
                         font: .systemFont(ofSize: fontSize, weight: .regular),
                         color: UIColor(white: 0, alpha: 0.3))
            }

            // ── Tap dots (per-key normalized position) ──────────────────────────
            let dotR: CGFloat = 3.5
            for e in validEvents {
                guard let frame = frames[e.keyLabel] else { continue }
                let normX = e.keyWidth > 0 ? e.tapLocalX / e.keyWidth : 0.5
                let normY = e.keyHeight > 0 ? e.tapLocalY / e.keyHeight : 0.5
                let px = frame.minX + CGFloat(normX) * frame.width
                let py = frame.minY + CGFloat(normY) * frame.height

                let colorKey = e.expectedChar.isEmpty ? e.keyLabel : e.expectedChar
                let color = keyUIColor(colorKey)

                cgCtx.setFillColor(color.withAlphaComponent(0.85).cgColor)
                cgCtx.fillEllipse(in: CGRect(x: px - dotR, y: py - dotR,
                                              width: dotR * 2, height: dotR * 2))
            }

            // ── Legend ──────────────────────────────────────────────────────────
            let legendY = canvasTop + canvasH + 18
            let shownKeys = Array(Set(validEvents.map {
                $0.expectedChar.isEmpty ? $0.keyLabel : $0.expectedChar
            })).sorted()
            var lx = canvasLeft
            for k in shownKeys {
                cgCtx.setFillColor(keyUIColor(k).cgColor)
                cgCtx.fillEllipse(in: CGRect(x: lx, y: legendY + 1, width: 7, height: 7))
                let display = k == "delete" ? "del" : k == "space" ? "sp" : k
                drawText(display,
                         at: CGPoint(x: lx + 9, y: legendY - 1),
                         font: .monospacedSystemFont(ofSize: 7, weight: .medium),
                         color: .secondaryLabel, width: 22)
                lx += 24
                if lx + 24 > canvasRight { break }
            }
        }

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Header

    @discardableResult
    private func drawHeader(ctx: UIGraphicsPDFRendererContext, session: Session,
                            participant: Participant?, tapCount: Int) -> CGFloat {
        let cgCtx = ctx.cgContext
        cgCtx.setFillColor(UIColor.systemPurple.withAlphaComponent(0.85).cgColor)
        cgCtx.fill(CGRect(x: 0, y: 0, width: pageW, height: 40))

        drawText("Tap Distribution \u{2014} Keyboard View",
                 at: CGPoint(x: margin, y: 10),
                 font: .systemFont(ofSize: 14, weight: .bold), color: .white)
        drawText("\(tapCount) taps",
                 at: CGPoint(x: pageW - margin - 60, y: 12),
                 font: .monospacedSystemFont(ofSize: 11, weight: .medium), color: .white, width: 60)

        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
        let name = participant.map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) } ?? "\u{2014}"
        drawText("Participant: \(name)   Date: \(iso.string(from: session.startedAt))",
                 at: CGPoint(x: margin, y: 44),
                 font: .systemFont(ofSize: 8), color: .secondaryLabel)
        return 56
    }

    // MARK: - Key Frames

    private func buildFrames(ox: CGFloat, plotTop: CGFloat, kw: CGFloat,
                             sp: CGFloat, keyH: CGFloat, plotW: CGFloat) -> [String: CGRect] {
        var f = [String: CGRect]()
        let y0 = plotTop + topPad
        for (i, k) in row0.enumerated() {
            f[k] = CGRect(x: ox + sidePad + CGFloat(i) * (kw + keyGap), y: y0, width: kw, height: keyH)
        }
        let y1 = y0 + keyH + rowGap
        let row1Start = ox + (plotW - 9 * kw - 8 * keyGap) / 2
        for (i, k) in row1.enumerated() {
            f[k] = CGRect(x: row1Start + CGFloat(i) * (kw + keyGap), y: y1, width: kw, height: keyH)
        }
        let y2 = y1 + keyH + rowGap
        let row2Start = ox + sidePad + sp + keyGap
        for (i, k) in row2.enumerated() {
            f[k] = CGRect(x: row2Start + CGFloat(i) * (kw + keyGap), y: y2, width: kw, height: keyH)
        }
        f["delete"] = CGRect(x: ox + plotW - sidePad - sp, y: y2, width: sp, height: keyH)
        let y3 = y2 + keyH + rowGap
        f["space"] = CGRect(x: ox + sidePad + sp + keyGap, y: y3,
                            width: plotW - 2 * sidePad - 2 * sp - 2 * keyGap, height: keyH)
        return f
    }

    // MARK: - Helpers

    private func keyUIColor(_ key: String) -> UIColor {
        let idx = Double(allKeys.firstIndex(of: key) ?? 0)
        let hue = (idx * 0.618033988749895).truncatingRemainder(dividingBy: 1.0)
        let sat: CGFloat = idx.truncatingRemainder(dividingBy: 2) == 0 ? 0.82 : 0.65
        return UIColor(hue: CGFloat(hue), saturation: sat, brightness: 0.88, alpha: 1.0)
    }

    private func drawText(_ text: String, at point: CGPoint,
                          font: UIFont, color: UIColor, width: CGFloat = 200) {
        text.draw(in: CGRect(x: point.x, y: point.y, width: width, height: 20),
                  withAttributes: [.font: font, .foregroundColor: color])
    }

    private func drawTextCentered(_ text: String, in rect: CGRect,
                                  font: UIFont, color: UIColor) {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let textRect = CGRect(x: rect.minX,
                              y: rect.midY - size.height / 2,
                              width: rect.width,
                              height: size.height)
        text.draw(in: textRect, withAttributes: attrs)
    }
}
