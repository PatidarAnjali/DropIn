//
//  AuthViewModel.swift
//  DropIn
//
//  Milestone 1: local, fake session state so you can build & test the
//  Login -> Home transition before Firebase Auth exists.
//  Milestone 2: replace signIn()/signUp() bodies with real
//  Auth.auth().signIn(withEmail:password:) calls — DropInApp.swift
//  won't need to change because it only watches `isAuthenticated`.
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    var isAuthenticated: Bool = false
    var currentUser: User?
    var errorMessage: String?

    func signIn(username: String, email: String, password: String) {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a username."
            return
        }
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter an email and password."
            return
        }
        // TODO (Milestone 2): Auth.auth().signIn(withEmail: email, password: password)
        currentUser = User(name: username, email: email)
        isAuthenticated = true
        errorMessage = nil
    }

    /// Called from ProfileView when the user picks a new avatar.
    func updateAvatar(_ imageName: String) {
        currentUser?.avatarUrl = imageName
    }

    func signOut() {
        // TODO (Milestone 2): try? Auth.auth().signOut()
        isAuthenticated = false
        currentUser = nil
    }
}
