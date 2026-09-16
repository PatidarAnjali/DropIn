//
//  AuthViewModel.swift
//  DropIn
//
//  Real Firebase Auth + Firestore now that the SDK is wired in.
//  "Get Started" on LoginView still does double duty as sign-in AND
//  sign-up (same as the Milestone 1 mock did): try to sign in first,
//  and if there's no account yet with that email, create one.
//

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated: Bool = false
    var currentUser: User?
    var errorMessage: String?

    // `deinit` is nonisolated, so the handle must be readable from there.
    nonisolated(unsafe) private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        FirebaseBootstrap.configureIfNeeded()
        // Keeps `isAuthenticated` in sync with Firebase's own session
        // state, so relaunching after a previous sign-in skips straight
        // to Home instead of showing the login screen again.
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task { @MainActor in
                if let firebaseUser {
                    await self.loadUserProfile(uid: firebaseUser.uid)
                } else {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    func signIn(username: String, email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter an email and password."
            return
        }
        errorMessage = nil
        Task {
            do {
                _ = try await Auth.auth().signIn(withEmail: email, password: password)
                // `loadUserProfile` fires automatically via the state
                // listener above once sign-in succeeds.
            } catch {
                await signUp(username: username, email: email, password: password)
            }
        }
    }

    private func signUp(username: String, email: String, password: String) async {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a username."
            return
        }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let newUser = User(id: result.user.uid, name: username, email: email)
            try FirestoreService.shared.db.collection("users").document(result.user.uid).setData(from: newUser)
            // `loadUserProfile` fires automatically via the state
            // listener above once the account is created.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadUserProfile(uid: String) async {
        do {
            let snapshot = try await FirestoreService.shared.db.collection("users").document(uid).getDocument()
            currentUser = try snapshot.data(as: User.self)
            isAuthenticated = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called from ProfileView when the user picks a new avatar.
    func updateAvatar(_ imageName: String) {
        currentUser?.avatarUrl = imageName
        guard let uid = currentUser?.id else { return }
        FirestoreService.shared.db.collection("users").document(uid)
            .setData(["avatarUrl": imageName], merge: true)
    }

    func signOut() {
        try? Auth.auth().signOut()
        isAuthenticated = false
        currentUser = nil
    }
}
