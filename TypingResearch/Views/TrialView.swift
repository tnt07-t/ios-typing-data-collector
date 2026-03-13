import SwiftUI

struct TrialView: View {
    var sessionManager: SessionManager
    var onTrialComplete: () -> Void

    @State private var typedText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: timer + WPM
            topBar

            // Time progress bar
            progressBar

            Spacer().frame(height: 24)

            // Target text with per-character color highlight
            targetTextView
                .padding(.horizontal, 16)

            Spacer().frame(height: 32)

            // Logging text field
            if let trial = sessionManager.currentTrial {
                LoggingTextField(
                    text: $typedText,
                    placeholder: "Type the phrase, then press Return...",
                    onEvent: { eventData in
                        sessionManager.logEvent(eventData)
                    },
                    buildEventData: { textBefore, textAfter, replacement, rangeStart, rangeLength, eventType in
                        sessionManager.buildEventData(
                            textBefore: textBefore,
                            textAfter: textAfter,
                            replacementString: replacement,
                            rangeStart: rangeStart,
                            rangeLength: rangeLength,
                            eventType: eventType
                        )
                    },
                )
                .frame(height: 44)
                .padding(.horizontal, 16)
                .id(trial.id)
            }

            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Phrase #\(sessionManager.currentTrialIndex + 1)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(sessionManager.completedTrials.count) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(sessionManager.formattedRemaining)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(sessionManager.remainingSeconds < 30 ? .red : .primary)
                    .monospacedDigit()
                Text(String(format: "%.0f WPM", sessionManager.liveWPM))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar (time-based)

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(height: 4)

                let progress = sessionManager.sessionDurationSeconds > 0
                    ? CGFloat(sessionManager.remainingSeconds) / CGFloat(sessionManager.sessionDurationSeconds)
                    : 0
                Rectangle()
                    .fill(sessionManager.remainingSeconds < 30 ? Color.red : Color.orange)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.linear(duration: 1), value: sessionManager.remainingSeconds)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Target Text View

    private var targetTextView: some View {
        Group {
            if let trial = sessionManager.currentTrial {
                let targetChars = Array(trial.targetText)
                let typedChars = Array(typedText)
                let cursorIndex = typedChars.count

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(targetChars.enumerated()), id: \.offset) { index, char in
                                Text(String(char))
                                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                                    .foregroundColor(charColor(index: index, char: char, typedChars: typedChars))
                                    .underline(index == cursorIndex)
                                    .background(
                                        index == cursorIndex ?
                                        Color.yellow.opacity(0.3) : Color.clear
                                    )
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: typedText) { _, _ in
                        // Keep cursor centered in the scroll view
                        if cursorIndex >= 0 {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(cursorIndex, anchor: .center)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }

    private func charColor(index: Int, char: Character, typedChars: [Character]) -> Color {
        if index < typedChars.count {
            return typedChars[index] == char ? .green : .red
        }
        return .primary
    }

    private func handleNext() {
        sessionManager.submitTrial(finalText: typedText)
        typedText = ""
        onTrialComplete()
    }
}
