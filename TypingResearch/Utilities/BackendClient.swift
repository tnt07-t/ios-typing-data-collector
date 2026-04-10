import Foundation

// MARK: - BackendClient
//
// Set isEnabled = true and endpointURL before running a study.
// While isEnabled = false everything still works — data saves locally only.

final class BackendClient {
    static let shared = BackendClient()
    private init() {}

    var isEnabled: Bool = false
    var endpointURL: String = "https://your-research-server.com/api/v1/keystrokes"
    var studyId: String = "study_001"

    private var buffer: [KeystrokeRecord] = []
    private let batchSize: Int = 50
    private let sendQueue = DispatchQueue(label: "com.research.backendclient", qos: .utility)

    func enqueue(event: InputEventData, sessionId: UUID, participantId: UUID) {
        guard isEnabled else { return }
        let record = KeystrokeRecord(from: event, sessionId: sessionId,
                                     participantId: participantId, studyId: studyId)
        sendQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(record)
            if self.buffer.count >= self.batchSize {
                let batch = Array(self.buffer)
                self.buffer.removeAll(keepingCapacity: true)
                self.post(batch)
            }
        }
    }

    func flush() {
        sendQueue.async { [weak self] in
            guard let self, !self.buffer.isEmpty else { return }
            let batch = Array(self.buffer)
            self.buffer.removeAll(keepingCapacity: true)
            self.post(batch)
        }
    }

    private func post(_ records: [KeystrokeRecord]) {
        guard let url = URL(string: endpointURL) else { return }
        guard let body = try? JSONEncoder().encode(records) else { return }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    print("BackendClient: HTTP \(http.statusCode)")
                }
            } catch {
                print("BackendClient: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - KeystrokeRecord

struct KeystrokeRecord: Encodable {
    let studyId: String
    let participantId: String
    let sessionId: String
    let promptId: String
    let timestampISO: String
    let eventType: String
    let keyLabel: String
    let tapLocalX: Double
    let tapLocalY: Double
    let keyWidth: Double
    let keyHeight: Double
    let keyRow: String
    let keyCol: Int?
    let expectedChar: String
    let actualChar: String
    let correctedChar: String
    let isCorrect: Bool
    let previousKeyLabel: String
    let interKeyIntervalMs: Double

    init(from event: InputEventData, sessionId: UUID, participantId: UUID, studyId: String) {
        let iso = ISO8601DateFormatter()
        self.studyId = studyId
        self.participantId = participantId.uuidString
        self.sessionId = sessionId.uuidString
        self.promptId = event.trialId.uuidString
        self.timestampISO = iso.string(from: event.timestamp)
        self.eventType = event.eventType.rawValue
        self.keyLabel = event.keyLabel
        self.tapLocalX = event.tapLocalX
        self.tapLocalY = event.tapLocalY
        self.keyWidth = event.keyWidth
        self.keyHeight = event.keyHeight
        self.keyRow = event.keyRow
        self.keyCol = event.keyCol
        self.expectedChar = event.expectedChar
        self.actualChar = event.actualChar
        self.correctedChar = event.correctedChar
        self.isCorrect = event.isCorrect
        self.previousKeyLabel = event.previousKeyLabel
        self.interKeyIntervalMs = event.interKeyIntervalMs
    }
}