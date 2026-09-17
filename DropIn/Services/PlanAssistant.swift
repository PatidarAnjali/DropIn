//
//  PlanAssistant.swift
//  DropIn
//
//  "Type one sentence, get a whole plan."
//
//  Uses Apple's on-device Foundation Models framework (Apple
//  Intelligence), so it's free, works offline, and nothing the user
//  types leaves the phone.
//
//  How it works:
//  1. `PlanSuggestion` describes the fields we want back. `@Generable`
//     makes the model return exactly that shape (no JSON parsing), and
//     `@Guide` limits values, e.g. category must be one of our four.
//  2. PlanTextParser then double-checks anything the text states
//     exactly (a clock time, a seat count), since small models can be
//     off with time math.
//  3. If Apple Intelligence isn't available (older iPhone, turned off,
//     still downloading) or anything fails, PlanTextParser fills in the
//     whole plan instead. Autofill always works.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum PlanAssistant {

    enum Source {
        case appleIntelligence
        case smartRules
    }

    /// True when the on-device model is ready to use.
    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    /// Builds a plan from `text`. Never throws: falls back to rules.
    static func draft(from text: String, now: Date = Date(), calendar: Calendar = .current) async -> (draft: PlanDraft, source: Source) {
        let fallback = PlanTextParser.parse(text, now: now, calendar: calendar)

        #if canImport(FoundationModels)
        if isAppleIntelligenceAvailable {
            do {
                let suggestion = try await askModel(text, now: now)
                let merged = merge(suggestion, into: fallback, text: text, now: now, calendar: calendar)
                return (merged, .appleIntelligence)
            } catch {
                print("PlanAssistant: model failed, using rules instead: \(error)")
            }
        }
        #endif

        return (fallback, .smartRules)
    }

    #if canImport(FoundationModels)

    private static let instructions = """
    You help people post casual hangout plans in a friends app called DropIn.
    Read what the user wrote and fill in the plan.
    - activity: a short, friendly version of what they're doing, under 50 characters. \
    Keep places they mention. Capitalize the first letter. No emojis, no hashtags.
    - category: coffee (coffee, tea, boba, cafes), food (meals, snacks, restaurants), \
    study (studying, homework, library, working), or walk (walks, hikes, runs, parks).
    - intent: capped if they mention a limited number of seats or spots; \
    quiet if they want to focus, study silently, or co-work; otherwise openDoor.
    - seats: the number of open seats if intent is capped, otherwise 0.
    - startsInMinutes: 0 if it's happening now. Otherwise minutes from the current time until it starts.
    - durationMinutes: how long it lasts. Use 60 if they don't say.
    """

    private static func askModel(_ text: String, now: Date) async throws -> PlanSuggestion {
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Current time: \(now.formatted(date: .omitted, time: .shortened))
        Plan: \(text)
        """
        let response = try await session.respond(to: prompt, generating: PlanSuggestion.self)
        return response.content
    }

    /// Model output, with rule-based values winning for anything the
    /// text states exactly.
    private static func merge(_ suggestion: PlanSuggestion, into fallback: PlanDraft, text: String, now: Date, calendar: Calendar) -> PlanDraft {
        let lower = text.lowercased()
        var draft = fallback

        let activity = suggestion.activity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activity.isEmpty {
            draft.activityText = String(activity.prefix(60))
        }
        draft.category = StatusCategory(rawValue: suggestion.category) ?? fallback.category

        // Intent and seats: an explicit number in the text always wins.
        if let seats = PlanTextParser.seatCount(in: lower) {
            draft.intent = .capped
            draft.seatLimit = seats
        } else {
            draft.intent = PlanIntent(rawValue: suggestion.intent) ?? fallback.intent
            draft.seatLimit = draft.intent == .capped
                ? min(max(suggestion.seats, PlanRules.seatRange.lowerBound), PlanRules.seatRange.upperBound)
                : nil
        }

        // Timing: exact phrases ("till 6", "in 30 min") win over the model's math.
        let timing = PlanTextParser.explicitTiming(in: lower, now: now, calendar: calendar)
        draft.startsInMinutes = timing.startsInMinutes
            ?? min(max(suggestion.startsInMinutes, PlanTextParser.startRange.lowerBound), PlanTextParser.startRange.upperBound)
        draft.durationMinutes = timing.durationMinutes
            ?? min(max(suggestion.durationMinutes, PlanTextParser.durationRange.lowerBound), PlanTextParser.durationRange.upperBound)

        return draft
    }

    #endif
}

#if canImport(FoundationModels)
/// The exact shape the on-device model fills in.
/// `nonisolated` because the model fills it in off the main thread.
@Generable
nonisolated struct PlanSuggestion {
    @Guide(description: "Short, friendly activity text under 50 characters")
    var activity: String

    @Guide(description: "The plan's category", .anyOf(["coffee", "food", "study", "walk"]))
    var category: String

    @Guide(description: "How the person wants company", .anyOf(["openDoor", "quiet", "capped"]))
    var intent: String

    @Guide(description: "Open seats when intent is capped, otherwise 0", .range(0...8))
    var seats: Int

    @Guide(description: "Minutes from now until the plan starts, 0 if it's happening now", .range(0...720))
    var startsInMinutes: Int

    @Guide(description: "How long the plan lasts in minutes", .range(15...720))
    var durationMinutes: Int
}
#endif
