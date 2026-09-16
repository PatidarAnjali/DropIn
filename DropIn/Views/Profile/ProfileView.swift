//
//  ProfileView.swift
//  DropIn
//
//  Lets the signed-in user pick an avatar from the full icon set. Plain
//  cream background with a few doodle accents, matching every other
//  screen besides Home.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var selectedAvatar: String?

    /// All 22 avatars bundled in Assets.xcassets (Avatar1...Avatar22).
    private let avatarOptions: [String] = (1...22).map { "Avatar\($0)" }
    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 16)]

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Your Profile")
                        .font(DropInFont.heading(24))
                        .foregroundColor(.dropInIndigo)
                    Spacer()
                    closeButton
                }

                VStack(spacing: 10) {
                    AvatarView(
                        name: authViewModel.currentUser?.name ?? "You",
                        imageName: selectedAvatar,
                        size: 96
                    )
                    Text(authViewModel.currentUser?.name ?? "You")
                        .font(DropInFont.bodyMedium(18))
                        .foregroundColor(.dropInIndigo)
                    if let email = authViewModel.currentUser?.email {
                        Text(email)
                            .font(DropInFont.body(13))
                            .foregroundColor(.dropInIndigo.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

                Text("Choose an avatar")
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.dropInIndigo)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(avatarOptions, id: \.self) { avatarName in
                            avatarOption(avatarName)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button("Save") {
                    if let selectedAvatar {
                        authViewModel.updateAvatar(selectedAvatar)
                    }
                    dismiss()
                }
                .buttonStyle(DropInPrimaryButtonStyle())

                Button {
                    authViewModel.signOut()
                    dismiss()
                } label: {
                    Text("Sign Out")
                        .font(DropInFont.bodyMedium(15))
                        .foregroundColor(.dropInCoral)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, DropInLayout.screenMargin)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
//        .doodleAccents()
        .onAppear {
            selectedAvatar = authViewModel.currentUser?.avatarUrl
        }
    }

    private func avatarOption(_ name: String) -> some View {
        let isSelected = name == selectedAvatar
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedAvatar = name
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    name: name,
                    imageName: name,
                    size: 56,
                    ringColor: isSelected ? .dropInCoral : .white
                )
                .scaleEffect(isSelected ? 1.08 : 1)

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.dropInCoral)
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
            }
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.dropInIndigo.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.75))
                .clipShape(Circle())
        }
    }
}

#Preview {
    ProfileView().environment(AuthViewModel())
}
