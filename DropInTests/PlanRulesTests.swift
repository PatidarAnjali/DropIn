//
//  PlanRulesTests.swift
//  DropInTests
//
//  Who can join a plan: the poster can't, expired plans are closed, and
//  "Limited Seats" plans lock once they're full.
//

import Foundation
import Testing
@testable import DropIn

@MainActor
@Suite("RSVP rules")
struct PlanRulesTests {

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func makePlan(
        owner: String = "host",
        attendees: [String] = [],
        intent: PlanIntent? = nil,
        seatLimit: Int? = nil,
        expiresIn: TimeInterval = 3600
    ) -> Status {
        Status(
            userId: owner,
            username: "Host",
            activityText: "Dinner",
            category: .food,
            createdAt: now,
            startsAt: now,
            expiresAt: now.addingTimeInterval(expiresIn),
            attendees: attendees,
            intent: intent,
            seatLimit: seatLimit
        )
    }

    @Test("A friend can join an open plan")
    func friendJoins() {
        let plan = makePlan(attendees: ["bob"])
        #expect(plan.toggledAttendees(for: "justin", now: now) == .success(["bob", "justin"]))
    }

    @Test("Tapping again leaves the plan")
    func friendLeaves() {
        let plan = makePlan(attendees: ["bob", "justin"])
        #expect(plan.toggledAttendees(for: "bob", now: now) == .success(["justin"]))
    }

    @Test("The poster can't drop in on their own plan")
    func ownerCannotJoin() {
        let plan = makePlan(owner: "host")
        #expect(plan.toggledAttendees(for: "host", now: now) == .failure(.ownPlan))
    }

    @Test("Nobody can join once a plan has expired")
    func expiredPlan() {
        let plan = makePlan(expiresIn: -60)
        #expect(plan.toggledAttendees(for: "justin", now: now) == .failure(.expired))
    }

    @Test("A capped plan locks when the last seat is taken")
    func cappedPlanLocks() {
        let plan = makePlan(attendees: ["bob", "justin"], intent: .capped, seatLimit: 2)
        #expect(plan.seatsLeft == 0)
        #expect(plan.isFull)
        #expect(plan.toggledAttendees(for: "anjali", now: now) == .failure(.full))
    }

    @Test("Leaving a full plan frees up a seat")
    func leavingFullPlan() {
        let plan = makePlan(attendees: ["bob", "justin"], intent: .capped, seatLimit: 2)
        #expect(plan.toggledAttendees(for: "bob", now: now) == .success(["justin"]))
    }

    @Test("Seats left counts down as friends join", arguments: [
        (0, 3), (1, 2), (2, 1), (3, 0), (5, 0),
    ])
    func seatsLeft(attendeeCount: Int, expectedLeft: Int) {
        let attendees = (0..<attendeeCount).map { "friend\($0)" }
        let plan = makePlan(attendees: attendees, intent: .capped, seatLimit: 3)
        #expect(plan.seatsLeft == expectedLeft)
    }

    @Test("Open Door and Quiet plans never fill up", arguments: [PlanIntent.openDoor, .quiet])
    func uncappedNeverFull(intent: PlanIntent) {
        let crowd = (0..<50).map { "friend\($0)" }
        let plan = makePlan(attendees: crowd, intent: intent, seatLimit: 2)
        #expect(plan.seatsLeft == nil)
        #expect(!plan.isFull)
        #expect(plan.toggledAttendees(for: "late", now: now) == .success(crowd + ["late"]))
    }

    @Test("Plans saved before intents existed act like Open Door")
    func legacyPlanDefaultsToOpenDoor() {
        let plan = makePlan(intent: nil)
        #expect(plan.resolvedIntent == .openDoor)
    }
}

@MainActor
@Suite("Plan visibility")
struct PlanVisibilityTests {

    func makePlan(visibleTo: [String]? = nil, paused: Bool = false) -> Status {
        Status(
            userId: "host",
            username: "Host",
            activityText: "Walk",
            category: .walk,
            createdAt: Date(),
            startsAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            attendees: [],
            visibleToUserIds: visibleTo,
            isPaused: paused
        )
    }

    @Test("Everyone sees a public plan")
    func publicPlan() {
        #expect(makePlan().isVisible(to: "anyone"))
    }

    @Test("Private plans only show to chosen friends")
    func privatePlan() {
        let plan = makePlan(visibleTo: ["bob"])
        #expect(plan.isVisible(to: "bob"))
        #expect(!plan.isVisible(to: "justin"))
    }

    @Test("Paused plans are hidden from friends but not the poster")
    func pausedPlan() {
        let plan = makePlan(paused: true)
        #expect(!plan.isVisible(to: "bob"))
        #expect(plan.isVisible(to: "host"))
    }
}
