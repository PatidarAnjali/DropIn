//
//  NudgeSheet.swift
//  DropIn
//
//  "Who's Down?": privately ask up to 4 friends if anyone's around,
//  without posting to the feed.
//

import SwiftUI

struct NudgeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let friends: [User]
    /// Returns an error to show, or nil if the nudge was sent.
    let onSend: (_ message: String, _ recipientIds: [String]) -> NudgeRules.ValidationError?
    var onAddFriends: (() -> Void)? = nil

    @State private var message = ""
    @State private var selectedIds: Set<String> = []
    @State private var error: NudgeRules.ValidationError?

    private let suggestions = ["Anyone free for coffee?", "Who's on campus?", "Walk in 10?", "Food run?"]

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.dropInCoral)
                                Text("Who's Down?")
                                    .font(DropInFont.heading(22))
                                    .foregroundColor(.dropInIndigo)
                            }
                            Text("Privately ask up to \(NudgeRules.maxRecipients) friends if anyone's around. It won't show in the feed, and it disappears in 30 minutes.")
                                .font(DropInFont.body(13))
                                .foregroundColor(.dropInIndigo.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        DropInCloseButton { dismiss() }
                    }

                    if friends.isEmpty {
                        noFriends
                    } else {
                        messageCard
                        friendsCard

                        if let error {
                            Label(error.message, systemImage: "exclamationmark.circle.fill")
                                .font(DropInFont.body(13))
                                .foregroundColor(.dropInCoral)
                        }

                        Button("Send Nudge") {
                            error = onSend(message, Array(selectedIds))
                            if error == nil { dismiss() }
                        }
                        .buttonStyle(DropInPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("What's the idea?", text: $message, axis: .vertical)
                .font(DropInFont.body(16))
                .padding(14)
                .background(Color.dropInCream)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1)
                )

            HStack {
                Spacer()
                Text("\(message.count)/\(NudgeRules.maxMessageLength)")
                    .font(DropInFont.body(11))
                    .foregroundColor(message.count > NudgeRules.maxMessageLength ? .dropInCoral : .dropInIndigo.opacity(0.4))
                    .monospacedDigit()
            }

            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        message = suggestion
                    }
                    .font(DropInFont.body(13))
                    .foregroundColor(.dropInIndigo)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Color.dropInCream))
                    .overlay(Capsule().stroke(Color.dropInIndigo.opacity(0.1), lineWidth: 1))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 20)
    }

    private var friendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ask")
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.dropInIndigo)
                Spacer()
                Text("\(selectedIds.count) of \(NudgeRules.maxRecipients)")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
            }

            FlowLayout(spacing: 8) {
                ForEach(friends, id: \.id) { friend in
                    friendChip(friend)
                }
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 20)
    }

    private func friendChip(_ friend: User) -> some View {
        let id = friend.id ?? ""
        let isSelected = selectedIds.contains(id)
        let isFull = selectedIds.count >= NudgeRules.maxRecipients && !isSelected
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedIds.remove(id)
                } else if !isFull {
                    selectedIds.insert(id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                AvatarView(name: friend.name, imageName: friend.avatarUrl, size: 22)
                Text(friend.name)
                    .font(DropInFont.bodyMedium(13))
            }
            .foregroundColor(isSelected ? .white : .dropInIndigo)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(Capsule().fill(isSelected ? Color.dropInIndigo : Color.white.opacity(0.75)))
            .overlay(Capsule().stroke(Color.dropInIndigo.opacity(isSelected ? 0 : 0.1), lineWidth: 1))
            .opacity(isFull ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var noFriends: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 24))
                .foregroundColor(.dropInCoral.opacity(0.8))
            Text("Add friends first")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)
            Text("Nudges go to friends, so add a few and come back.")
                .font(DropInFont.body(13))
                .foregroundColor(.dropInIndigo.opacity(0.55))
                .multilineTextAlignment(.center)
            if let onAddFriends {
                Button("Add Friends") {
                    dismiss()
                    onAddFriends()
                }
                .buttonStyle(SmallCapsuleButtonStyle(filled: true))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .dropInCard(cornerRadius: 20)
    }
}
