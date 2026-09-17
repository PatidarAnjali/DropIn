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
    /// Short code friends use to add you (see FriendCode). Optional
    /// because accounts made before friends existed don't have one yet;
    /// AuthViewModel creates it the next time they log in.
    var friendCode: String?
}
