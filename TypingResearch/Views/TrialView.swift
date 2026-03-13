import SwiftUI

struct TrialView: View {
    var sessionManager: SessionManager
    var onTrialComplete: () -> Void

    @State private var typedText: String = ""
    @State private var lastTapInfo: TapInfo = .none

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar

            Spacer().frame(height: 24)

            targetTextView
                .padding(.horizontal, 16)

            Spacer()

            tapCoordinateBar
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            // Custom inline QWERTY keyboard, sized to match the system keyboard on this device
            CustomKeyboardView { key, tapInfo in
                handleKeyTap(key: key, tapInfo: tapInfo)
            }
            .frame(height: sessionManager.measuredKeyboardHeight)
        }
        .padding(.top, 16)
    }

    // MARK: - Key Tap Handler

    private func handleKeyTap(key: String, tapInfo: TapInfo) {
        let textBefore = typedText
        let textAfter: String
        let replacementString: String
        let eventType: InputEventType
        let rangeStart: Int
        let rangeLength: Int

        switch key {
        case "delete":
            guard !textBefore.isEmpty else { return }
            textAfter = String(textBefore.dropLast())
            replacementString = ""
            eventType = .delete
            rangeStart = textAfter.count
            rangeLength = 1
        case "space":
            textAfter = textBefore + " "
            replacementString = " "
            eventType = .insert
            rangeStart = textBefore.count
            rangeLength = 0
        default:
            textAfter = textBefore + key
            replacementString = key
            eventType = .insert
            rangeStart = textBefore.count
            rangeLength = 0
        }

        let eventData = sessionManager.buildKeyboardEventData(
            textBefore: textBefore,
            textAfter: textAfter,
            replacementString: replacementString,
            rangeStart: rangeStart,
            rangeLength: rangeLength,
            eventType: eventType,
            tapInfo: tapInfo
        )
        sessionManager.logEvent(eventData)
        typedText = textAfter
        lastTapInfo = tapInfo
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionManager.formattedRemaining)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(sessionManager.remainingSeconds < 30 ? .red : .primary)
                    .monospacedDigit()
                Text("words typed: \(typedText.split(separator: " ").count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f WPM", sessionManager.liveWPM))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                Text("live speed")
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
                                        index == cursorIndex
                                            ? Color.yellow.opacity(0.3) : Color.clear
                                    )
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: typedText) { _, _ in
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

    // MARK: - Tap Coordinate Bar

    private var tapCoordinateBar: some View {
        HStack(spacing: 0) {
            // Key label
            Text(lastTapInfo.keyLabel.isEmpty ? "—" : "[\(lastTapInfo.keyLabel)]")
                .frame(width: 36, alignment: .leading)

            Spacer()

            Group {
                coordCell(label: "local x", value: lastTapInfo.tapLocalX)
                coordCell(label: "local y", value: lastTapInfo.tapLocalY)
                coordCell(label: "norm x", value: lastTapInfo.tapNormX, decimals: 3)
                coordCell(label: "norm y", value: lastTapInfo.tapNormY, decimals: 3)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }

    private func coordCell(label: String, value: Double, decimals: Int = 1) -> some View {
        VStack(spacing: 1) {
            Text(String(format: decimals == 3 ? "%.3f" : "%.1f", value))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
        }
        .frame(minWidth: 52)
    }

    private func charColor(index: Int, char: Character, typedChars: [Character]) -> Color {
        if index < typedChars.count {
            return typedChars[index] == char ? .green : .red
        }
        return .primary
    }
}
