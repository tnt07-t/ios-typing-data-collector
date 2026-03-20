import SwiftUI

struct TrialView: View {
    var sessionManager: SessionManager
    var onTrialComplete: () -> Void

    @State private var typedText: String = ""
    @State private var lastTapInfo: TapInfo = .none

    private var keyboardHeight: CGFloat {
        max(180, sessionManager.measuredKeyboardHeight - sessionManager.safeAreaBottom)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar

            Spacer().frame(height: 24)

            targetTextView
                .padding(.horizontal, 16)

            tapCoordinateBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()

            CustomKeyboardView(overlayMode: false) { key, tapInfo in
                handleKeyTap(key: key, tapInfo: tapInfo)
            }
            .frame(height: keyboardHeight)
        }
        .padding(.top, 16)
        // Extend the keyboard background color into the bottom safe area so the
        // keyboard appears flush with the screen edge, matching the real iOS keyboard.
        .background(alignment: .bottom) {
            Color(red: 0.816, green: 0.827, blue: 0.851)
                .frame(height: keyboardHeight + sessionManager.safeAreaBottom)
                .ignoresSafeArea(edges: .bottom)
        }
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
        case "space", "return":
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
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(sessionManager.remainingSeconds < 30 ? .red : .primary)
                    .monospacedDigit()
                Text("words typed: \(typedText.split(separator: " ").count)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f WPM", sessionManager.liveWPM))
                    .font(.title3).fontWeight(.semibold)
                    .foregroundColor(.secondary).monospacedDigit()
                Text("live speed")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

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
                let typedChars  = Array(typedText)
                let cursorIndex = typedChars.count

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(targetChars.enumerated()), id: \.offset) { index, char in
                                Text(String(char))
                                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                                    .foregroundColor(charColor(index: index, typedCount: cursorIndex))
                                    .underline(index == cursorIndex)
                                    .background(
                                        index == cursorIndex
                                            ? Color.orange.opacity(0.25) : Color.clear
                                    )
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: typedText) { _, _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(cursorIndex, anchor: .center)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
            }
        }
    }

    private func charColor(index: Int, typedCount: Int) -> Color {
        if index < typedCount  { return .secondary }
        if index == typedCount { return .primary }
        return .primary.opacity(0.35)
    }

    // MARK: - Tap Coordinate Bar

    private var tapCoordinateBar: some View {
        HStack(spacing: 0) {
            Text(lastTapInfo.keyLabel.isEmpty ? "—" : "[\(lastTapInfo.keyLabel)]")
                .frame(width: 40, alignment: .leading)
            Spacer()
            coordCell(label: "local x", value: lastTapInfo.tapLocalX)
            coordCell(label: "local y", value: lastTapInfo.tapLocalY)
            coordCell(label: "norm x",  value: lastTapInfo.tapNormX, decimals: 3)
            coordCell(label: "norm y",  value: lastTapInfo.tapNormY, decimals: 3)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
    }

    private func coordCell(label: String, value: Double, decimals: Int = 1) -> some View {
        VStack(spacing: 1) {
            Text(String(format: decimals == 3 ? "%.3f" : "%.1f", value))
                .fontWeight(.medium).foregroundColor(.primary)
            Text(label).font(.system(size: 9, design: .monospaced))
        }
        .frame(minWidth: 52)
    }
}