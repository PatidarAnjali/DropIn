//
//  FirestoreService.swift
//  DropIn
//
//  One shared Firestore handle. Collections used by this app:
//    "users"    — one doc per account, keyed by the Firebase Auth uid
//    "statuses" — one doc per hang, auto-generated id
//

import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()

    let db: Firestore

    private init() {
        FirebaseBootstrap.configureIfNeeded()
        db = Firestore.firestore()
    }
}
