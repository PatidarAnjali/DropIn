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
    /// Only ever wired up for the signed-in user's own hangs — lets
    /// them quietly go invisible without any "you were unpaused"-style
    /// notice going to friends.
    var onTogglePause: (() -> Void)? = nil

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

    /// Whether the signed-in user has already RSVP'd to this hang, so
    /// the button can flip to an "undo" state instead of always reading
    /// like a fresh invite.
    private var isAttending: Bool {
        guard let currentUserId else { return false }
        return status.attendees.contains(currentUserId)
    }

    private var attendLabel: String {
        if isOwnStatus { return "Drop In" }
        if isAttending { return "Can't Make It" }
        return status.isUpcoming ? "I'm In" : "I'm Coming!"
    }

    private var attendIcon: String {
        if isOwnStatus { return "sparkles" }
        return isAttending ? "xmark" : "hand.wave.fill"
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

                HStack(spacing: 6) {
                    if status.isPrivate {
                        privacyBadge
                    }

                    Text(status.timingLabel)
                        .font(DropInFont.bodyMedium(11))
                        .foregroundColor(.dropInIndigo.opacity(0.6))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.65))
                        .clipShape(Capsule())

                    if isOwnStatus, let onTogglePause {
                        pauseButton(action: onTogglePause)
                    }
                }
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

            if isOwnStatus && status.isPaused {
                Label("Paused — only you can see this right now", systemImage: "eye.slash.fill")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.55))
            }

            HStack {
                Button(action: onTapAttend) {
                    HStack(spacing: 6) {
                        Image(systemName: attendIcon)
                            .font(.system(size: 12))
                        Text(attendLabel)
                            .font(DropInFont.bodyMedium(14))
                    }
                    .foregroundColor(isAttending ? .dropInIndigo.opacity(0.7) : .white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(isAttending ? Color.white.opacity(0.85) : Color.dropInIndigo)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.dropInIndigo.opacity(isAttending ? 0.2 : 0), lineWidth: 1)
                    )
                    .shadow(color: Color.dropInIndigo.opacity(isAttending ? 0.08 : 0.25), radius: 6, y: 3)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAttending)

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
        .background(Color(hex: status.category.tint).opacity(status.isPaused ? 0.3 : 0.6))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.dropInIndigo.opacity(0.07), radius: 12, y: 6)
    }

    /// Visible only to the poster (everyone else who can even see this
    /// card was already one of the people invited), just a quiet
    /// reminder of who it's limited to.
    private var privacyBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.dropInIndigo.opacity(0.55))
            .padding(6)
            .background(Color.white.opacity(0.65))
            .clipShape(Circle())
    }

    private func pauseButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: status.isPaused ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.dropInIndigo.opacity(0.6))
                .padding(6)
                .background(Color.white.opacity(0.65))
                .clipShape(Circle())
        }
    }
}

#Preview {
    VStack(spacing: 14) {
        StatusRowView(status: MockData.statuses[0], isOwnStatus: false, onTapAttend: {})
        StatusRowView(status: MockData.statuses[1], isOwnStatus: true, onTapAttend: {}, onTogglePause: {})
    }
    .padding()
    .background(Color.dropInCream)
}
