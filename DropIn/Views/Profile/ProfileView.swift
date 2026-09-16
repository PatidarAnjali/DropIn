//
//  ProfileView.swift
//  DropIn
//
//  Shows the signed-in user's avatar and opens AvatarBuilderView to
//  customize it. Plain cream background, matching every other screen
//  besides Home.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var showBuilder = false

    private var avatarString: String? { authViewModel.currentUser?.avatarUrl }
    private var hasCustomAvatar: Bool { AvatarConfig(storageString: avatarString) != nil }

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Your Profile")
                        .font(DropInFont.heading(24))
                        .foregroundColor(.dropInIndigo)
                    Spacer()
                    DropInCloseButton { dismiss() }
                }

                VStack(spacing: 12) {
                    Button {
                        showBuilder = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(
                                name: authViewModel.currentUser?.name ?? "You",
                                imageName: avatarString,
                                size: 132,
                                ringColor: .white
                            )

                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.dropInCoral)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit avatar")

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
                .padding(.top, 12)

                Spacer()

                Button(hasCustomAvatar ? "Edit Avatar" : "Create Your Avatar") {
                    showBuilder = true
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
            .padding(.horizontal, DropInLayout.sheetMargin)
            .padding(.top, DropInLayout.sheetTopPadding)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showBuilder) {
            // Start from their saved avatar, or a plain body if they
            // don't have one yet (or still have an old premade pick).
            AvatarBuilderView(initial: AvatarConfig(storageString: avatarString) ?? AvatarConfig()) { newAvatar in
                authViewModel.updateAvatar(newAvatar.storageString)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

}

#Preview {
    ProfileView().environment(AuthViewModel())
}
