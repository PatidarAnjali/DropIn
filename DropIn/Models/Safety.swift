//
//  Safety.swift
//  DropIn
//
//  Blocking and reporting.
//
//  Firestore:
//  - `blocks/{blockerId}_{blockedId}`: one document per block. Both
//    people can read it, so each phone knows to hide the other person,
//    but only the blocker can create or remove it.
//  - `reports/{auto id}`: write-only from the app. Nobody can read
//    reports in the app; review them in the Firebase console (or later,
//    an admin tool).
//
//  The rules here are plain Swift, so they're unit tested
//  (DropInTests/SafetyTests.swift).
//

import Foundation
import FirebaseFirestore

struct Block: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var blockerId: String
    var blockedId: String
    var createdAt: Date = Date()
}

struct Report: Codable {
    enum Reason: String, Codable, CaseIterable {
        case spam
        case harassment
        case inappropriate
        case unsafe
        case other

        var title: String {
            switch self {
            case .spam: "Spam or fake account"
            case .harassment: "Harassment or bullying"
            case .inappropriate: "Inappropriate content"
            case .unsafe: "Makes me feel unsafe"
            case .other: "Something else"
            }
        }
    }

    enum Kind: String, Codable {
        case user
        case plan
        case nudge
    }

    var reporterId: String
    var reportedUserId: String
    var kind: Kind
    /// The plan or nudge id, when reporting content.
    var contentId: String?
    /// A copy of the text at the time of the report, in case it's
    /// edited or deleted before anyone reviews it.
    var contentText: String?
    var reason: Reason
    var details: String?
    var createdAt: Date = Date()
}

/// Who or what is being reported, passed to ReportSheet.
struct ReportTarget: Identifiable {
    let id = UUID()
    let userId: String
    let userName: String
    let kind: Report.Kind
    var contentId: String? = nil
    var contentText: String? = nil
}

enum SafetyRules {
    static let maxDetailsLength = 500

    /// "blocker_blocked": direction matters, so two people can each
    /// block the other.
    static func blockDocumentId(blocker: String, blocked: String) -> String {
        "\(blocker)_\(blocked)"
    }

    /// Everyone `me` shouldn't see or hear from: people I blocked, and
    /// people who blocked me.
    static func hiddenUserIds(for me: String, in blocks: [Block]) -> Set<String> {
        var hidden = Set<String>()
        for block in blocks {
            if block.blockerId == me { hidden.insert(block.blockedId) }
            if block.blockedId == me { hidden.insert(block.blockerId) }
        }
        hidden.remove(me)
        return hidden
    }

    static func didBlock(_ me: String, _ other: String, in blocks: [Block]) -> Bool {
        blocks.contains { $0.blockerId == me && $0.blockedId == other }
    }

    static func isBlocked(by other: String, me: String, in blocks: [Block]) -> Bool {
        blocks.contains { $0.blockerId == other && $0.blockedId == me }
    }

    /// Trims the optional details and caps their length. Empty → nil.
    static func cleanDetails(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxDetailsLength))
    }
}
