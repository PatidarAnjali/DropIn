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

import FirebaseCore

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
