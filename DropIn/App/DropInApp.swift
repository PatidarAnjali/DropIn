//
//  DropInApp.swift
//  DropIn
//
//  App entry point. Milestone 1: switches between LoginView and
//  HomeFeedView based on a local flag in AuthViewModel.
//  Milestone 2: add `FirebaseApp.configure()` here once the Firebase
//  SDK is added via Swift Package Manager (see setup guide).
//

import SwiftUI

@main
struct DropInApp: App {

    // init() {
    //     FirebaseApp.configure() // uncomment in Milestone 2
    // }

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
        }
    }
}
