import Foundation

final class DataExporter {

    // MARK: - Keystroke CSV Export

    func exportKeystrokesCSV(
        session: Session,
        events: [InputEventData],
        participant: Participant?
    ) -> URL? {
        var rows: [String] = []

        rows.append([
            "participant_first", "participant_last", "session_id",
            "event_type", "key_label",
            "tap_local_x", "tap_local_y",
            "key_width", "key_height",
            "key_row", "key_col",
            "expected_char", "actual_char", "corrected_char", "is_correct",
            "previous_key_label",
            "text_before",
            "timestamp_ms", "inter_key_interval_ms"
        ].joined(separator: ","))

        let sessionStart = session.startedAt

        for event in events {
            let keyColStr   = event.keyCol.map { "\($0)" } ?? ""
            let isCorrectStr = event.eventType == .delete ? "" : (event.isCorrect ? "1" : "0")
            let row: [String] = [
                csvEscape(participant?.firstName ?? ""),
                csvEscape(participant?.lastName  ?? ""),
                csvEscape(event.sessionId.uuidString),
                csvEscape(event.eventType.rawValue),
                csvEscape(event.keyLabel),
                String(format: "%.4f", event.tapLocalX),
                String(format: "%.4f", event.tapLocalY),
                String(format: "%.4f", event.keyWidth),
                String(format: "%.4f", event.keyHeight),
                csvEscape(event.keyRow),
                keyColStr,
                csvEscape(event.expectedChar),
                csvEscape(event.actualChar),
                csvEscape(event.correctedChar),
                isCorrectStr,
                csvEscape(event.previousKeyLabel),
                csvEscape(event.textBefore),
                String(format: "%.3f", event.timestamp.timeIntervalSince(sessionStart) * 1000),
                String(format: "%.3f", event.interKeyIntervalMs)
            ]
            rows.append(row.joined(separator: ","))
        }

        let first = participant?.firstName ?? "unknown"
        let last  = participant?.lastName  ?? "unknown"
        return writeToTempFile(
            content: rows.joined(separator: "\n"),
            filename: "keystrokes_\(first)_\(last).csv"
        )
    }

    // MARK: - Helpers

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func writeToTempFile(content: String, filename: String) -> URL? {
        guard let data = content.data(using: .utf8) else { return nil }
        return writeToTempFile(data: data, filename: filename)
    }

    private func writeToTempFile(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("DataExporter error: \(error)")
            return nil
        }
    }
}
