//
//  PlanRules.swift
//  DropIn
//
//  The "vibe" of a plan and the rules for who can join it.
//
//  These rules are plain Swift with no Firebase or UI code. That keeps
//  them easy to unit test (see DropInTests/PlanRulesTests.swift), and
//  the exact same function runs inside the Firestore transaction in
//  HomeViewModel, so what the tests check is what the app enforces.
//

import Foundation

// MARK: - Intent

/// How the poster wants company.
nonisolated enum PlanIntent: String, CaseIterable, Codable, Sendable {
    /// "Drop in anytime!"
    case openDoor
    /// "Studying at the library, sit nearby, but mostly silent."
    case quiet
    /// "Only 2 open seats at my table!" Locks once it's full.
    case capped

    var title: String {
        switch self {
        case .openDoor: "Open Door"
        case .quiet: "Quiet"
        case .capped: "Limited Seats"
        }
    }

    var subtitle: String {
        switch self {
        case .openDoor: "Drop in anytime"
        case .quiet: "Sit nearby, mostly silent"
        case .capped: "Only a few spots, locks when full"
        }
    }

    var systemImage: String {
        switch self {
        case .openDoor: "door.left.hand.open"
        case .quiet: "laptopcomputer"
        case .capped: "chair.fill"
        }
    }
}

// MARK: - RSVP rules

nonisolated enum RSVPError: Error, Equatable, Sendable {
    case ownPlan
    case full
    case expired

    var message: String {
        switch self {
        case .ownPlan: "You can't drop in on your own plan."
        case .full: "Sorry, that plan just filled up."
        case .expired: "That plan has already ended."
        }
    }

    var code: Int {
        switch self {
        case .ownPlan: 1
        case .full: 2
        case .expired: 3
        }
    }
}

nonisolated enum PlanRules {
    static let seatRange = 1...8
    static let errorDomain = "DropIn.RSVP"

    /// Seats still open, or nil if the plan has no seat limit.
    static func seatsLeft(intent: PlanIntent, seatLimit: Int?, attendeeCount: Int) -> Int? {
        guard intent == .capped, let seatLimit else { return nil }
        return max(0, seatLimit - attendeeCount)
    }

    /// What the attendee list becomes when `userId` taps the RSVP button:
    /// they're added if they weren't coming, removed if they were.
    ///
    /// - Leaving is always allowed (it frees up a seat).
    /// - Joining fails for the poster, for expired plans, and for full plans.
    static func toggledAttendees(
        current: [String],
        userId: String,
        ownerId: String,
        intent: PlanIntent,
        seatLimit: Int?,
        expiresAt: Date,
        now: Date = Date()
    ) -> Result<[String], RSVPError> {
        if current.contains(userId) {
            return .success(current.filter { $0 != userId })
        }
        if userId == ownerId { return .failure(.ownPlan) }
        if now >= expiresAt { return .failure(.expired) }
        if let left = seatsLeft(intent: intent, seatLimit: seatLimit, attendeeCount: current.count), left == 0 {
            return .failure(.full)
        }
        return .success(current + [userId])
    }
}
