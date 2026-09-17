//
//  Friendship.swift
//  DropIn
//
//  Friends, friend requests, and friend codes.
//
//  Firestore layout: one `friendships` document per pair of people.
//  - The document id is both uids sorted and joined ("abc_xyz"), so a
//    pair can only ever have one document and it's easy to look up.
//  - `userIds` holds both uids, so "all my friendships" is a single
//    `arrayContains` query (and easy to protect with security rules).
//  - `state` is "pending" (a request) or "accepted" (friends).
//  Declining, cancelling, and unfriending all just delete the document.
//
//  The rules below are plain Swift with no Firebase calls, so they're
//  unit tested (DropInTests/FriendsTests.swift).
//

import Foundation
import FirebaseFirestore

enum FriendshipState: String, Codable {
    case pending
    case accepted
}

struct Friendship: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    /// Both people, sorted.
    var userIds: [String]
    /// Who sent the request.
    var requesterId: String
    var state: FriendshipState
    var createdAt: Date = Date()

    /// The other person in this friendship.
    func otherUserId(than userId: String) -> String? {
        userIds.first { $0 != userId }
    }
}

// MARK: - How two people are related

enum FriendRelation: Equatable {
    case none
    /// You sent them a request.
    case requestSent
    /// They sent you a request.
    case requestReceived
    case friends
}

enum FriendshipRules {
    /// "abc_xyz": the same id no matter who sends the request.
    static func documentId(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "_")
    }

    static func relation(between me: String, and other: String, in friendships: [Friendship]) -> FriendRelation {
        guard me != other,
              let friendship = friendships.first(where: { Set($0.userIds) == [me, other] }) else {
            return .none
        }
        switch friendship.state {
        case .accepted: return .friends
        case .pending: return friendship.requesterId == me ? .requestSent : .requestReceived
        }
    }

    static func friendIds(of me: String, in friendships: [Friendship]) -> Set<String> {
        Set(friendships.filter { $0.state == .accepted }.compactMap { $0.otherUserId(than: me) })
    }

    static func incomingRequests(for me: String, in friendships: [Friendship]) -> [Friendship] {
        friendships.filter { $0.state == .pending && $0.requesterId != me }
    }

    static func outgoingRequests(from me: String, in friendships: [Friendship]) -> [Friendship] {
        friendships.filter { $0.state == .pending && $0.requesterId == me }
    }
}

// MARK: - Friend codes

/// A short code like "K7Q2MX" that people share (typed, texted, or as a
/// QR code) to add each other. Uses letters and numbers that are hard
/// to mix up: no 0/O, 1/I/L.
enum FriendCode {
    static let length = 6
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    /// What the QR code contains, so the scanner can ignore other QR codes.
    static let qrPrefix = "dropin-friend:"

    static func generate() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    static func qrPayload(for code: String) -> String {
        qrPrefix + code
    }

    /// Cleans up whatever the user typed or scanned. Returns nil if it
    /// can't be a friend code. Accepts "k7q2mx", "K7Q-2MX", " K7Q 2MX ",
    /// and scanned "dropin-friend:K7Q2MX".
    static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix(qrPrefix) {
            text = String(text.dropFirst(qrPrefix.count))
        }
        let cleaned = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == length, cleaned.allSatisfy({ alphabet.contains($0) }) else {
            return nil
        }
        return cleaned
    }

    /// "K7Q2MX" → "K7Q-2MX", easier to read out loud.
    static func formatted(_ code: String) -> String {
        guard code.count == length else { return code }
        return "\(code.prefix(3))-\(code.suffix(3))"
    }
}
