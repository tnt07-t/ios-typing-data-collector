import Foundation

final class DataExporter {

    // MARK: - CSV Export

    func exportEventsCSV(
        session: Session,
        trials: [Trial],
        participant: Participant?
    ) -> URL? {
        var rows: [String] = []

        // Header
        rows.append([
            "session_id", "participant_id", "participant_first", "participant_last",
            "trial_id", "trial_index", "target_text", "final_text",
            "trial_duration_ms", "trial_accuracy", "trial_wpm", "trial_cps",
            "trial_backspaces", "trial_inserts", "correct_chars", "total_target_chars"
        ].joined(separator: ","))

        for trial in trials {
            let row: [String] = [
                session.id.uuidString,
                session.participantId.uuidString,
                csvEscape(participant?.firstName ?? ""),
                csvEscape(participant?.lastName ?? ""),
                trial.id.uuidString,
                "\(trial.trialIndex)",
                csvEscape(trial.targetText),
                csvEscape(trial.finalText),
                String(format: "%.2f", trial.durationMs),
                String(format: "%.4f", trial.accuracy),
                String(format: "%.2f", trial.wpm),
                String(format: "%.4f", trial.charsPerSecond),
                "\(trial.backspaceCount)",
                "\(trial.insertCount)",
                "\(trial.correctChars)",
                "\(trial.totalTargetChars)"
            ]
            rows.append(row.joined(separator: ","))
        }

        return writeToTempFile(
            content: rows.joined(separator: "\n"),
            filename: "session_\(session.id.uuidString).csv"
        )
    }

    // MARK: - JSON Export

    func exportSessionJSON(
        session: Session,
        trials: [Trial],
        participant: Participant?
    ) -> URL? {
        var dict: [String: Any] = [:]

        dict["session_id"] = session.id.uuidString
        dict["participant_id"] = session.participantId.uuidString
        dict["started_at"] = ISO8601DateFormatter().string(from: session.startedAt)
        dict["ended_at"] = session.endedAt.map { ISO8601DateFormatter().string(from: $0) } as Any
        dict["total_trials"] = session.totalTrials
        dict["completed_trials"] = session.completedTrials
        dict["mean_accuracy"] = session.meanAccuracy
        dict["mean_chars_per_second"] = session.meanCharsPerSecond
        dict["total_backspaces"] = session.totalBackspaces

        if let p = participant {
            dict["participant"] = [
                "id": p.id.uuidString,
                "first_name": p.firstName,
                "last_name": p.lastName,
                "age": p.age as Any,
                "dominant_hand": p.dominantHand.rawValue,
                "device_model": p.deviceModel,
                "system_version": p.systemVersion,
                "screen_width_pt": p.screenWidthPt,
                "screen_height_pt": p.screenHeightPt,
                "app_version": p.appVersion
            ] as [String: Any]
        }

        dict["trials"] = trials.map { trial -> [String: Any] in
            [
                "id": trial.id.uuidString,
                "trial_index": trial.trialIndex,
                "target_text": trial.targetText,
                "final_text": trial.finalText,
                "started_at": ISO8601DateFormatter().string(from: trial.startedAt),
                "ended_at": trial.endedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "duration_ms": trial.durationMs,
                "backspace_count": trial.backspaceCount,
                "insert_count": trial.insertCount,
                "correct_chars": trial.correctChars,
                "total_target_chars": trial.totalTargetChars,
                "accuracy": trial.accuracy,
                "chars_per_second": trial.charsPerSecond,
                "wpm": trial.wpm
            ]
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return nil
        }

        return writeToTempFile(
            data: data,
            filename: "session_\(session.id.uuidString).json"
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
