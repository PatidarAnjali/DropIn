//
//  FriendsTests.swift
//  DropInTests
//
//  Friend codes, how two people are related, and nudge validation.
//

import Foundation
import Testing
@testable import DropIn

@MainActor
@Suite("Friend codes")
struct FriendCodeTests {

    @Test("Generated codes are 6 easy-to-read characters")
    func generated() {
        for _ in 0..<200 {
            let code = FriendCode.generate()
            #expect(code.count == FriendCode.length)
            #expect(FriendCode.normalize(code) == code)
            #expect(!code.contains { "01OIL".contains($0) })
        }
    }

    @Test("Typed and scanned codes are cleaned up", arguments: [
        ("k7q2mx", "K7Q2MX"),
        ("K7Q-2MX", "K7Q2MX"),
        ("  k7q 2mx ", "K7Q2MX"),
        ("dropin-friend:K7Q2MX", "K7Q2MX"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(FriendCode.normalize(input) == expected)
    }

    @Test("Things that can't be codes are rejected", arguments: [
        "", "K7Q2M", "K7Q2MXX", "K0Q2MX", "https://example.com",
    ])
    func rejects(input: String) {
        #expect(FriendCode.normalize(input) == nil)
    }

    @Test("Codes display with a dash in the middle")
    func formatted() {
        #expect(FriendCode.formatted("K7Q2MX") == "K7Q-2MX")
    }
}

@MainActor
@Suite("Friendships")
struct FriendshipRulesTests {

    func friendship(_ a: String, _ b: String, requester: String, state: FriendshipState) -> Friendship {
        Friendship(userIds: [a, b].sorted(), requesterId: requester, state: state)
    }

    @Test("A pair gets the same document id whoever asks first")
    func documentId() {
        #expect(FriendshipRules.documentId("zoe", "adam") == "adam_zoe")
        #expect(FriendshipRules.documentId("adam", "zoe") == "adam_zoe")
    }

    @Test("Relations are seen from each person's side")
    func relations() {
        let pending = [friendship("anjali", "bob", requester: "anjali", state: .pending)]
        #expect(FriendshipRules.relation(between: "anjali", and: "bob", in: pending) == .requestSent)
        #expect(FriendshipRules.relation(between: "bob", and: "anjali", in: pending) == .requestReceived)
        #expect(FriendshipRules.relation(between: "anjali", and: "justin", in: pending) == .none)

        let accepted = [friendship("anjali", "bob", requester: "anjali", state: .accepted)]
        #expect(FriendshipRules.relation(between: "bob", and: "anjali", in: accepted) == .friends)
    }

    @Test("Only accepted friendships count as friends")
    func friendIds() {
        let all = [
            friendship("anjali", "bob", requester: "bob", state: .accepted),
            friendship("anjali", "justin", requester: "anjali", state: .pending),
            friendship("anjali", "mara", requester: "mara", state: .pending),
        ]
        #expect(FriendshipRules.friendIds(of: "anjali", in: all) == ["bob"])
        #expect(FriendshipRules.incomingRequests(for: "anjali", in: all).count == 1)
        #expect(FriendshipRules.outgoingRequests(from: "anjali", in: all).count == 1)
    }
}

@MainActor
@Suite("Who's Down? nudges")
struct NudgeRulesTests {

    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let friends: Set<String> = ["bob", "justin", "mara", "jordan", "sam"]

    func make(_ message: String = "Coffee?", to recipients: [String]) -> Result<Nudge, NudgeRules.ValidationError> {
        NudgeRules.makeNudge(from: "anjali", name: "Anjali", message: message, to: recipients, friendIds: friends, now: now)
    }

    @Test("A valid nudge lasts 30 minutes")
    func valid() throws {
        let nudge = try make(to: ["bob", "justin"]).get()
        #expect(nudge.toUserIds == ["bob", "justin"])
        #expect(nudge.expiresAt == now.addingTimeInterval(30 * 60))
        #expect(nudge.isActive(now: now))
        #expect(!nudge.isActive(now: now.addingTimeInterval(31 * 60)))
    }

    @Test("Nudges go to 1–4 friends only")
    func recipientLimits() {
        #expect(make(to: []) == .failure(.noRecipients))
        #expect(make(to: ["bob", "justin", "mara", "jordan", "sam"]) == .failure(.tooManyRecipients))
        #expect(make(to: ["stranger"]) == .failure(.notFriends))
    }

    @Test("Picking the same friend twice only counts once")
    func duplicates() throws {
        let nudge = try make(to: ["bob", "bob"]).get()
        #expect(nudge.toUserIds == ["bob"])
    }

    @Test("Messages can't be blank or too long")
    func messageLimits() {
        #expect(make("   ", to: ["bob"]) == .failure(.emptyMessage))
        #expect(make(String(repeating: "a", count: 81), to: ["bob"]) == .failure(.messageTooLong))
    }

    @Test("The sender sees who's down")
    func responses() throws {
        var nudge = try make(to: ["bob", "justin", "mara"]).get()
        nudge.responses = ["bob": .down, "justin": .notNearby]
        #expect(nudge.downUserIds == ["bob"])
        #expect(nudge.response(from: "mara") == nil)
    }
}
