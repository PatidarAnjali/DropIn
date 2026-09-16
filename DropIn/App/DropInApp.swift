//
//  DropInApp.swift
//  DropIn
//
//  App entry point. Switches between LoginView and HomeFeedView based
//  on AuthViewModel.isAuthenticated, which now tracks Firebase Auth's
//  real session state.
//

import SwiftUI

@main
struct DropInApp: App {

    init() {
        FirebaseBootstrap.configureIfNeeded()
    }

    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    HomeFeedView()
                } else {
                    LoginView()
                }
            }
            .environment(authViewModel)
            // Open Sans for any text that doesn't set its own font.
            .font(DropInFont.body())
        }
    }
}
