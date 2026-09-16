//
//  CreateStatusSheet.swift
//  DropIn
//

import SwiftUI

struct CreateStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var activityText: String = ""
    @State private var selectedCategory: StatusCategory = .coffee
    @State private var expirationMinutes: Double = 60 // 1 hour default

    let onBroadcast: (Status) -> Void

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.dropInCoral)
                    Text("What are you up to?")
                        .font(DropInFont.heading(22))
                        .foregroundColor(.dropInIndigo)
                    Spacer()
                    closeButton
                }

                TextField("E.g., Grabbing coffee...", text: $activityText, axis: .vertical)
                    .font(DropInFont.body(16))
                    .padding(16)
                    .background(Color.white.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(DropInFont.bodyMedium(15))
                        .foregroundColor(.dropInIndigo)

                    HStack(spacing: 12) {
                        ForEach(StatusCategory.allCases, id: \.self) { category in
                            categoryButton(category)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Expiration")
                        .font(DropInFont.bodyMedium(15))
                        .foregroundColor(.dropInIndigo)

                    Slider(value: $expirationMinutes, in: 30...720, step: 30)
                        .tint(.dropInCoral)

                    HStack {
                        Text("1 hour")
                        Spacer()
                        Text("3 hours")
                        Spacer()
                        Text("Tonight")
                    }
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
                }
                .padding(18)
                .dropInCard(cornerRadius: 18)

                Spacer()

                Button("Broadcast Plan") {
                    broadcast()
                }
                .buttonStyle(DropInPrimaryButtonStyle())
                .disabled(activityText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 28)
        }
        .doodleAccents()
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

    private func categoryButton(_ category: StatusCategory) -> some View {
        let isSelected = category == selectedCategory
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedCategory = category
            }
        } label: {
            Image(systemName: category.systemImage)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : .dropInIndigo)
                .frame(width: 50, height: 50)
                .background(isSelected ? Color.dropInIndigo : Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.dropInIndigo.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                )
                .shadow(color: Color.dropInIndigo.opacity(isSelected ? 0.2 : 0), radius: 8, y: 4)
                .scaleEffect(isSelected ? 1.05 : 1)
        }
    }

    private func broadcast() {
        let newStatus = Status(
            userId: authViewModel.currentUser?.id ?? "me",
            username: authViewModel.currentUser?.name ?? "You",
            activityText: activityText,
            category: selectedCategory,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(expirationMinutes * 60),
            attendees: [],
            avatarImageName: authViewModel.currentUser?.avatarUrl
        )
        onBroadcast(newStatus)
        dismiss()
    }
}

#Preview {
    CreateStatusSheet(onBroadcast: { _ in })
        .environment(AuthViewModel())
}
