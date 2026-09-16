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

                if live.isEmpty && upcoming.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
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
                    .padding(.trailing, DropInLayout.screenMargin)
                    .padding(.bottom, 24)
                }
            }
        }
//        .doodleAccents()
        .sheet(isPresented: $showCreateSheet) {
            CreateStatusSheet { newStatus in
                homeViewModel.addStatus(newStatus)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
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
            onTapAttend: {
                homeViewModel.toggleAttendance(for: status, currentUserId: currentUserId)
            },
            onTogglePause: isOwn ? { homeViewModel.togglePause(for: status) } : nil
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
                Spacer()
                profileButton
            }
        }
        .padding(.horizontal, DropInLayout.screenMargin)
        .padding(.top, 16)
        .padding(.bottom, 6)
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
            Text("No plans right now")
                .font(DropInFont.bodyMedium(17))
                .foregroundColor(.dropInIndigo.opacity(0.7))
            Text("Tap + to broadcast what you're up to")
                .font(DropInFont.body(13))
                .foregroundColor(.dropInIndigo.opacity(0.45))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, DropInLayout.screenMargin)
    }
}

#Preview {
    HomeFeedView().environment(AuthViewModel())
}
