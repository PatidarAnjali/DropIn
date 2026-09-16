//
//  LoginView.swift
//  DropIn
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case username, email, password
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Spacer()

                // Logo, sitting on a soft round badge so it feels like a
                // little sticker rather than a flat image.
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 116, height: 116)
                            .shadow(color: Color.dropInIndigo.opacity(0.08), radius: 14, y: 6)

                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                    }

                    Text("DropIn")
                        .font(DropInFont.heading(36))
                        .foregroundColor(.dropInIndigo)

                    Text("Stay up & see what\nfriends are up to!")
                        .font(DropInFont.body(16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.dropInIndigo.opacity(0.7))
                        .lineSpacing(3)
                }

                // Form fields live on their own soft card so the screen
                // reads as one cohesive, huggable panel.
                VStack(spacing: 12) {
                    DropInTextField(
                        placeholder: "Username",
                        text: $username,
                        icon: "person.fill"
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }

                    DropInTextField(
                        placeholder: "Email",
                        text: $email,
                        icon: "envelope.fill"
                    )
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                    DropInTextField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock.fill",
                        isSecure: true
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { signIn() }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(DropInFont.body(13))
                            .foregroundColor(.dropInCoral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }

                    Button("Get Started") {
                        signIn()
                    }
                    .buttonStyle(DropInPrimaryButtonStyle())
                    .padding(.top, 6)
                }
                .padding(20)
                .dropInCard()

                Text("By continuing you agree to keep it friendly.")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.4))

                Spacer()
                Spacer()
            }
            .padding(.horizontal, DropInLayout.screenMargin)
        }
    }

    private func signIn() {
        focusedField = nil
        authViewModel.signIn(username: username, email: email, password: password)
    }
}

/// Rounded, icon-accented text field matching the friendly card look.
struct DropInTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.dropInCoral.opacity(0.8))
                    .frame(width: 18)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(DropInFont.body(16))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.dropInCream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    LoginView().environment(AuthViewModel())
}
