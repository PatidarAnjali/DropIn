//
//  PlanTextParser.swift
//  DropIn
//
//  Turns a casual sentence like "library grind till 6, quiet pls" into
//  a filled-in plan, using keyword and pattern matching.
//
//  It has two jobs:
//  1. Fallback when Apple Intelligence isn't available (older iPhones,
//     or it's turned off), so autofill works on every phone.
//  2. Precision check for the AI. Small on-device models are great at
//     understanding intent but can be sloppy with clock math, so when
//     the text states an exact time ("till 6", "in 30 min") or seat
//     count ("room for 2"), these rules win.
//
//  Everything takes `now` and `calendar` as inputs so tests can use a
//  fixed time (see DropInTests/PlanTextParserTests.swift).
//

import Foundation

/// A suggested plan, filled in from text. The create sheet copies these
/// values into its form so the user can review before posting.
struct PlanDraft: Equatable {
    var activityText: String
    var category: StatusCategory
    var intent: PlanIntent
    /// Only set when `intent` is `.capped`.
    var seatLimit: Int?
    /// 0 means "right now".
    var startsInMinutes: Int
    var durationMinutes: Int
}

enum PlanTextParser {
    static let defaultDurationMinutes = 60
    static let durationRange = 15...720
    static let startRange = 0...(24 * 60)

    // MARK: Full parse (fallback)

    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> PlanDraft {
        let lower = text.lowercased()
        let seats = seatCount(in: lower)
        let timing = explicitTiming(in: lower, now: now, calendar: calendar)

        let intent: PlanIntent
        if seats != nil {
            intent = .capped
        } else if mentionsQuiet(lower) {
            intent = .quiet
        } else {
            intent = .openDoor
        }

        return PlanDraft(
            activityText: tidy(text),
            category: category(in: lower) ?? .coffee,
            intent: intent,
            seatLimit: seats,
            startsInMinutes: timing.startsInMinutes ?? 0,
            durationMinutes: timing.durationMinutes ?? defaultDurationMinutes
        )
    }

    // MARK: Category

    private static let categoryKeywords: [(StatusCategory, [String])] = [
        (.coffee, ["coffee", "cafe", "café", "latte", "espresso", "starbucks", "tims", "tim hortons", "boba", "bubble tea", "tea", "matcha"]),
        (.food, ["dinner", "lunch", "breakfast", "brunch", "eat", "eating", "food", "pizza", "sushi", "ramen", "chipotle", "burger", "burgers", "tacos", "snack", "snacks", "restaurant"]),
        (.study, ["study", "studying", "library", "homework", "exam", "exams", "midterm", "class", "lecture", "cowork", "co-work", "coworking", "co-working", "laptop", "assignment"]),
        (.walk, ["walk", "walking", "hike", "hiking", "stroll", "run", "running", "jog", "park", "trail"]),
    ]

    /// The category whose keyword appears earliest in the text, so
    /// "boba after class" is coffee, not study.
    static func category(in lower: String) -> StatusCategory? {
        var best: (category: StatusCategory, position: Int)?
        for (category, words) in categoryKeywords {
            for word in words {
                guard let range = firstMatch(of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", in: lower)?.range else { continue }
                if best == nil || range.location < best!.position {
                    best = (category, range.location)
                }
            }
        }
        return best?.category
    }

    // MARK: Intent

    private static let quietWords = ["quiet", "silent", "silence", "focus", "focusing", "grind", "grinding", "lock in", "locked in", "no talking", "headphones", "cowork", "co-work", "coworking", "co-working", "bring a laptop", "bring your laptop"]

    static func mentionsQuiet(_ lower: String) -> Bool {
        quietWords.contains { firstMatch(of: "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b", in: lower) != nil }
    }

    private static let numberWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "a couple": 2, "couple": 2]
    private static let numberPattern = "(\\d+|one|two|three|four|five|six|seven|eight|a couple|couple)"

    /// "only 2 seats", "3 spots left", "room for two", "space for 4".
    static func seatCount(in lower: String) -> Int? {
        let patterns = [
            "\(numberPattern)\\s+(?:open\\s+|more\\s+|free\\s+|extra\\s+)?(?:seats?|spots?|spaces?|chairs?)",
            "(?:room|space|seats?|spots?)\\s+for\\s+\(numberPattern)",
        ]
        for pattern in patterns {
            if let match = firstMatch(of: pattern, in: lower),
               let raw = substring(lower, match.range(at: 1)),
               let value = Int(raw) ?? numberWords[raw] {
                return min(max(value, PlanRules.seatRange.lowerBound), PlanRules.seatRange.upperBound)
            }
        }
        return nil
    }

    // MARK: Timing

    struct Timing: Equatable {
        var startsInMinutes: Int?
        var durationMinutes: Int?
    }

    /// Only the timing the text actually states. Anything not mentioned
    /// stays nil so the AI's guess (or a default) can be used instead.
    static func explicitTiming(in lower: String, now: Date, calendar: Calendar) -> Timing {
        var timing = Timing()

        // Start: "in 30 min", "in an hour", "in half an hour"
        if let match = firstMatch(of: "\\bin\\s+(half an|an?|\\d+(?:\\.\\d+)?)\\s*(minutes?|mins?|m|hours?|hrs?|h)\\b", in: lower) {
            timing.startsInMinutes = minutes(amount: substring(lower, match.range(at: 1)), unit: substring(lower, match.range(at: 2)))
        }
        // Start: "at 7", "at 7:30pm"
        else if let match = firstMatch(of: "\\bat\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\b", in: lower),
                let date = clockTime(match, in: lower, after: now, calendar: calendar) {
            timing.startsInMinutes = Int(date.timeIntervalSince(now) / 60)
        }

        let start = now.addingTimeInterval(Double(timing.startsInMinutes ?? 0) * 60)

        // End: "till 6", "until 9:30pm"
        if let match = firstMatch(of: "\\b(?:till|til|until|untill|'til)\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\b", in: lower),
           let end = clockTime(match, in: lower, after: start, calendar: calendar) {
            timing.durationMinutes = Int(end.timeIntervalSince(start) / 60)
        }
        // Duration: "for 2 hours", "for an hour", "for 45 min"
        else if let match = firstMatch(of: "\\bfor\\s+(half an|an?|\\d+(?:\\.\\d+)?)\\s*(minutes?|mins?|m|hours?|hrs?|h)\\b", in: lower) {
            timing.durationMinutes = minutes(amount: substring(lower, match.range(at: 1)), unit: substring(lower, match.range(at: 2)))
        }

        if let start = timing.startsInMinutes {
            timing.startsInMinutes = min(max(start, startRange.lowerBound), startRange.upperBound)
        }
        if let duration = timing.durationMinutes {
            timing.durationMinutes = min(max(duration, durationRange.lowerBound), durationRange.upperBound)
        }
        return timing
    }

    private static func minutes(amount: String?, unit: String?) -> Int? {
        guard let amount, let unit else { return nil }
        let value: Double
        switch amount {
        case "a", "an": value = 1
        case "half an": value = 0.5
        default:
            guard let number = Double(amount) else { return nil }
            value = number
        }
        let isHours = unit.hasPrefix("h")
        // "in half an minute" isn't a thing; treat "half an" as hours.
        return Int((isHours || amount == "half an" ? value * 60 : value).rounded())
    }

    /// The soonest time after `reference` that matches a clock time like
    /// "6" or "9:30pm". Without am/pm, both are tried, so "till 6" at
    /// 3:40pm means 6pm, and "at 8" at 9pm means 8am tomorrow.
    private static func clockTime(_ match: NSTextCheckingResult, in lower: String, after reference: Date, calendar: Calendar) -> Date? {
        guard let hourText = substring(lower, match.range(at: 1)), var hour = Int(hourText), (0...23).contains(hour) else { return nil }
        let minute = substring(lower, match.range(at: 2)).flatMap { Int($0) } ?? 0
        guard (0...59).contains(minute) else { return nil }
        let meridiem = substring(lower, match.range(at: 3))

        var hours: [Int]
        if let meridiem, hour <= 12 {
            if hour == 12 { hour = 0 }
            hours = [meridiem == "pm" ? hour + 12 : hour]
        } else if hour <= 12 {
            hours = [hour % 12, hour % 12 + 12]
        } else {
            hours = [hour]
        }

        let candidates = hours.compactMap { h -> Date? in
            guard let today = calendar.date(bySettingHour: h, minute: minute, second: 0, of: reference) else { return nil }
            return today > reference ? today : calendar.date(byAdding: .day, value: 1, to: today)
        }
        return candidates.min()
    }

    // MARK: Text helpers

    /// Trims and capitalizes the first letter.
    static func tidy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }

    private static func firstMatch(of pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func substring(_ text: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
