//
//  Status.swift
//  DropIn
//
//  Now backed by Firestore — `@DocumentID` and `Codable` conformance
//  let HomeViewModel read/write these straight from/to the "statuses"
//  collection without any manual (de)serialization code.
//

import Foundation
import FirebaseFirestore

enum StatusCategory: String, CaseIterable, Codable {
    case coffee, study, walk, food

    var systemImage: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .study:  return "book.fill"
        case .walk:   return "figure.walk"
        case .food:   return "fork.knife"
        }
    }

    var tint: String {
        switch self {
        case .coffee: return "AFC2A5" // sage
        case .study:  return "F2C9CE" // pink
        case .walk:   return "AFC2A5" // sage
        case .food:   return "E2735A" // coral
        }
    }
}

struct Status: Identifiable, Codable {
    /// Firestore auto-generates this when the doc is created via
    /// `addDocument(from:)`; it's nil only for a not-yet-saved local
    /// instance (e.g. the one built by CreateStatusSheet before it's
    /// written).
    @DocumentID var id: String?
    let userId: String
    let username: String
    var activityText: String
    var category: StatusCategory
    let createdAt: Date
    /// When the hang actually starts. Equal to `createdAt` for an
    /// immediate "I'm here now" hang. Set in the future for a
    /// "plan ahead" hang (e.g. bdenzer's Reddit feedback: "I'll be at
    /// the park in 30 min" is more useful than a live-only ping).
    var startsAt: Date = Date()
    var expiresAt: Date
    var attendees: [String]
    /// Local asset name (mock data) or, later, a remote avatar URL string
    /// from Firebase Storage. Nil falls back to an initials bubble.
    var avatarImageName: String? = nil
    /// nil = visible to every friend (today's default behavior).
    /// Non-nil = only visible to the poster and the friend ids listed
    /// here (This-Establishment26 / achilltrainer's feedback: not every
    /// hang should broadcast to the whole group). Stored as a plain
    /// array (rather than a Set) since that's what Firestore's Codable
    /// support serializes reliably.
    var visibleToUserIds: [String]? = nil
    /// The poster quietly went invisible. The hang keeps existing (so
    /// the poster still sees it and can resume it) but disappears from
    /// everyone else's feed with no "paused" indicator shown to them —
    /// per rjyo's feedback, nobody should have to explain why they
    /// turned their location off.
    var isPaused: Bool = false
    /// How the poster wants company (see PlanRules.swift). Optional so
    /// plans saved before this existed still load; nil means Open Door.
    var intent: PlanIntent? = nil
    /// Number of open seats. Only used when `intent` is `.capped`.
    var seatLimit: Int? = nil

    var resolvedIntent: PlanIntent {
        intent ?? .openDoor
    }

    /// Seats still open, or nil if there's no limit.
    var seatsLeft: Int? {
        PlanRules.seatsLeft(intent: resolvedIntent, seatLimit: seatLimit, attendeeCount: attendees.count)
    }

    var isFull: Bool {
        seatsLeft == 0
    }

    /// The attendee list after `userId` taps the RSVP button, or why
    /// they can't. HomeViewModel re-runs the same rules on the latest
    /// server copy inside a transaction before saving.
    func toggledAttendees(for userId: String, now: Date = Date()) -> Result<[String], RSVPError> {
        PlanRules.toggledAttendees(
            current: attendees,
            userId: userId,
            ownerId: self.userId,
            intent: resolvedIntent,
            seatLimit: seatLimit,
            expiresAt: expiresAt,
            now: now
        )
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    /// True until `startsAt`, for a "plan ahead" hang that hasn't begun yet.
    var isUpcoming: Bool {
        Date() < startsAt
    }

    /// Started, hasn't expired.
    var isLive: Bool {
        !isUpcoming && !isExpired
    }

    var isPrivate: Bool {
        visibleToUserIds != nil
    }

    /// Whether `userId` should see this hang in their feed at all.
    /// The poster always sees their own hang, even while paused, so
    /// they can resume it later.
    func isVisible(to viewerId: String) -> Bool {
        if viewerId == userId { return true }
        if isPaused { return false }
        if let allowed = visibleToUserIds { return allowed.contains(viewerId) }
        return true
    }

    /// e.g. "Starts in 20m" or "Starting now" for an upcoming hang.
    var startLabel: String {
        let remaining = startsAt.timeIntervalSince(Date())
        guard remaining > 60 else { return "Starting now" }
        let minutes = Int(remaining / 60)
        if minutes < 60 {
            return "Starts in \(minutes)m"
        } else {
            let hours = minutes / 60
            return "Starts in \(hours)h"
        }
    }

    /// e.g. "Expiring in 45m" or "Expiring in 2h"
    var expiryLabel: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        guard remaining > 0 else { return "Expired" }
        let minutes = Int(remaining / 60)
        if minutes < 60 {
            return "Expiring in \(minutes)m"
        } else {
            let hours = minutes / 60
            return "Expiring in \(hours)h"
        }
    }

    /// Whichever timing badge is relevant right now — start countdown
    /// while upcoming, expiry countdown once live.
    var timingLabel: String {
        isUpcoming ? startLabel : expiryLabel
    }
}
