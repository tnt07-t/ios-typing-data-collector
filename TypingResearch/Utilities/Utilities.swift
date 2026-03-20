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
    /// Corpus of natural sentences optimized for HCI typing data collection.
    /// Every sentence contains at least 2 of {j, k, q, v, x, z} for even rare-letter coverage.
    /// Mix of statements, apostrophe sentences, questions, and commands for rhythm variety.
    static let sentencePool: [String] = [

        // MARK: Everyday statements
        "she quickly packed her jacket and jogged across campus to the lecture hall.",
        "jake fixed the kitchen valve and left the tools on the counter before leaving.",
        "my roommate baked a spicy vegetable pizza while i vacuumed the kitchen floor.",
        "he grabbed his keys and jacket, then jogged over to the next building.",
        "the bakery next to the quad opens very early and serves excellent coffee.",
        "we kept a record of every expense and split the grocery bill evenly.",
        "the delivery van arrived two days late, but every item was carefully packed.",
        "she kept a journal and wrote vivid notes every quiet evening before bed.",
        "the morning light moved across the kitchen and brightened every dark corner.",
        "a warm breeze moved across the lake just before the sky went dark.",
        "the bus service was revised after the holiday, leaving quite a few riders confused.",
        "he fixed the leaky valve using just a wrench and a bit of extra tape.",
        "the kids drew vivid pictures and colored every page with bright markers.",
        "we stopped to check the map and kept track of every fork in the trail.",
        "she revised her key points and practiced her speech every morning before work.",
        "the valley trail winds through pine forests and ends at a rocky overlook.",
        "the jazz venue hosted a live event just before it closed for the week.",
        "the lake was very quiet just before the kayakers arrived at dawn.",
        "every volunteer organized each garden zone and kept the flowers watered all week.",
        "we grilled fresh vegetables and served them with a zesty lemon dressing.",
        "the bridge was closed for repairs, so every driver took a longer route.",
        "she left her jacket on the chair and forgot to take the key with her.",
        "the venue was booked until five, so we moved the meeting to a nearby cafe.",
        "we watched the squirrels race across the vivid green park near the clock tower.",

        // MARK: Apostrophe sentences (adjacent-key error data)
        "i don't think she's planning to move to a new job quite yet.",
        "it's been a very long week, but we've kept every task on track.",
        "he couldn't find the key, so he checked every jacket pocket very carefully.",
        "she didn't expect the quiz to cover six vocabulary units in one exam.",
        "i've just realized i haven't reviewed the final version of the document.",
        "we're not quite finished, but we've covered every key section already.",
        "the store wasn't stocking the exact flavor, so we picked a very close option.",
        "he'd already locked the van, but she asked him to check the back seat.",

        // MARK: Sentences with heavy rare-letter coverage
        "jack quickly zipped his jacket, joined the queue, and left the building.",
        "the exhibit mixed vintage jazz recordings with old photographs and wax figures.",
        "quinn solved the complex equation and explained every step to the review group.",
        "every student received a revised version of the exam and kept a copy on file.",
        "xavier asked if the extra package had arrived and whether the valve was intact.",
        "zach packed six textbooks into his backpack and locked the dorm before leaving.",
        "jenny sent six vivid photographs from the quiet coastal village to her family.",
        "the judge reviewed each objection very quickly and moved the case forward.",
        "my colleague wore a black jacket and packed extra voltage converters for the trip.",
        "her younger brother plays the saxophone in the jazz quartet every weekend.",
        "both students checked the quiz and reviewed every exam section before leaving.",
        "we packed fresh fruit, six juice boxes, and a very large vegetable wrap.",
        "the volunteer fixed the broken projector just before the keynote speech began.",

        // MARK: Questions
        "did you save a backup of every version before you closed the project file?",
        "can you pick up some milk and check if the bakery has any fresh rolls?",
        "have you reviewed the key vocabulary from the first six chapters yet?",
        "do you know if the exam will cover just the vocabulary from unit five?",
        "is there a quick fix for the broken valve before the review session starts?",
        "could you check whether the jazz venue is still open on sunday evenings?",
        "did xavier mention the project deliverables or the revised timeline at the meeting?",
        "would you like to review the key objectives before we submit the final version?",

        // MARK: Commands
        "check your work, save a backup copy, and close every extra tab you have open.",
        "lock the door, close every window, and leave the key on the kitchen table.",
        "save your work, back up every file, and shut down before you leave for the evening.",
        "check the weather forecast and bring a jacket if you're leaving after six.",
        "jot down the exact question, note the key details, and review your sources.",
        "keep your journal, a water bottle, and your student id in your jacket pocket.",
        "send the revised draft to every team member and ask for feedback by friday.",
        "make sure the volume is low and switch off every extra light before leaving.",

        // MARK: Compound and contrast sentences
        "the venue was very busy, but the event coordinator kept everything moving well.",
        "she expected an easy quiz, yet the questions covered six complex vocabulary topics.",
        "he took the shortcut across the park, but it added extra time to the journey.",
        "the plan looked solid at first, but we revised every key section before submitting.",
        "the event was small, yet the keynote left a very vivid impression on everyone.",
        "the quiz was short, but it covered vocabulary from six very different units.",
    ]

    /// Returns `sentenceCount` shuffled sentences joined by spaces.
    static func randomSentences(count: Int) -> String {
        var pool = sentencePool.shuffled()
        var result: [String] = []
        var idx = 0
        for _ in 0..<count {
            result.append(pool[idx % pool.count])
            idx += 1
            if idx == pool.count { pool = sentencePool.shuffled() }
        }
        return result.joined(separator: " ")
    }

    /// Legacy shim — converts a rough word count into a sentence count and delegates.
    static func randomString(wordCount: Int = 8) -> String {
        let sentenceCount = max(1, wordCount / 8)
        return randomSentences(count: sentenceCount)
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
