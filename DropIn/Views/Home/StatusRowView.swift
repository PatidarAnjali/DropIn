//
//  StatusRowView.swift
//  DropIn
//
//  One card in the Live Feed — matches the colored cards in the mockup
//  (name, activity, expiry pill, avatar stack, and a "Drop In" / "I'm Coming!" button).
//

import SwiftUI

struct StatusRowView: View {
    let status: Status
    let isOwnStatus: Bool
    /// The signed-in user's id, name, and currently-chosen avatar, so a
    /// poster or attendee who picked a new avatar (or has none yet)
    /// always shows the right image — or the right initial — instead of
    /// a stale/mock one.
    var currentUserId: String? = nil
    var currentUserName: String? = nil
    var currentUserAvatar: String? = nil
    let onTapAttend: () -> Void

    private var posterAvatar: String? {
        status.userId == currentUserId ? currentUserAvatar : status.avatarImageName
    }

    private func avatar(forAttendee attendeeId: String) -> String? {
        attendeeId == currentUserId ? currentUserAvatar : MockData.avatar(forUserId: attendeeId)
    }

    /// A real, human name to fall back on for the initials bubble — never
    /// the raw user id itself, since ids (especially UUIDs) often start
    /// with a digit rather than a letter.
    private func displayName(forAttendee attendeeId: String) -> String {
        if attendeeId == currentUserId {
            return currentUserName ?? "You"
        }
        return MockData.username(forUserId: attendeeId) ?? "Friend"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    AvatarView(name: status.username, imageName: posterAvatar, size: 36)
                    Text(status.username)
                        .font(DropInFont.bodyMedium(16))
                        .foregroundColor(.dropInIndigo)
                }

                Spacer()

                Text(status.expiryLabel)
                    .font(DropInFont.bodyMedium(11))
                    .foregroundColor(.dropInIndigo.opacity(0.6))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.65))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                    Image(systemName: status.category.systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.dropInIndigo)
                }
                Text(status.activityText)
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.dropInIndigo)
                    .lineLimit(2)
            }

            HStack {
                Button(action: onTapAttend) {
                    HStack(spacing: 6) {
                        Image(systemName: isOwnStatus ? "sparkles" : "hand.wave.fill")
                            .font(.system(size: 12))
                        Text(isOwnStatus ? "Drop In" : "I'm Coming!")
                            .font(DropInFont.bodyMedium(14))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.dropInIndigo)
                    .clipShape(Capsule())
                    .shadow(color: Color.dropInIndigo.opacity(0.25), radius: 6, y: 3)
                }

                Spacer()

                // Avatar stack for people already attending
                if !status.attendees.isEmpty {
                    HStack(spacing: -10) {
                        ForEach(status.attendees.prefix(3), id: \.self) { attendeeId in
                            AvatarView(
                                name: displayName(forAttendee: attendeeId),
                                imageName: avatar(forAttendee: attendeeId),
                                size: 28
                            )
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(hex: status.category.tint).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.dropInIndigo.opacity(0.07), radius: 12, y: 6)
    }
}

#Preview {
    VStack(spacing: 14) {
        StatusRowView(status: MockData.statuses[0], isOwnStatus: false, onTapAttend: {})
        StatusRowView(status: MockData.statuses[1], isOwnStatus: true, onTapAttend: {})
    }
    .padding()
    .background(Color.dropInCream)
}
