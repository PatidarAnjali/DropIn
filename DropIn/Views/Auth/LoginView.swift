//
//  LoginView.swift
//  DropIn
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    private enum Mode: String, CaseIterable {
        case logIn = "Log In"
        case signUp = "Sign Up"
    }

    @State private var mode: Mode = .logIn
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

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        header
                        formCard
                        Text("By continuing you agree to keep it friendly.")
                            .font(DropInFont.body(12))
                            .foregroundColor(.dropInIndigo.opacity(0.4))
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, DropInLayout.screenMargin)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            // Logo on a soft round badge so it feels like a little sticker.
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
                .font(DropInFont.brand(36))
                .foregroundColor(.dropInIndigo)

            Text(mode == .logIn ? "Welcome back!\nSee what friends are up to." : "Stay up & see what\nfriends are up to!")
                .font(DropInFont.body(16))
                .multilineTextAlignment(.center)
                .foregroundColor(.dropInIndigo.opacity(0.7))
                .lineSpacing(3)
                .contentTransition(.opacity)
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: 12) {
            modePicker
                .padding(.bottom, 4)

            if mode == .signUp {
                DropInTextField(placeholder: "Username", text: $username, icon: "person.fill")
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            DropInTextField(placeholder: "Email", text: $email, icon: "envelope.fill")
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            DropInTextField(placeholder: "Password", text: $password, icon: "lock.fill", isSecure: true)
                // Lets iOS offer saved passwords when logging in, and suggest
                // a strong new one when signing up.
                .textContentType(mode == .logIn ? .password : .newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

            HStack {
                if mode == .signUp {
                    Text("At least 6 characters")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.45))
                    Spacer()
                } else {
                    Spacer()
                    Button("Forgot password?") {
                        focusedField = nil
                        authViewModel.sendPasswordReset(email: email)
                    }
                    .font(DropInFont.bodyMedium(13))
                    .foregroundColor(.dropInCoral)
                    .disabled(authViewModel.isWorking)
                }
            }
            .padding(.horizontal, 4)

            if let error = authViewModel.errorMessage {
                message(error, icon: "exclamationmark.circle.fill", color: .dropInCoral)
            } else if let info = authViewModel.infoMessage {
                message(info, icon: "checkmark.circle.fill", color: .dropInIndigo.opacity(0.7))
            }

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if authViewModel.isWorking {
                        ProgressView().tint(.white)
                    }
                    Text(mode == .logIn ? "Log In" : "Create Account")
                }
            }
            .buttonStyle(DropInPrimaryButtonStyle())
            .disabled(authViewModel.isWorking)
            .padding(.top, 4)

            HStack(spacing: 4) {
                Text(mode == .logIn ? "New to DropIn?" : "Already have an account?")
                    .foregroundColor(.dropInIndigo.opacity(0.55))
                Button(mode == .logIn ? "Sign up" : "Log in") {
                    switchMode(to: mode == .logIn ? .signUp : .logIn)
                }
                .font(DropInFont.bodyMedium(14))
                .foregroundColor(.dropInCoral)
            }
            .font(DropInFont.body(14))
            .padding(.top, 4)
        }
        .padding(20)
        .dropInCard()
    }

    /// Log In | Sign Up toggle at the top of the card.
    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { option in
                let isSelected = mode == option
                Button {
                    switchMode(to: option)
                } label: {
                    Text(option.rawValue)
                        .font(DropInFont.bodyMedium(14))
                        .foregroundColor(isSelected ? .white : .dropInIndigo.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isSelected ? Color.dropInIndigo : Color.clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.dropInCream))
        .overlay(Capsule().stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1))
    }

    private func message(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(DropInFont.body(13))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func switchMode(to newMode: Mode) {
        guard newMode != mode else { return }
        authViewModel.clearMessages()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            mode = newMode
        }
        focusedField = nil
    }

    private func submit() {
        focusedField = nil
        switch mode {
        case .logIn:
            authViewModel.logIn(email: email, password: password)
        case .signUp:
            authViewModel.signUp(username: username, email: email, password: password)
        }
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
