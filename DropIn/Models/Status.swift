//
//  Status.swift
//  DropIn
//
//  Milestone 1 version: a plain Swift struct so we can build and preview
//  the UI with mock data. In Milestone 2/3 we'll add `@DocumentID` and
//  Firestore's `Codable` conformance without changing the views at all —
//  that's the whole point of MVVM.
//

import Foundation

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
    var id: String = UUID().uuidString
    let userId: String
    let username: String
    let activityText: String
    let category: StatusCategory
    let createdAt: Date
    let expiresAt: Date
    var attendees: [String]
    /// Local asset name (mock data) or, later, a remote avatar URL string
    /// from Firebase Storage. Nil falls back to an initials bubble.
    var avatarImageName: String? = nil

    var isExpired: Bool {
        Date() > expiresAt
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
}
