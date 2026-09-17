//
//  AuthViewModel.swift
//  DropIn
//
//  Firebase Auth + the user's Firestore profile. Log in and sign up are
//  separate on purpose, so a mistyped password never tries to create a
//  new account.
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

    // Not shown on screen, so there's no need for SwiftUI to track it.
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?

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

    // `isolated` runs cleanup on the main actor, the same place
    // `authHandle` lives, so it can be read here safely.
    isolated deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    /// True while a log in / sign up / reset request is in flight, so the
    /// button can show a spinner and can't be tapped twice.
    var isWorking = false
    /// Non-error notes, e.g. "Password reset email sent".
    var infoMessage: String?

    func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    // MARK: - Log in

    func logIn(email: String, password: String) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return
        }
        clearMessages()
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                _ = try await Auth.auth().signIn(withEmail: email, password: password)
                // The auth listener in init loads the profile and shows Home.
            } catch {
                errorMessage = Self.friendlyMessage(for: error, duringSignUp: false)
            }
        }
    }

    // MARK: - Sign up

    func signUp(username: String, email: String, password: String) {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            errorMessage = "Pick a username."
            return
        }
        guard username.count <= 24 else {
            errorMessage = "Usernames can be up to 24 characters."
            return
        }
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and a password."
            return
        }
        clearMessages()
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                let uid = result.user.uid
                let code = await Self.makeUniqueFriendCode()
                let newUser = User(id: uid, name: username, email: email, friendCode: code)
                // Wait for the profile to be saved *before* loading it.
                // Otherwise the auth listener can look for it too early.
                let data = try Firestore.Encoder().encode(newUser)
                try await FirestoreService.shared.db.collection("users").document(uid).setData(data)
                await loadUserProfile(uid: uid)
            } catch {
                errorMessage = Self.friendlyMessage(for: error, duringSignUp: true)
            }
        }
    }

    // MARK: - Forgot password

    func sendPasswordReset(email: String) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Enter your email above first, then tap Forgot password."
            return
        }
        clearMessages()
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                infoMessage = "If there's an account for \(email), a reset link is on its way."
            } catch {
                errorMessage = Self.friendlyMessage(for: error, duringSignUp: false)
            }
        }
    }

    /// Turns Firebase's technical errors into something a person can act on.
    private static func friendlyMessage(for error: Error, duringSignUp: Bool) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            return "Something went wrong. Check your connection and try again."
        }
        switch code {
        case .invalidEmail:
            return "That email doesn't look right."
        case .emailAlreadyInUse:
            return "There's already an account with this email. Try logging in instead."
        case .weakPassword:
            return "Passwords need at least 6 characters."
        case .wrongPassword, .invalidCredential:
            return "Wrong email or password."
        case .userNotFound:
            return "No account with that email yet. Tap Sign Up to make one."
        case .userDisabled:
            return "This account has been turned off."
        case .tooManyRequests:
            return "Too many tries. Wait a minute and try again."
        case .networkError:
            return "Couldn't connect. Check your internet and try again."
        default:
            return duringSignUp
                ? "Couldn't create your account. Please try again."
                : "Couldn't log you in. Please try again."
        }
    }

    private func loadUserProfile(uid: String) async {
        do {
            let snapshot = try await FirestoreService.shared.db.collection("users").document(uid).getDocument()
            // A brand-new account's profile may not be saved yet; signUp
            // calls this again once it is.
            guard snapshot.exists else { return }
            var user = try snapshot.data(as: User.self)
            // Accounts made before friend codes existed get one now.
            if user.friendCode == nil {
                let code = await Self.makeUniqueFriendCode()
                user.friendCode = code
                try? await FirestoreService.shared.db.collection("users").document(uid)
                    .setData(["friendCode": code], merge: true)
            }
            currentUser = user
            isAuthenticated = true
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your profile. Please try again."
        }
    }

    /// A random friend code nobody else has. With ~887 million possible
    /// codes a clash is very unlikely, but it's checked anyway.
    private static func makeUniqueFriendCode() async -> String {
        for _ in 0..<5 {
            let code = FriendCode.generate()
            let existing = try? await FirestoreService.shared.db.collection("users")
                .whereField("friendCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            if existing?.documents.isEmpty ?? true {
                return code
            }
        }
        return FriendCode.generate()
    }

    /// Called from ProfileView when the user picks a new avatar.
    func updateAvatar(_ imageName: String) {
        currentUser?.avatarUrl = imageName
        guard let uid = currentUser?.id else { return }
        FirestoreService.shared.db.collection("users").document(uid)
            .setData(["avatarUrl": imageName], merge: true)
    }

    // MARK: - Delete account

    enum DeleteAccountError: Error {
        case wrongPassword
        case network
        case failed

        var message: String {
            switch self {
            case .wrongPassword: "That password isn't right."
            case .network: "Couldn't connect. Check your internet and try again."
            case .failed: "Couldn't delete your account. Please try again."
            }
        }
    }

    /// Permanently deletes the account and everything it created.
    ///
    /// Order matters:
    /// 1. Confirm the password (Firebase requires a recent login to delete).
    /// 2. Delete Firestore data while still signed in, since security
    ///    rules only allow you to delete your own things.
    /// 3. Delete the login itself last. If anything before this fails,
    ///    the account still exists and the user can simply try again.
    func deleteAccount(password: String) async -> DeleteAccountError? {
        guard let firebaseUser = Auth.auth().currentUser, let email = firebaseUser.email else {
            return .failed
        }
        let uid = firebaseUser.uid

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            _ = try await firebaseUser.reauthenticate(with: credential)
        } catch {
            let code = AuthErrorCode(rawValue: (error as NSError).code)
            if code == .wrongPassword || code == .invalidCredential { return .wrongPassword }
            if code == .networkError { return .network }
            return .failed
        }

        do {
            try await Self.deleteUserData(uid: uid)
            try await firebaseUser.delete()
        } catch {
            print("Account deletion failed: \(error)")
            return (error as NSError).code == AuthErrorCode.networkError.rawValue ? .network : .failed
        }

        NotificationService.shared.cancelAllNotifications()
        isAuthenticated = false
        currentUser = nil
        return nil
    }

    private static func deleteUserData(uid: String) async throws {
        let db = FirestoreService.shared.db

        // Leave plans you joined (security rules let you remove yourself).
        let joined = try await db.collection("statuses").whereField("attendees", arrayContains: uid).getDocuments()
        for document in joined.documents {
            try await document.reference.updateData(["attendees": FieldValue.arrayRemove([uid])])
        }

        var toDelete: [DocumentReference] = []
        toDelete += try await db.collection("statuses").whereField("userId", isEqualTo: uid).getDocuments().documents.map(\.reference)
        toDelete += try await db.collection("friendships").whereField("userIds", arrayContains: uid).getDocuments().documents.map(\.reference)
        toDelete += try await db.collection("nudges").whereField("fromUserId", isEqualTo: uid).getDocuments().documents.map(\.reference)
        toDelete += try await db.collection("blocks").whereField("blockerId", isEqualTo: uid).getDocuments().documents.map(\.reference)
        toDelete.append(db.collection("users").document(uid))

        // Batches hold up to 500 writes.
        for start in stride(from: 0, to: toDelete.count, by: 450) {
            let batch = db.batch()
            for reference in toDelete[start..<min(start + 450, toDelete.count)] {
                batch.deleteDocument(reference)
            }
            try await batch.commit()
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        isAuthenticated = false
        currentUser = nil
    }
}
