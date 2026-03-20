import Foundation
import SwiftData
import Observation

// MARK: - TapInfo

struct TapInfo {
    let keyLabel: String
    let tapLocalX: Double
    let tapLocalY: Double
    let keyScreenX: Double
    let keyScreenY: Double
    let keyWidth: Double
    let keyHeight: Double

    var tapNormX: Double { keyWidth > 0 ? tapLocalX / keyWidth : 0 }
    var tapNormY: Double { keyHeight > 0 ? tapLocalY / keyHeight : 0 }

    static let none = TapInfo(
        keyLabel: "",
        tapLocalX: 0,
        tapLocalY: 0,
        keyScreenX: 0,
        keyScreenY: 0,
        keyWidth: 0,
        keyHeight: 0
    )
}

// MARK: - InputEventData (transient, not SwiftData)

struct InputEventData {
    let trialId: UUID
    let timestamp: Date
    let eventType: InputEventType
    let replacementString: String
    let rangeStart: Int
    let rangeLength: Int
    let textBefore: String
    let textAfter: String
    let expectedIndex: Int
    let expectedChar: String
    let actualChar: String
    let isCorrect: Bool
    let interKeyIntervalMs: Double
    let tapLocalX: Double
    let tapLocalY: Double
    let tapNormX: Double
    let tapNormY: Double
    let keyLabel: String
    let keyScreenX: Double
    let keyScreenY: Double
    let keyWidth: Double
    let keyHeight: Double
}

// MARK: - SessionManager

@Observable
final class SessionManager {
    // MARK: - State
    var participant: Participant?
    var currentSession: Session?
    var currentTrial: Trial?
    var currentTrialIndex: Int = 0
    var pendingEvents: [InputEventData] = []
    // All events across the session, kept for export
    var allEvents: [InputEventData] = []
    var isSessionActive: Bool = false
    var isTrialActive: Bool = false
    var isSessionComplete: Bool = false
    var completedTrials: [Trial] = []

    // Measured system keyboard height and safe area — set by ParticipantSetupView on first keyboard show
    var measuredKeyboardHeight: CGFloat = 291   // iPhone 16 default until measured
    var safeAreaBottom: CGFloat = 34            // iPhone 16 default until measured

    // Timer state
    var sessionDurationSeconds: Int = 300   // default 5 minutes
    var remainingSeconds: Int = 0
    var elapsedSeconds: Int = 0

    // Live metrics
    var liveTypedText: String = ""
    var liveWPM: Double = 0.0

    // Internal
    private var trialStartTime: Date?
    private var lastEventTimestamp: Date?
    private var modelContext: ModelContext?
    private var sessionTimer: Timer?
    private var timerStarted: Bool = false

    // Continuous mode: enough sentences to outlast any session
    private static let initialSentenceCount = 20

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Session Lifecycle

    func startSession(participant: Participant, durationSeconds: Int) {
        self.participant = participant
        self.sessionDurationSeconds = durationSeconds
        self.remainingSeconds = durationSeconds
        self.elapsedSeconds = 0

        let session = Session(participantId: participant.id)
        self.currentSession = session
        modelContext?.insert(session)

        isSessionActive = true
        isSessionComplete = false
        completedTrials = []
        currentTrialIndex = 0
        timerStarted = false
        allEvents = []

        // Timer starts on first keypress, not here
        startNextTrial()
    }

    private func startTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                self.elapsedSeconds += 1
            } else {
                self.timeExpired()
            }
        }
    }

    private func timeExpired() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        if isTrialActive {
            submitTrial(finalText: liveTypedText)
        }
        finalizeSession()
    }

    func startNextTrial() {
        guard isSessionActive, remainingSeconds > 0 else {
            finalizeSession()
            return
        }
        guard let session = currentSession else { return }

        let targetText = WordGenerator.randomSentences(count: Self.initialSentenceCount)
        let trial = Trial(
            sessionId: session.id,
            trialIndex: currentTrialIndex,
            targetText: targetText
        )
        currentTrial = trial
        modelContext?.insert(trial)

        pendingEvents = []
        liveTypedText = ""
        liveWPM = 0.0
        trialStartTime = Date()
        lastEventTimestamp = nil
        isTrialActive = true
    }

    // MARK: - Event Logging

    func logEvent(_ data: InputEventData) {
        // Start countdown on first keystroke
        if !timerStarted {
            timerStarted = true
            trialStartTime = Date()
            startTimer()
        }

        pendingEvents.append(data)
        allEvents.append(data)

        liveTypedText = data.textAfter

        // Keep target text well ahead of where the user is typing
        if let trial = currentTrial {
            let remaining = trial.targetText.count - data.textAfter.count
            if remaining < 200 {
                trial.targetText += " " + WordGenerator.randomSentences(count: 8)
            }
        }

        if let start = trialStartTime {
            let elapsed = Date().timeIntervalSince(start) * 1000.0
            liveWPM = MetricsComputer.wpm(charCount: data.textAfter.count, durationMs: elapsed)
        }

        let event = InputEvent(
            trialId: data.trialId,
            timestamp: data.timestamp,
            eventType: data.eventType,
            replacementString: data.replacementString,
            rangeStart: data.rangeStart,
            rangeLength: data.rangeLength,
            textBefore: data.textBefore,
            textAfter: data.textAfter,
            expectedIndex: data.expectedIndex,
            expectedChar: data.expectedChar,
            actualChar: data.actualChar,
            isCorrect: data.isCorrect,
            interKeyIntervalMs: data.interKeyIntervalMs,
            tapLocalX: data.tapLocalX,
            tapLocalY: data.tapLocalY,
            tapNormX: data.tapNormX,
            tapNormY: data.tapNormY,
            keyLabel: data.keyLabel,
            keyScreenX: data.keyScreenX,
            keyScreenY: data.keyScreenY,
            keyWidth: data.keyWidth,
            keyHeight: data.keyHeight
        )
        modelContext?.insert(event)
        // Send to research backend (non-blocking, batched)
        if let session = currentSession, let participant = participant {
            BackendClient.shared.enqueue(
                event: data,
                sessionId: session.id,
                participantId: participant.id
            )
        }
    }

    func buildEventData(
        textBefore: String,
        textAfter: String,
        replacementString: String,
        rangeStart: Int,
        rangeLength: Int,
        eventType: InputEventType
    ) -> InputEventData {
        return buildKeyboardEventData(
            textBefore: textBefore,
            textAfter: textAfter,
            replacementString: replacementString,
            rangeStart: rangeStart,
            rangeLength: rangeLength,
            eventType: eventType,
            tapInfo: .none
        )
    }

    func buildKeyboardEventData(
        textBefore: String,
        textAfter: String,
        replacementString: String,
        rangeStart: Int,
        rangeLength: Int,
        eventType: InputEventType,
        tapInfo: TapInfo
    ) -> InputEventData {
        guard let trial = currentTrial else {
            fatalError("No active trial")
        }

        let now = Date()
        let iki: Double
        if let last = lastEventTimestamp {
            iki = now.timeIntervalSince(last) * 1000.0
        } else {
            iki = 0.0
        }
        lastEventTimestamp = now

        let targetChars = Array(trial.targetText)
        let expectedIndex = rangeStart
        let expectedChar: String
        if expectedIndex >= 0 && expectedIndex < targetChars.count {
            expectedChar = String(targetChars[expectedIndex])
        } else {
            expectedChar = ""
        }

        let actualChar: String
        if eventType == .insert || eventType == .replace {
            actualChar = replacementString.isEmpty ? "" : String(replacementString.prefix(1))
        } else {
            actualChar = ""
        }

        let isCorrect = !actualChar.isEmpty && actualChar == expectedChar

        return InputEventData(
            trialId: trial.id,
            timestamp: now,
            eventType: eventType,
            replacementString: replacementString,
            rangeStart: rangeStart,
            rangeLength: rangeLength,
            textBefore: textBefore,
            textAfter: textAfter,
            expectedIndex: expectedIndex,
            expectedChar: expectedChar,
            actualChar: actualChar,
            isCorrect: isCorrect,
            interKeyIntervalMs: iki,
            tapLocalX: tapInfo.tapLocalX,
            tapLocalY: tapInfo.tapLocalY,
            tapNormX: tapInfo.tapNormX,
            tapNormY: tapInfo.tapNormY,
            keyLabel: tapInfo.keyLabel,
            keyScreenX: tapInfo.keyScreenX,
            keyScreenY: tapInfo.keyScreenY,
            keyWidth: tapInfo.keyWidth,
            keyHeight: tapInfo.keyHeight
        )
    }

    // MARK: - Trial Submission

    func submitTrial(finalText: String) {
        guard let trial = currentTrial, let start = trialStartTime else { return }

        let endTime = Date()
        let durationMs = endTime.timeIntervalSince(start) * 1000.0

        let cps = MetricsComputer.charsPerSecond(charCount: finalText.count, durationMs: durationMs)
        let wpmVal = MetricsComputer.wpm(charCount: finalText.count, durationMs: durationMs)

        let backspaces = pendingEvents.filter { $0.eventType == .delete }.count
        let inserts = pendingEvents.filter { $0.eventType == .insert }
        let correctChars = inserts.filter { $0.isCorrect }.count
        // Per-keystroke accuracy: fraction of insert taps that hit the correct key
        let accuracy = inserts.isEmpty ? 0.0 : Double(correctChars) / Double(inserts.count)

        trial.finalText = finalText
        trial.endedAt = endTime
        trial.durationMs = durationMs
        trial.backspaceCount = backspaces
        trial.insertCount = inserts.count
        trial.correctChars = correctChars
        trial.totalTargetChars = trial.targetText.count
        trial.accuracy = accuracy
        trial.charsPerSecond = cps
        trial.wpm = wpmVal

        completedTrials.append(trial)
        currentTrialIndex += 1
        isTrialActive = false

        if let session = currentSession {
            session.completedTrials = currentTrialIndex
            session.totalTrials = currentTrialIndex
        }
    }

    // MARK: - Session Finalization

    func finalizeSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil

        guard let session = currentSession else { return }

        session.endedAt = Date()
        session.completedTrials = completedTrials.count
        session.totalTrials = completedTrials.count

        if !completedTrials.isEmpty {
            session.meanAccuracy = completedTrials.map(\.accuracy).reduce(0, +) / Double(completedTrials.count)
            session.meanCharsPerSecond = completedTrials.map(\.charsPerSecond).reduce(0, +) / Double(completedTrials.count)
            session.totalBackspaces = completedTrials.map(\.backspaceCount).reduce(0, +)
        }

        isSessionActive = false
        isTrialActive = false
        isSessionComplete = true
        BackendClient.shared.flush()
        try? modelContext?.save()
    }

    // MARK: - Reset

    // Restart immediately with the same participant and duration — stays in session flow
    func restartSameSession() {
        guard let existingParticipant = participant else { return }
        let duration = sessionDurationSeconds
        reset()
        startSession(participant: existingParticipant, durationSeconds: duration)
    }

    func reset() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        participant = nil
        currentSession = nil
        currentTrial = nil
        currentTrialIndex = 0
        pendingEvents = []
        allEvents = []
        isSessionActive = false
        isTrialActive = false
        isSessionComplete = false
        completedTrials = []
        liveTypedText = ""
        liveWPM = 0.0
        trialStartTime = nil
        lastEventTimestamp = nil
    }

    // MARK: - Formatted time

    var formattedRemaining: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var formattedDuration: String {
        let m = sessionDurationSeconds / 60
        let s = sessionDurationSeconds % 60
        if s == 0 { return "\(m) min" }
        return String(format: "%d:%02d", m, s)
    }
}
