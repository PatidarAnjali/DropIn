//
//  HomeFeedView.swift
//  DropIn
//

import SwiftUI

struct HomeFeedView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var homeViewModel = HomeViewModel()
    @State private var showCreateSheet = false
    @State private var showProfile = false
    @State private var planToEdit: Status?
    @State private var showFriends = false
    @State private var showNudgeSheet = false
    @State private var reportTarget: ReportTarget?
    /// Person waiting on the "Block?" confirmation.
    @State private var blockTarget: (id: String, name: String)?

    private var currentUserId: String {
        authViewModel.currentUser?.id ?? "me"
    }

    var body: some View {
        ZStack {
            // Plain background once inside the app. The hand-drawn
            // wallpaper only appears on the Login screen (the moment the
            // app opens) — everyday use inside the app stays clean, with
            // just a couple of faint doodle accents for texture.
            Color.dropInCream.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                Rectangle()
                    .fill(Color.dropInIndigo.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, DropInLayout.screenMargin)

                let live = homeViewModel.liveStatuses(for: currentUserId)
                let upcoming = homeViewModel.upcomingStatuses(for: currentUserId)
                let nudges = homeViewModel.activeNudgesFromMe() + homeViewModel.activeNudgesToMe()

                if live.isEmpty && upcoming.isEmpty && nudges.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if !nudges.isEmpty {
                                sectionHeader(title: "Who's Down?", systemImage: "hand.raised.fill")
                                ForEach(nudges) { nudge in
                                    NudgeCardView(
                                        nudge: nudge,
                                        currentUserId: currentUserId,
                                        usersById: homeViewModel.usersById,
                                        onRespond: { response in
                                            homeViewModel.respond(to: nudge, with: response, me: currentUserId)
                                        },
                                        onDelete: { homeViewModel.deleteNudge(nudge) },
                                        onReport: {
                                            reportTarget = ReportTarget(
                                                userId: nudge.fromUserId,
                                                userName: nudge.fromName,
                                                kind: .nudge,
                                                contentId: nudge.id,
                                                contentText: nudge.message
                                            )
                                        },
                                        onBlock: { blockTarget = (nudge.fromUserId, nudge.fromName) }
                                    )
                                }
                            }

                            if !upcoming.isEmpty {
                                sectionHeader(
                                    title: "Starting Soon",
                                    systemImage: "clock.fill"
                                )
                                ForEach(upcoming) { status in
                                    statusRow(for: status)
                                }
                            }

                            if !live.isEmpty {
                                sectionHeader(
                                    title: "Live Now",
                                    systemImage: "dot.radiowaves.left.and.right"
                                )
                                    .padding(.top, upcoming.isEmpty ? 0 : 6)
                                ForEach(live) { status in
                                    statusRow(for: status)
                                }
                            } else if !upcoming.isEmpty {
                                // Nothing live right now, but there IS
                                // something upcoming — say so plainly
                                // instead of leaving a dead gap, so
                                // nobody assumes the app is broken or
                                // empty (the "empty room" problem).
                                Text("Nothing live yet; check back when one of these starts.")
                                    .font(DropInFont.body(13))
                                    .foregroundColor(.dropInIndigo.opacity(0.45))
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, DropInLayout.screenMargin)
                        .padding(.top, 18)
                        // Extra bottom room so the last card never sits
                        // underneath the floating action button.
                        .padding(.bottom, 100)
                    }
                }
            }

            // Floating action button to broadcast a new status
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button {
                            showNudgeSheet = true
                        } label: {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.dropInCoral)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color.white))
                                .overlay(Circle().stroke(Color.dropInCoral.opacity(0.25), lineWidth: 1))
                                .shadow(color: Color.dropInIndigo.opacity(0.12), radius: 8, y: 4)
                        }
                        .accessibilityLabel("Who's Down? Nudge a few friends")

                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 58, height: 58)
                                .background(
                                    LinearGradient(
                                        colors: [Color.dropInCoral, Color.dropInCoral.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                                .shadow(color: Color.dropInCoral.opacity(0.4), radius: 12, y: 6)
                        }
                        .accessibilityLabel("Post a plan")
                    }
                    .padding(.trailing, DropInLayout.screenMargin)
                    .padding(.bottom, 24)
                }
            }
        }
//        .doodleAccents()
        .alert(
            "Couldn't update your RSVP",
            isPresented: Binding(
                get: { homeViewModel.rsvpMessage != nil },
                set: { if !$0 { homeViewModel.rsvpMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(homeViewModel.rsvpMessage ?? "")
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateStatusSheet(friends: homeViewModel.friendOptions(excluding: currentUserId)) { newStatus in
                homeViewModel.addStatus(newStatus)
            }
        }
        .sheet(item: $planToEdit) { plan in
            CreateStatusSheet(editing: plan, friends: homeViewModel.friendOptions(excluding: currentUserId)) { updated in
                homeViewModel.updateStatus(updated, original: plan)
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { reason, details, alsoBlock in
                await homeViewModel.submitReport(target, reason: reason, details: details, alsoBlock: alsoBlock, me: currentUserId)
            }
        }
        .confirmationDialog(
            "Block \(blockTarget?.name ?? "this person")?",
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let blockTarget {
                    homeViewModel.block(userId: blockTarget.id, me: currentUserId)
                }
            }
        } message: {
            Text("You'll unfriend each other and stop seeing each other's plans and nudges. They won't be told. You can unblock them from the Friends screen.")
        }
        .sheet(isPresented: $showFriends) {
            FriendsView(homeViewModel: homeViewModel)
        }
        .sheet(isPresented: $showNudgeSheet) {
            NudgeSheet(
                friends: homeViewModel.friendOptions(excluding: currentUserId),
                onSend: { message, recipients in
                    guard let me = authViewModel.currentUser else { return .noRecipients }
                    return homeViewModel.sendNudge(message: message, to: recipients, me: me)
                },
                onAddFriends: {
                    Task {
                        // Let the nudge sheet finish closing first.
                        try? await Task.sleep(for: .milliseconds(400))
                        showFriends = true
                    }
                }
            )
        }
        .task(id: authViewModel.currentUser?.id) {
            if let id = authViewModel.currentUser?.id {
                homeViewModel.startSocialListeners(for: id)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(homeViewModel: homeViewModel)
        }
        .onAppear {
            // Ask up front so the very first hang someone broadcasts can
            // actually nudge friends, instead of silently failing later.
            NotificationService.shared.requestAuthorizationIfNeeded()
        }
    }

    @ViewBuilder
    private func statusRow(for status: Status) -> some View {
        let isOwn = status.userId == currentUserId
        StatusRowView(
            status: status,
            isOwnStatus: isOwn,
            currentUserId: authViewModel.currentUser?.id,
            currentUserName: authViewModel.currentUser?.name,
            currentUserAvatar: authViewModel.currentUser?.avatarUrl,
            usersById: homeViewModel.usersById,
            blockedByMeIds: homeViewModel.blockedByMeIds(),
            blockedMeIds: homeViewModel.blockedMeIds(),
            onTapAttend: {
                homeViewModel.toggleAttendance(for: status, currentUserId: currentUserId)
            },
            onTogglePause: isOwn ? { homeViewModel.togglePause(for: status) } : nil,
            onEdit: isOwn ? { planToEdit = status } : nil,
            onDelete: isOwn ? { homeViewModel.deleteStatus(status) } : nil,
            onReport: isOwn ? nil : {
                reportTarget = ReportTarget(
                    userId: status.userId,
                    userName: status.username,
                    kind: .plan,
                    contentId: status.id,
                    contentText: status.activityText
                )
            },
            onBlock: isOwn ? nil : { blockTarget = (status.userId, status.username) }
        )
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(DropInFont.bodyMedium(13))
        }
        .foregroundColor(.dropInIndigo.opacity(0.55))
        .padding(.horizontal, 4)
    }

    /// Custom header replacing a native NavigationStack toolbar. A plain
    /// VStack respects the safe area automatically, so this sits neatly
    /// below the dynamic island.
    private var header: some View {
        ZStack {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                Text("DropIn")
                    .font(DropInFont.brand(28))
                    .foregroundColor(.dropInIndigo)
            }
            .frame(maxWidth: .infinity)

            HStack {
                friendsButton
                Spacer()
                profileButton
            }
        }
        .padding(.horizontal, DropInLayout.screenMargin)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private var friendsButton: some View {
        let requestCount = homeViewModel.incomingRequests(for: currentUserId).count
        return Button {
            showFriends = true
        } label: {
            Image(systemName: "person.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.dropInIndigo.opacity(0.75))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if requestCount > 0 {
                        Text("\(requestCount)")
                            .font(DropInFont.bodyMedium(11))
                            .foregroundColor(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Circle().fill(Color.dropInCoral))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .accessibilityLabel(requestCount > 0 ? "Friends, \(requestCount) new requests" : "Friends")
    }

    private var profileButton: some View {
        Button {
            showProfile = true
        } label: {
            AvatarView(
                name: authViewModel.currentUser?.name ?? "You",
                imageName: authViewModel.currentUser?.avatarUrl,
                size: 38
            )
        }
    }

    private var searchBar: some View {
        @Bindable var homeViewModel = homeViewModel
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.dropInIndigo.opacity(0.4))
            TextField("Search what friends are up to", text: $homeViewModel.searchText)
                .font(DropInFont.body(15))

            if !homeViewModel.searchText.isEmpty {
                Button {
                    homeViewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.dropInIndigo.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dropInIndigo.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: Color.dropInIndigo.opacity(0.05), radius: 8, y: 3)
        .padding(.horizontal, DropInLayout.screenMargin)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.dropInIndigo.opacity(0.06), radius: 10, y: 4)
                Image(systemName: "eye")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.dropInIndigo.opacity(0.6))
            }
            if homeViewModel.friendIds(of: currentUserId).isEmpty {
                Text("Add friends to see their plans")
                    .font(DropInFont.bodyMedium(17))
                    .foregroundColor(.dropInIndigo.opacity(0.7))
                Text("DropIn only shows plans from your friends.")
                    .font(DropInFont.body(13))
                    .foregroundColor(.dropInIndigo.opacity(0.45))
                Button("Add Friends") {
                    showFriends = true
                }
                .buttonStyle(SmallCapsuleButtonStyle(filled: true))
                .padding(.top, 4)
            } else {
                Text("No plans right now")
                    .font(DropInFont.bodyMedium(17))
                    .foregroundColor(.dropInIndigo.opacity(0.7))
                Text("Tap + to post a plan, or \u{270B} to ask who's down")
                    .font(DropInFont.body(13))
                    .foregroundColor(.dropInIndigo.opacity(0.45))
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, DropInLayout.screenMargin)
    }
}

#Preview {
    HomeFeedView().environment(AuthViewModel())
}
