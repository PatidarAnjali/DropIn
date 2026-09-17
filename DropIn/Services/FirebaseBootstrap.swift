//
//  FirebaseBootstrap.swift
//  DropIn
//
//  Xcode Previews render a single view in isolation — they never run
//  DropInApp.init(), so FirebaseApp.configure() wouldn't normally have
//  happened by the time a preview creates a HomeViewModel or
//  AuthViewModel. Both call this first so Previews (and any future
//  entry point) configure Firebase exactly once, safely.
//

import Foundation
import FirebaseCore

enum FirebaseBootstrap {
    /// True while the unit test runner is hosting the app (locally or in
    /// GitHub Actions). Tests only check plain logic, so the app skips
    /// Firebase and its screens entirely.
    static let isRunningUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// True once Firebase has started successfully.
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        // GoogleService-Info.plist is gitignored, so a fresh clone (or CI)
        // won't have it. Warn instead of crashing.
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("⚠️ GoogleService-Info.plist is missing. Add your own from the Firebase console (see README).")
            return
        }
        FirebaseApp.configure()
    }
}
