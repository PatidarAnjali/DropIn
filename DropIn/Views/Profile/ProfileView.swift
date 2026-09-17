//
//  ProfileView.swift
//  DropIn
//
//  Your avatar, a few stats, and every plan you've posted, with options
//  to edit, pause, or delete them. Past plans can be deleted one at a time or
//  all at once.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    let homeViewModel: HomeViewModel

    @State private var showBuilder = false
    @State private var planToDelete: Status?
    @State private var planToEdit: Status?
    @State private var showDeleteAccount = false
    @State private var confirmClearPast = false

    private var userId: String { authViewModel.currentUser?.id ?? "" }
    private var avatarString: String? { authViewModel.currentUser?.avatarUrl }
    private var hasCustomAvatar: Bool { AvatarConfig(storageString: avatarString) != nil }

    private var activePlans: [Status] { homeViewModel.activePlans(postedBy: userId) }
    private var pastPlans: [Status] { homeViewModel.pastPlans(postedBy: userId) }

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text("Your Profile")
                            .font(DropInFont.heading(24))
                            .foregroundColor(.dropInIndigo)
                        Spacer()
                        DropInCloseButton { dismiss() }
                    }

                    identity
                    statsCard
                    activePlansSection
                    if !pastPlans.isEmpty {
                        pastPlansSection
                    }

                    Button {
                        authViewModel.signOut()
                        dismiss()
                    } label: {
                        Text("Sign Out")
                            .font(DropInFont.bodyMedium(15))
                            .foregroundColor(.dropInCoral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDeleteAccount = true
                    } label: {
                        Text("Delete Account")
                            .font(DropInFont.body(13))
                            .foregroundColor(.dropInIndigo.opacity(0.45))
                            .underline()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -12)
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
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
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView()
        }
        .sheet(item: $planToEdit) { plan in
            CreateStatusSheet(editing: plan, friends: homeViewModel.friendOptions(excluding: authViewModel.currentUser?.id)) { updated in
                homeViewModel.updateStatus(updated, original: plan)
            }
        }
        .confirmationDialog(
            "Delete this plan?",
            isPresented: Binding(get: { planToDelete != nil }, set: { if !$0 { planToDelete = nil } }),
            titleVisibility: .visible,
            presenting: planToDelete
        ) { plan in
            Button("Delete Plan", role: .destructive) {
                homeViewModel.deleteStatus(plan)
            }
        } message: { plan in
            Text(plan.isExpired
                 ? "This removes it from your history. This can't be undone."
                 : "Friends won't see it anymore. This can't be undone.")
        }
        .confirmationDialog("Clear all past plans?", isPresented: $confirmClearPast, titleVisibility: .visible) {
            Button("Delete \(pastPlans.count) Past \(pastPlans.count == 1 ? "Plan" : "Plans")", role: .destructive) {
                homeViewModel.deletePastPlans(postedBy: userId)
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Avatar + name

    private var identity: some View {
        VStack(spacing: 10) {
            Button {
                showBuilder = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(
                        name: authViewModel.currentUser?.name ?? "You",
                        imageName: avatarString,
                        size: 116,
                        ringColor: .white
                    )
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.dropInCoral)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasCustomAvatar ? "Edit avatar" : "Create avatar")

            VStack(spacing: 2) {
                Text(authViewModel.currentUser?.name ?? "You")
                    .font(DropInFont.bodyMedium(19))
                    .foregroundColor(.dropInIndigo)
                if let email = authViewModel.currentUser?.email {
                    Text(email)
                        .font(DropInFont.body(13))
                        .foregroundColor(.dropInIndigo.opacity(0.5))
                }
            }

            Button {
                showBuilder = true
            } label: {
                Label(hasCustomAvatar ? "Edit Avatar" : "Create Your Avatar", systemImage: "paintbrush.pointed.fill")
                    .font(DropInFont.bodyMedium(13))
                    .foregroundColor(.dropInCoral)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.dropInCoral.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsCard: some View {
        let stats = homeViewModel.stats(for: userId)
        return HStack(spacing: 0) {
            statColumn(value: stats.plansPosted, label: "Plans\nposted", icon: "megaphone.fill")
            divider
            statColumn(value: stats.friendsDroppedIn, label: "Friends\ndropped in", icon: "hand.wave.fill")
            divider
            statColumn(value: stats.plansJoined, label: "Plans\njoined", icon: "figure.walk")
        }
        .padding(.vertical, 16)
        .dropInCard(cornerRadius: 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.dropInIndigo.opacity(0.08))
            .frame(width: 1, height: 44)
    }

    private func statColumn(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.dropInCoral)
            Text("\(value)")
                .font(DropInFont.heading(22))
                .foregroundColor(.dropInIndigo)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(DropInFont.body(11))
                .foregroundColor(.dropInIndigo.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    private var activePlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Your Plans", count: activePlans.count)

            if activePlans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.dropInCoral.opacity(0.8))
                    Text("No plans right now")
                        .font(DropInFont.bodyMedium(14))
                        .foregroundColor(.dropInIndigo)
                    Text("Post what you're up to from the home screen and it'll show up here.")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .dropInCard(cornerRadius: 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(activePlans) { plan in
                        planRow(plan, isPast: false)
                    }
                }
            }
        }
    }

    private var pastPlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Past Plans", count: pastPlans.count)
                Spacer()
                Button("Clear All") { confirmClearPast = true }
                    .font(DropInFont.bodyMedium(13))
                    .foregroundColor(.dropInCoral)
            }

            VStack(spacing: 10) {
                // Show the most recent few so the page doesn't get endless.
                ForEach(pastPlans.prefix(10)) { plan in
                    planRow(plan, isPast: true)
                }
            }

            if pastPlans.count > 10 {
                Text("Showing your 10 most recent. Clear All removes all \(pastPlans.count).")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
            }
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(DropInFont.bodyMedium(16))
                .foregroundColor(.dropInIndigo)
            if count > 0 {
                Text("\(count)")
                    .font(DropInFont.bodyMedium(12))
                    .foregroundColor(.dropInIndigo.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.8))
                    .clipShape(Capsule())
            }
        }
    }

    private func planRow(_ plan: Status, isPast: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: plan.category.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.dropInIndigo)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(hex: plan.category.tint).opacity(isPast ? 0.35 : 0.8)))

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.activityText)
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.dropInIndigo.opacity(isPast ? 0.6 : 1))
                    .lineLimit(1)
                Text(detailLine(for: plan, isPast: isPast))
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isPast {
                Button {
                    planToDelete = plan
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.dropInCoral)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.dropInCoral.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(plan.activityText)")
            } else {
                Menu {
                    Button {
                        planToEdit = plan
                    } label: {
                        Label("Edit Plan", systemImage: "pencil")
                    }
                    Button {
                        homeViewModel.togglePause(for: plan)
                    } label: {
                        Label(plan.isPaused ? "Show to Friends" : "Pause (Hide from Friends)",
                              systemImage: plan.isPaused ? "eye.fill" : "eye.slash.fill")
                    }
                    Button(role: .destructive) {
                        planToDelete = plan
                    } label: {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.dropInIndigo.opacity(0.65))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white))
                        .contentShape(Circle())
                }
                .accessibilityLabel("Options for \(plan.activityText)")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .dropInCard(cornerRadius: 18)
    }

    /// e.g. "Live · Expiring in 45m · 2 dropping in · Paused"
    private func detailLine(for plan: Status, isPast: Bool) -> String {
        var parts: [String] = []
        if isPast {
            parts.append("Ended \(plan.expiresAt.formatted(.relative(presentation: .named)))")
        } else {
            parts.append(plan.isUpcoming ? plan.startLabel : "Live · \(plan.expiryLabel)")
        }
        let count = plan.attendees.count
        if count > 0 {
            parts.append(count == 1 ? "1 dropped in" : "\(count) dropped in")
        }
        if plan.isPaused && !isPast {
            parts.append("Paused")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    ProfileView(homeViewModel: HomeViewModel())
        .environment(AuthViewModel())
}
