//
//  NudgeCardView.swift
//  DropIn
//
//  A "Who's Down?" nudge in the feed. Friends who were asked can answer;
//  the sender sees who's down and can end it early.
//

import SwiftUI

struct NudgeCardView: View {
    let nudge: Nudge
    let currentUserId: String
    let usersById: [String: User]
    var onRespond: (NudgeResponse) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onReport: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil

    private var isMine: Bool { nudge.fromUserId == currentUserId }
    private var myResponse: NudgeResponse? { nudge.response(from: currentUserId) }

    var body: some View {
        // Re-renders every 30s so the "12m left" countdown stays current.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    AvatarView(
                        name: usersById[nudge.fromUserId]?.name ?? nudge.fromName,
                        imageName: usersById[nudge.fromUserId]?.avatarUrl,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isMine ? "Your nudge" : "\(nudge.fromName) asks")
                            .font(DropInFont.bodyMedium(14))
                            .foregroundColor(.dropInIndigo)
                        Text(isMine ? "Only the friends you picked can see this" : "Just you and a few friends")
                            .font(DropInFont.body(11))
                            .foregroundColor(.dropInIndigo.opacity(0.5))
                    }
                    Spacer()
                    Text(nudge.timeLeftLabel(now: context.date))
                        .font(DropInFont.bodyMedium(12))
                        .foregroundColor(.dropInIndigo.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.7)))
                    if isMine {
                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.dropInIndigo.opacity(0.6))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("End nudge")
                    } else if onReport != nil || onBlock != nil {
                        Menu {
                            if let onReport {
                                Button(action: onReport) {
                                    Label("Report Nudge", systemImage: "flag")
                                }
                            }
                            if let onBlock {
                                Button(role: .destructive, action: onBlock) {
                                    Label("Block \(nudge.fromName)", systemImage: "hand.raised.slash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.dropInIndigo.opacity(0.6))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.7)))
                                .contentShape(Circle())
                        }
                        .accessibilityLabel("More options")
                    }
                }

                Text("\u{201C}\(nudge.message)\u{201D}")
                    .font(DropInFont.bodyMedium(17))
                    .foregroundColor(.dropInIndigo)

                if isMine {
                    senderSummary
                } else {
                    responseButtons
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.dropInCoral.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.dropInCoral.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
            )
        }
    }

    private var responseButtons: some View {
        HStack(spacing: 10) {
            responseButton(.down, title: "I'm down", icon: "hand.thumbsup.fill")
            responseButton(.notNearby, title: "Not nearby", icon: "location.slash.fill")
        }
    }

    private func responseButton(_ response: NudgeResponse, title: String, icon: String) -> some View {
        let isSelected = myResponse == response
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onRespond(response)
        } label: {
            Label(title, systemImage: icon)
                .font(DropInFont.bodyMedium(14))
                .foregroundColor(isSelected ? .white : .dropInIndigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(isSelected ? (response == .down ? Color.dropInCoral : Color.dropInIndigo) : Color.white))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var senderSummary: some View {
        let down = nudge.downUserIds
        let notNearby = nudge.toUserIds.filter { nudge.responses[$0] == .notNearby }.count
        let waiting = nudge.toUserIds.count - down.count - notNearby
        return HStack(spacing: 8) {
            if !down.isEmpty {
                HStack(spacing: -8) {
                    ForEach(down, id: \.self) { id in
                        AvatarView(name: usersById[id]?.name ?? "Friend", imageName: usersById[id]?.avatarUrl, size: 26)
                    }
                }
            }
            Text(summaryText(down: down.count, notNearby: notNearby, waiting: waiting))
                .font(DropInFont.body(13))
                .foregroundColor(.dropInIndigo.opacity(0.7))
        }
    }

    private func summaryText(down: Int, notNearby: Int, waiting: Int) -> String {
        var parts: [String] = []
        if down > 0 { parts.append("\(down) down") }
        if notNearby > 0 { parts.append("\(notNearby) not nearby") }
        if waiting > 0 { parts.append("\(waiting) waiting") }
        return parts.joined(separator: " · ")
    }
}
