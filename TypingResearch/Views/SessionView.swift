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
                // Between trials or loading
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryStats
                    Divider()
                    exportButtons
                }
                .padding()
            }
            .navigationTitle("Session Complete")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Session") {
                        showResetConfirm = true
                    }
                    .foregroundColor(.orange)
                }
            }
            .confirmationDialog("Start a new session?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("New Session", role: .destructive) {
                    sessionManager.reset()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        VStack(spacing: 12) {
            Text("Session Summary")
                .font(.title2)
                .fontWeight(.bold)

            if let session = sessionManager.currentSession {
                let meanWPM = sessionManager.completedTrials.isEmpty ? 0.0
                    : sessionManager.completedTrials.map(\.wpm).reduce(0, +) / Double(sessionManager.completedTrials.count)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(
                        title: "Duration",
                        value: sessionManager.formattedDuration
                    )
                    statCard(
                        title: "Phrases Completed",
                        value: "\(session.completedTrials)"
                    )
                    statCard(
                        title: "Mean Accuracy",
                        value: String(format: "%.1f%%", session.meanAccuracy * 100)
                    )
                    statCard(
                        title: "Mean WPM",
                        value: String(format: "%.1f", meanWPM)
                    )
                    statCard(
                        title: "Chars/Sec",
                        value: String(format: "%.2f", session.meanCharsPerSecond)
                    )
                    statCard(
                        title: "Total Backspaces",
                        value: "\(session.totalBackspaces)"
                    )
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Trial Table

    private var trialTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per-Phrase Breakdown")
                .font(.headline)

            ForEach(Array(sessionManager.completedTrials.enumerated()), id: \.offset) { index, trial in
                HStack {
                    Text("#\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 28, alignment: .leading)

                    Text(trial.targetText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(String(format: "%.0f%%", trial.accuracy * 100))
                        .font(.caption)
                        .foregroundColor(trial.accuracy > 0.8 ? .green : .orange)
                        .frame(width: 44, alignment: .trailing)

                    Text(String(format: "%.0f wpm", trial.wpm))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 54, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if index < sessionManager.completedTrials.count - 1 {
                    Divider()
                }
            }
        }
    }

    // MARK: - Export

    private var exportButtons: some View {
        VStack(spacing: 12) {
            Button(action: exportCSV) {
                Label("Export CSV", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Button(action: exportJSON) {
                Label("Export JSON", systemImage: "doc.badge.gearshape")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    private func exportCSV() {
        guard let session = sessionManager.currentSession else { return }
        let exporter = DataExporter()
        if let url = exporter.exportEventsCSV(
            session: session,
            trials: sessionManager.completedTrials,
            participant: sessionManager.participant
        ) {
            shareItem = ShareItem(url: url)
        }
    }

    private func exportJSON() {
        guard let session = sessionManager.currentSession else { return }
        let exporter = DataExporter()
        if let url = exporter.exportSessionJSON(
            session: session,
            trials: sessionManager.completedTrials,
            participant: sessionManager.participant
        ) {
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
