//
//  MockData.swift
//  DropIn
//
//  Now Preview-only fuel; HomeViewModel reads live data from Firestore,
//  but #Preview blocks (StatusRowView, CreateStatusSheet, etc.) still use
//  this so Xcode's canvas has something to render without hitting the
//  network or requiring a signed-in Firebase user.
//

import Foundation

enum MockData {
    /// Friend -> picture avatar lookup, so attendee avatar stacks can show
    /// faces instead of initials. Swap for real profile photo URLs once
    /// Firebase Storage is wired up.
    static let avatarsByUserId: [String: String] = [
        "u1": "Avatar6",
        "u2": "Avatar14",
        "u3": "Avatar9",
        "u4": "Avatar20"
    ]

    /// Friend -> display name lookup. Used so that if an avatar is ever
    /// missing, the initials fallback bubble shows the first letter of
    /// the person's actual name instead of the first character of their
    /// raw user id (which, for real accounts with UUID ids, is often a
    /// digit rather than a letter).
    static let usernamesByUserId: [String: String] = [
        "u1": "Name",
        "u2": "Mara",
        "u3": "Rarian",
        "u4": "Jordan"
    ]

    static func avatar(forUserId userId: String) -> String? {
        avatarsByUserId[userId]
    }

    static func username(forUserId userId: String) -> String? {
        usernamesByUserId[userId]
    }

    /// All friend ids available to invite/pick from in the "who can see
    /// this" picker, in a stable order.
    static let allFriendIds: [String] = ["u1", "u2", "u3", "u4"]

    static let statuses: [Status] = [
        Status(
            userId: "u1",
            username: "Name",
            activityText: "Grabbing coffee at Starbucks",
            category: .coffee,
            createdAt: Date(),
            startsAt: Date(),
            expiresAt: Date().addingTimeInterval(45 * 60),
            attendees: ["u2", "u3"],
            avatarImageName: "Avatar6",
            intent: .capped,
            seatLimit: 3
        ),
        Status(
            userId: "u2",
            username: "Mara",
            activityText: "Studying at the library",
            category: .study,
            createdAt: Date(),
            startsAt: Date(),
            expiresAt: Date().addingTimeInterval(2 * 60 * 60),
            attendees: ["u1"],
            avatarImageName: "Avatar14",
            intent: .quiet
        ),
        Status(
            userId: "u3",
            username: "Rarian",
            activityText: "Routine walk",
            category: .walk,
            createdAt: Date(),
            startsAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60),
            attendees: ["u1", "u2", "u4"],
            avatarImageName: "Avatar9"
        ),
        // Demo of a "plan ahead" hang that hasn't started yet — shows up
        // in the "Starting Soon" section instead of "Live Now".
        Status(
            userId: "u4",
            username: "Jordan",
            activityText: "Dinner at the new ramen spot",
            category: .food,
            createdAt: Date(),
            startsAt: Date().addingTimeInterval(40 * 60),
            expiresAt: Date().addingTimeInterval(40 * 60 + 90 * 60),
            attendees: [],
            avatarImageName: "Avatar20"
        )
    ]
}
