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
        if !FirebaseBootstrap.isRunningUnitTests {
            FirebaseBootstrap.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            if FirebaseBootstrap.isRunningUnitTests {
                // Unit tests don't need any screens or Firebase.
                Color.clear
            } else if !FirebaseBootstrap.isConfigured {
                // Without GoogleService-Info.plist, Firebase can't start and
                // any sign-in call would crash. Explain the fix instead.
                FirebaseSetupMissingView()
            } else {
                RootView()
            }
        }
    }
}

private struct RootView: View {
    @State private var authViewModel = AuthViewModel()

    var body: some View {
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

/// Shown instead of crashing when GoogleService-Info.plist isn't in the app.
private struct FirebaseSetupMissingView: View {
    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.dropInCoral)
                Text("Firebase isn't set up")
                    .font(DropInFont.heading(22))
                    .foregroundColor(.dropInIndigo)
                Text("DropIn couldn't find GoogleService-Info.plist. Download it from the Firebase console (Project settings → Your apps), drag it into the DropIn folder in Xcode, check the DropIn target, then run again.")
                    .font(DropInFont.body(15))
                    .foregroundColor(.dropInIndigo.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(DropInLayout.sheetMargin)
        }
    }
}
