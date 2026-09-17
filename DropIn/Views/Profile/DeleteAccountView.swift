//
//  DeleteAccountView.swift
//  DropIn
//
//  Permanently deletes the account (required by the App Store for apps
//  that let people sign up). Asks for the password because Firebase only
//  allows deleting an account right after logging in.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var password = ""
    @State private var isDeleting = false
    @State private var error: AuthViewModel.DeleteAccountError?
    @State private var confirm = false

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("Delete Account")
                            .font(DropInFont.heading(24))
                            .foregroundColor(.dropInIndigo)
                        Spacer()
                        DropInCloseButton { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("This can't be undone", systemImage: "exclamationmark.triangle.fill")
                            .font(DropInFont.bodyMedium(15))
                            .foregroundColor(.dropInCoral)
                        Text("Deleting your account permanently removes:")
                            .font(DropInFont.body(14))
                            .foregroundColor(.dropInIndigo.opacity(0.75))
                        VStack(alignment: .leading, spacing: 8) {
                            bullet("Your profile, avatar, and friend code")
                            bullet("All plans you posted")
                            bullet("Your friends and friend requests")
                            bullet("Nudges you sent and people you blocked")
                            bullet("Your spot on plans you said you'd drop in on")
                        }
                    }
                    .padding(18)
                    .dropInCard(cornerRadius: 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your password to confirm")
                            .font(DropInFont.bodyMedium(14))
                            .foregroundColor(.dropInIndigo)
                        DropInTextField(placeholder: "Password", text: $password, icon: "lock.fill", isSecure: true)
                            .textContentType(.password)
                    }

                    if let error {
                        Label(error.message, systemImage: "exclamationmark.circle.fill")
                            .font(DropInFont.body(13))
                            .foregroundColor(.dropInCoral)
                    }

                    Button {
                        confirm = true
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting { ProgressView().tint(.white) }
                            Text(isDeleting ? "Deleting..." : "Delete My Account")
                                .font(DropInFont.bodyMedium(17))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty || isDeleting)
                    .opacity(password.isEmpty ? 0.5 : 1)

                    Button("Keep My Account") { dismiss() }
                        .font(DropInFont.bodyMedium(15))
                        .foregroundColor(.dropInIndigo.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .disabled(isDeleting)
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .interactiveDismissDisabled(isDeleting)
        .confirmationDialog("Delete your account forever?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) { delete() }
        } message: {
            Text("All your DropIn data will be erased.")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Color.dropInCoral.opacity(0.7))
                .frame(width: 5, height: 5)
            Text(text)
                .font(DropInFont.body(14))
                .foregroundColor(.dropInIndigo.opacity(0.75))
        }
    }

    private func delete() {
        isDeleting = true
        error = nil
        Task {
            let result = await authViewModel.deleteAccount(password: password)
            isDeleting = false
            if let result {
                error = result
            }
            // On success the app returns to the login screen by itself.
        }
    }
}
