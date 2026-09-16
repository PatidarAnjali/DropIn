//
//  User.swift
//  DropIn
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    /// Firestore document id — always set to the Firebase Auth uid so a
    /// user doc's path IS their uid (no separate lookup needed).
    @DocumentID var id: String?
    let name: String
    let email: String
    var avatarUrl: String?
}
