//
//  Nudge.swift
//  DropIn
//
//  "Who's Down?": instead of posting to the whole feed, privately ping
//  a few friends to see if anyone's nearby. Friends answer "I'm down"
//  or "Not nearby", and the nudge disappears after 30 minutes.
//
//  Firestore: one `nudges` document per nudge. `toUserIds` lets each
//  friend load only nudges sent to them (`arrayContains`), and replies
//  live in the `responses` map (uid → "down" / "notNearby").
//
//  Right now nudges show up whenever the recipient has the app open.
//  With push notifications later, a Cloud Function can also buzz their
//  phone when a nudge document is created.
//

import Foundation
import FirebaseFirestore

enum NudgeResponse: String, Codable {
    case down
    case notNearby
}

struct Nudge: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var fromUserId: String
    var fromName: String
    var message: String
    var toUserIds: [String]
    var responses: [String: NudgeResponse] = [:]
    var createdAt: Date = Date()
    var expiresAt: Date

    func isActive(now: Date = Date()) -> Bool {
        now < expiresAt
    }

    func response(from userId: String) -> NudgeResponse? {
        responses[userId]
    }

    var downUserIds: [String] {
        toUserIds.filter { responses[$0] == .down }
    }

    /// e.g. "12m left"
    func timeLeftLabel(now: Date = Date()) -> String {
        let minutes = Int(ceil(expiresAt.timeIntervalSince(now) / 60))
        return minutes <= 0 ? "Ended" : "\(minutes)m left"
    }
}

enum NudgeRules {
    static let maxRecipients = 4
    static let maxMessageLength = 80
    static let lifetime: TimeInterval = 30 * 60

    enum ValidationError: Error, Equatable {
        case emptyMessage
        case messageTooLong
        case noRecipients
        case tooManyRecipients
        case notFriends

        var message: String {
            switch self {
            case .emptyMessage: "Say what you're thinking, like \"coffee near campus?\""
            case .messageTooLong: "Keep it under \(NudgeRules.maxMessageLength) characters."
            case .noRecipients: "Pick at least one friend."
            case .tooManyRecipients: "Nudges go to \(NudgeRules.maxRecipients) friends at most."
            case .notFriends: "You can only nudge friends."
            }
        }
    }

    /// Builds a nudge, or explains what's wrong.
    static func makeNudge(
        from userId: String,
        name: String,
        message: String,
        to recipients: [String],
        friendIds: Set<String>,
        now: Date = Date()
    ) -> Result<Nudge, ValidationError> {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueRecipients = Array(Set(recipients)).sorted()

        if text.isEmpty { return .failure(.emptyMessage) }
        if text.count > maxMessageLength { return .failure(.messageTooLong) }
        if uniqueRecipients.isEmpty { return .failure(.noRecipients) }
        if uniqueRecipients.count > maxRecipients { return .failure(.tooManyRecipients) }
        if !uniqueRecipients.allSatisfy(friendIds.contains) { return .failure(.notFriends) }

        return .success(Nudge(
            fromUserId: userId,
            fromName: name,
            message: text,
            toUserIds: uniqueRecipients,
            createdAt: now,
            expiresAt: now.addingTimeInterval(lifetime)
        ))
    }
}
