//
//  PlanTextParserTests.swift
//  DropInTests
//
//  The rule-based autofill (used when Apple Intelligence isn't
//  available, and to double-check exact times and seat counts).
//  Uses a fixed clock, Wednesday 3:40 PM, so results never change.
//

import Foundation
import Testing
@testable import DropIn

@MainActor
@Suite("Plan text parser")
struct PlanTextParserTests {

    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 15, minute: 40))!
    }

    func parse(_ text: String) -> PlanDraft {
        PlanTextParser.parse(text, now: now, calendar: calendar)
    }

    @Test("Dinner with limited room becomes a capped food plan")
    func cappedDinner() {
        let draft = parse("dinner at chipotle, only have room for 2")
        #expect(draft.category == .food)
        #expect(draft.intent == .capped)
        #expect(draft.seatLimit == 2)
        #expect(draft.startsInMinutes == 0)
        #expect(draft.durationMinutes == 60)
    }

    @Test("\"till 6\" at 3:40 PM means it lasts until 6 PM")
    func quietStudyUntilSix() {
        let draft = parse("library grind till 6, quiet pls")
        #expect(draft.category == .study)
        #expect(draft.intent == .quiet)
        #expect(draft.seatLimit == nil)
        #expect(draft.durationMinutes == 140)
    }

    @Test("Start and length can both be relative")
    func relativeTiming() {
        let draft = parse("walk in 30 min for an hour")
        #expect(draft.category == .walk)
        #expect(draft.startsInMinutes == 30)
        #expect(draft.durationMinutes == 60)
    }

    @Test("\"at 8 until 10\" picks 8 PM tonight, not 8 AM tomorrow")
    func clockTimes() {
        let draft = parse("study session at 8 until 10")
        #expect(draft.startsInMinutes == 260)
        #expect(draft.durationMinutes == 120)
    }

    @Test("The earliest keyword decides the category")
    func earliestKeywordWins() {
        #expect(parse("getting boba after class").category == .coffee)
    }

    @Test("Seat counts can be written as numbers or words", arguments: [
        ("ramen, 3 spots left", 3),
        ("lunch, room for two", 2),
        ("pizza, a couple seats open", 2),
        ("huge table, 20 seats", 8), // clamped to the max
    ])
    func seatCounts(text: String, expected: Int) {
        let draft = parse(text)
        #expect(draft.intent == .capped)
        #expect(draft.seatLimit == expected)
    }

    @Test("Plain text defaults to an open-door plan starting now")
    func defaults() {
        let draft = parse("  hanging out  ")
        #expect(draft.activityText == "Hanging out")
        #expect(draft.intent == .openDoor)
        #expect(draft.startsInMinutes == 0)
        #expect(draft.durationMinutes == PlanTextParser.defaultDurationMinutes)
    }

    @Test("Only stated timing is reported, so the AI can fill the rest")
    func explicitTimingOnly() {
        let timing = PlanTextParser.explicitTiming(in: "coffee sometime", now: now, calendar: calendar)
        #expect(timing == PlanTextParser.Timing(startsInMinutes: nil, durationMinutes: nil))
    }
}
