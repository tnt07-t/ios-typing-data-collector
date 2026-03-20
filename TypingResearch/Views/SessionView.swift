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
            Text("Tap Distribution")
                .font(.headline)

            TapDotPlotView(
                events: sessionManager.allEvents,
                colorMode: .byKey
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
                    Text(isGeneratingReport ? "Generating…" : "Export Per-Key Tap Report (PDF)")
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
                    Text(isGeneratingCoordPDF ? "Generating…" : "Export Tap Coordinate Map (PDF)")
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.indigo)
                .foregroundColor(.white).cornerRadius(10)
            }
            .disabled(isGeneratingCoordPDF)

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