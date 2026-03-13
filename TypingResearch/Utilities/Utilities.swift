import Foundation
import UIKit

// MARK: - DeviceInfo

struct DeviceInfo {
    static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    static var systemVersion: String {
        UIDevice.current.systemVersion
    }

    static var screenWidthPt: Double {
        Double(UIScreen.main.bounds.width)
    }

    static var screenHeightPt: Double {
        Double(UIScreen.main.bounds.height)
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - WordGenerator

struct WordGenerator {
    static let wordPool: [String] = [
        "time", "year", "people", "way", "day", "man", "woman", "child", "world", "life",
        "hand", "part", "place", "case", "week", "company", "system", "program", "question", "work",
        "government", "number", "night", "point", "home", "water", "room", "mother", "area", "money",
        "story", "fact", "month", "lot", "right", "study", "book", "eye", "job", "word",
        "business", "issue", "side", "kind", "head", "house", "service", "friend", "father", "power",
        "hour", "game", "line", "end", "among", "next", "large", "need", "open", "public",
        "ground", "city", "school", "black", "white", "start", "turn", "class", "small", "level",
        "form", "road", "town", "change", "food", "court", "state", "learn", "plant", "cover",
        "sign", "half", "phone", "front", "press", "body", "whole", "paper", "clear", "force",
        "long", "move", "short", "bring", "bank", "check", "carry", "value", "keep", "drive",
        "table", "light", "voice", "power", "heart", "since", "price", "field", "sound", "watch",
        "floor", "horse", "teach", "north", "south", "east", "west", "color", "blood", "fire",
        "stone", "sense", "green", "river", "music", "party", "chair", "fruit", "youth", "glass",
        "smoke", "speak", "trade", "heavy", "issue", "ocean", "cross", "speed", "train", "space",
        "prove", "stand", "wrong", "young", "third", "truth", "great", "ready", "often", "order"
    ]

    static func randomString(wordCount: Int = 8) -> String {
        var words: [String] = []
        var available = wordPool.shuffled()
        for i in 0..<wordCount {
            words.append(available[i % available.count])
        }
        return words.joined(separator: " ")
    }
}

// MARK: - MetricsComputer

struct MetricsComputer {
    /// Positional character match accuracy at submission
    static func accuracy(target: String, typed: String) -> Double {
        guard !target.isEmpty else { return 0.0 }
        let targetChars = Array(target)
        let typedChars = Array(typed)
        var correct = 0
        let minLen = min(targetChars.count, typedChars.count)
        for i in 0..<minLen {
            if targetChars[i] == typedChars[i] {
                correct += 1
            }
        }
        return Double(correct) / Double(targetChars.count)
    }

    /// WPM = (chars / 5) / (durationSec / 60)
    static func wpm(charCount: Int, durationMs: Double) -> Double {
        guard durationMs > 0 else { return 0.0 }
        let durationSec = durationMs / 1000.0
        let words = Double(charCount) / 5.0
        return words / (durationSec / 60.0)
    }

    /// Characters per second
    static func charsPerSecond(charCount: Int, durationMs: Double) -> Double {
        guard durationMs > 0 else { return 0.0 }
        return Double(charCount) / (durationMs / 1000.0)
    }

    /// Count positionally correct characters
    static func correctCharCount(target: String, typed: String) -> Int {
        let targetChars = Array(target)
        let typedChars = Array(typed)
        var correct = 0
        let minLen = min(targetChars.count, typedChars.count)
        for i in 0..<minLen {
            if targetChars[i] == typedChars[i] {
                correct += 1
            }
        }
        return correct
    }
}
