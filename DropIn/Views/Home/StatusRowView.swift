//
//  StatusRowView.swift
//  DropIn
//
//  One card in the Live Feed; matches the colored cards in the mockup
//  (name, activity, expiry pill, avatar stack, and an "I'm Coming!" button).
//
//  The person who made the plan never gets an RSVP button on their own
//  card; they get a "who's coming" button instead. Everyone who can see
//  a plan can tap the avatar stack to see the full list of who's coming.
//

import SwiftUI

struct StatusRowView: View {
    let status: Status
    let isOwnStatus: Bool
    /// The signed-in user's id, name, and currently-chosen avatar, so a
    /// poster or attendee who picked a new avatar (or has none yet)
    /// always shows the right image (or the right initial) instead of
    /// a stale/mock one.
    var currentUserId: String? = nil
    var currentUserName: String? = nil
    var currentUserAvatar: String? = nil
    /// Real profiles loaded from Firestore (see HomeViewModel.usersById),
    /// used to show attendees' actual names and avatars.
    var usersById: [String: User] = [:]
    /// People the viewer blocked. They're hidden from the attendee list,
    /// and the card shows a heads-up that someone blocked is going.
    var blockedByMeIds: Set<String> = []
    /// People who blocked the viewer. Hidden silently, so the viewer is
    /// never told someone blocked them.
    var blockedMeIds: Set<String> = []
    let onTapAttend: () -> Void
    /// Only ever wired up for the signed-in user's own hangs; lets
    /// them quietly go invisible without any "you were unpaused"-style
    /// notice going to friends.
    var onTogglePause: (() -> Void)? = nil
    /// Only passed for the poster's own plans.
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    /// Only passed for other people's plans.
    var onReport: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil

    @State private var confirmDelete = false

    @State private var showAttendees = false

    /// Attendees the viewer is allowed to see.
    private var visibleAttendees: [String] {
        status.attendees.filter { !blockedByMeIds.contains($0) && !blockedMeIds.contains($0) }
    }

    /// How many people the viewer blocked are going.
    private var blockedAttendeeCount: Int {
        status.attendees.filter { blockedByMeIds.contains($0) }.count
    }

    private var posterAvatar: String? {
        if status.userId == currentUserId { return currentUserAvatar }
        // Prefer their current avatar over the one saved when they posted.
        return usersById[status.userId]?.avatarUrl ?? status.avatarImageName
    }

    private func avatar(forAttendee attendeeId: String) -> String? {
        if attendeeId == currentUserId { return currentUserAvatar }
        if let user = usersById[attendeeId] { return user.avatarUrl }
        return MockData.avatar(forUserId: attendeeId) // Xcode Previews only
    }

    /// A real, human name to fall back on for the initials bubble — never
    /// the raw user id itself, since ids (especially UUIDs) often start
    /// with a digit rather than a letter.
    private func displayName(forAttendee attendeeId: String) -> String {
        if attendeeId == currentUserId {
            return currentUserName ?? "You"
        }
        return usersById[attendeeId]?.name
            ?? MockData.username(forUserId: attendeeId) // Xcode Previews only
            ?? "Friend"
    }

    /// Whether the signed-in user has already RSVP'd to this hang, so
    /// the button can flip to an "undo" state instead of always reading
    /// like a fresh invite.
    private var isAttending: Bool {
        guard let currentUserId else { return false }
        return status.attendees.contains(currentUserId)
    }

    /// Full, and the viewer isn't one of the people who got a seat.
    private var isLockedOut: Bool {
        status.isFull && !isAttending
    }

    /// The button wording matches the plan's vibe.
    private var attendLabel: String {
        if isAttending {
            return status.resolvedIntent == .capped ? "Give Up Seat" : "Can't Make It"
        }
        if isLockedOut { return "Plan's Full" }
        switch status.resolvedIntent {
        case .openDoor: return status.isUpcoming ? "I'm In" : "I'm Coming!"
        case .quiet: return "I'll Sit Nearby"
        case .capped: return "Grab a Seat"
        }
    }

    private var attendIcon: String {
        if isAttending { return "xmark" }
        if isLockedOut { return "lock.fill" }
        switch status.resolvedIntent {
        case .openDoor: return "hand.wave.fill"
        case .quiet: return "laptopcomputer"
        case .capped: return "chair.fill"
        }
    }

    /// Shown to the poster in place of an RSVP button.
    private var attendeeSummary: String {
        let count = status.attendees.count
        if status.resolvedIntent == .capped, let limit = status.seatLimit {
            return count >= limit ? "Full (\(count)/\(limit))" : "\(count) of \(limit) seats taken"
        }
        switch count {
        case 0: return "No one yet"
        case 1: return "1 dropping in"
        default: return "\(count) dropping in"
        }
    }

    private var intentBadgeText: String {
        switch status.resolvedIntent {
        case .openDoor:
            return "Open door"
        case .quiet:
            return "Quiet · bring a laptop"
        case .capped:
            guard let left = status.seatsLeft else { return "Limited seats" }
            if left == 0 { return "Full" }
            return left == 1 ? "1 seat left" : "\(left) seats left"
        }
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

                    if isOwnStatus, onEdit != nil || onTogglePause != nil || onDelete != nil {
                        ownerMenu
                    } else if !isOwnStatus, onReport != nil || onBlock != nil {
                        safetyMenu
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

            intentBadge

            if blockedAttendeeCount > 0 {
                blockedNotice
            }

            if isOwnStatus && status.isPaused {
                Label("Paused — only you can see this right now", systemImage: "eye.slash.fill")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.55))
            }

            HStack {
                if isOwnStatus {
                    whosComingButton
                } else {
                    attendButton
                }

                Spacer()

                // Who's coming: everyone who can see the plan can tap
                // this to see the full list.
                if !visibleAttendees.isEmpty {
                    Button {
                        showAttendees = true
                    } label: {
                        HStack(spacing: 6) {
                            attendeeStack
                            // The host's button already shows the count.
                            if !isOwnStatus {
                                Text("\(visibleAttendees.count) coming")
                                    .font(DropInFont.bodyMedium(12))
                                    .foregroundColor(.dropInIndigo.opacity(0.7))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.dropInIndigo.opacity(0.45))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("See who's coming, \(visibleAttendees.count) \(visibleAttendees.count == 1 ? "person" : "people")")
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
        .sheet(isPresented: $showAttendees) {
            AttendeesSheet(
                activityText: status.activityText,
                blockedCount: blockedAttendeeCount,
                attendees: visibleAttendees.map { id in
                    AttendeeInfo(
                        id: id,
                        name: displayName(forAttendee: id),
                        avatar: avatar(forAttendee: id),
                        isYou: id == currentUserId
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Bottom row buttons

    /// "Someone you blocked is dropping in" heads-up.
    private var blockedNotice: some View {
        let isYourPlan = isOwnStatus
        let text: String
        if blockedAttendeeCount == 1 {
            text = isYourPlan ? "Someone you blocked is dropping in" : "Someone you blocked is going"
        } else {
            text = isYourPlan ? "\(blockedAttendeeCount) people you blocked are dropping in" : "\(blockedAttendeeCount) people you blocked are going"
        }
        return Label(text, systemImage: "hand.raised.slash.fill")
            .font(DropInFont.bodyMedium(12))
            .foregroundColor(.dropInCoral)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Color.white.opacity(0.75)))
            .overlay(Capsule().stroke(Color.dropInCoral.opacity(0.3), lineWidth: 1))
            .accessibilityElement(children: .combine)
    }

    private var intentBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: status.isFull ? "lock.fill" : status.resolvedIntent.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(intentBadgeText)
                .font(DropInFont.bodyMedium(12))
        }
        .foregroundColor(status.isFull ? .dropInCoral : .dropInIndigo.opacity(0.7))
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.55))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    /// RSVP button, only for friends (never the poster).
    private var attendButton: some View {
        Button(action: onTapAttend) {
            HStack(spacing: 6) {
                Image(systemName: attendIcon)
                    .font(.system(size: 12))
                Text(attendLabel)
                    .font(DropInFont.bodyMedium(14))
            }
            .foregroundColor(isAttending || isLockedOut ? .dropInIndigo.opacity(0.7) : .white)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(isAttending || isLockedOut ? Color.white.opacity(0.85) : Color.dropInIndigo)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.dropInIndigo.opacity(isAttending ? 0.2 : 0), lineWidth: 1)
            )
            .shadow(color: Color.dropInIndigo.opacity(isAttending ? 0.08 : 0.25), radius: 6, y: 3)
        }
        .disabled(isLockedOut)
        .opacity(isLockedOut ? 0.75 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAttending)
    }

    /// For the poster: see who said they'll drop in.
    private var whosComingButton: some View {
        Button {
            showAttendees = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                Text(attendeeSummary)
                    .font(DropInFont.bodyMedium(14))
                if !status.attendees.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.6)
                }
            }
            .foregroundColor(.dropInIndigo)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color.white.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.dropInIndigo.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var attendeeStack: some View {
        HStack(spacing: -10) {
            ForEach(visibleAttendees.prefix(3), id: \.self) { attendeeId in
                AvatarView(
                    name: displayName(forAttendee: attendeeId),
                    imageName: avatar(forAttendee: attendeeId),
                    size: 28
                )
            }
            if visibleAttendees.count > 3 {
                Text("+\(visibleAttendees.count - 3)")
                    .font(DropInFont.bodyMedium(11))
                    .foregroundColor(.dropInIndigo)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
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

    /// "..." menu on a friend's plan: report or block.
    private var safetyMenu: some View {
        Menu {
            if let onReport {
                Button(action: onReport) {
                    Label("Report Plan", systemImage: "flag")
                }
            }
            if let onBlock {
                Button(role: .destructive, action: onBlock) {
                    Label("Block \(status.username)", systemImage: "hand.raised.slash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.dropInIndigo.opacity(0.65))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.65))
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("More options")
    }

    /// "..." menu on your own plan: pause/resume and delete.
    private var ownerMenu: some View {
        Menu {
            if let onEdit {
                Button(action: onEdit) {
                    Label("Edit Plan", systemImage: "pencil")
                }
            }
            if let onTogglePause {
                Button(action: onTogglePause) {
                    Label(status.isPaused ? "Show to Friends" : "Pause (Hide from Friends)",
                          systemImage: status.isPaused ? "eye.fill" : "eye.slash.fill")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete Plan", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.dropInIndigo.opacity(0.65))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.65))
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("Plan options")
        .confirmationDialog("Delete this plan?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Plan", role: .destructive) { onDelete?() }
        } message: {
            Text("Friends won't see it anymore. This can't be undone.")
        }
    }
}

// MARK: - Who's dropping in (anyone who can see the plan)

private struct AttendeeInfo: Identifiable {
    let id: String
    let name: String
    let avatar: String?
    var isYou: Bool = false
}

private struct AttendeesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let activityText: String
    var blockedCount: Int = 0
    let attendees: [AttendeeInfo]

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Who's dropping in")
                            .font(DropInFont.heading(22))
                            .foregroundColor(.dropInIndigo)
                        Text(activityText)
                            .font(DropInFont.body(14))
                            .foregroundColor(.dropInIndigo.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer()
                    DropInCloseButton { dismiss() }
                }

                if blockedCount > 0 {
                    Label(
                        blockedCount == 1
                            ? "Someone you blocked is also going. They're hidden from this list."
                            : "\(blockedCount) people you blocked are also going. They're hidden from this list.",
                        systemImage: "hand.raised.slash.fill"
                    )
                    .font(DropInFont.body(13))
                    .foregroundColor(.dropInCoral)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.dropInCoral.opacity(0.1)))
                }

                if attendees.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 26))
                            .foregroundColor(.dropInCoral.opacity(0.8))
                        Text(blockedCount > 0 ? "No one else is coming yet." : "No one has said they're coming yet.")
                            .font(DropInFont.body(15))
                            .foregroundColor(.dropInIndigo.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(attendees) { person in
                                HStack(spacing: 12) {
                                    AvatarView(name: person.name, imageName: person.avatar, size: 40)
                                    Text(person.name)
                                        .font(DropInFont.bodyMedium(16))
                                        .foregroundColor(.dropInIndigo)
                                    if person.isYou {
                                        Text("You")
                                            .font(DropInFont.bodyMedium(11))
                                            .foregroundColor(.dropInCoral)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color.dropInCoral.opacity(0.12)))
                                    }
                                    Spacer()
                                    Image(systemName: "hand.wave.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.dropInCoral)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .dropInCard(cornerRadius: 18)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, DropInLayout.sheetMargin)
            .padding(.top, DropInLayout.sheetTopPadding)
        }
    }
}

#Preview {
    VStack(spacing: 14) {
        StatusRowView(status: MockData.statuses[0], isOwnStatus: false, onTapAttend: {})
        StatusRowView(status: MockData.statuses[1], isOwnStatus: true, onTapAttend: {}, onTogglePause: {}, onEdit: {}, onDelete: {})
    }
    .padding()
    .background(Color.dropInCream)
}
