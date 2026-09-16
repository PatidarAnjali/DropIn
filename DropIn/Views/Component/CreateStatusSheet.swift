//
//  CreateStatusSheet.swift
//  DropIn
//

import SwiftUI

private enum TimingMode: String, CaseIterable {
    case now = "Right now"
    case later = "Plan ahead"
}

private enum VisibilityMode: String, CaseIterable {
    case everyone = "Everyone"
    case selected = "Choose friends"
}

struct CreateStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var activityText: String = ""
    @State private var selectedCategory: StatusCategory = .coffee
    @State private var expirationMinutes: Double = 60 // 1 hour default

    // "Plan ahead" (bdenzer's feedback): let a hang start later instead
    // of only ever being live right now.
    @State private var timingMode: TimingMode = .now
    @State private var startDate: Date = Date().addingTimeInterval(30 * 60)

    // Selective visibility (This-Establishment26 / achilltrainer's
    // feedback): not every hang should go to the whole friend group.
    @State private var visibilityMode: VisibilityMode = .everyone
    @State private var selectedFriendIds: Set<String> = []

    let onBroadcast: (Status) -> Void

    private var friendOptions: [String] {
        MockData.allFriendIds.filter { $0 != authViewModel.currentUser?.id }
    }

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.dropInCoral)
                        Text("What are you up to?")
                            .font(DropInFont.heading(22))
                            .foregroundColor(.dropInIndigo)
                        Spacer()
                        DropInCloseButton { dismiss() }
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

                    timingSection

                    visibilitySection

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

                    Button("Broadcast Plan") {
                        broadcast()
                    }
                    .buttonStyle(DropInPrimaryButtonStyle())
                    .disabled(activityText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 28)
            }
        }
//        .doodleAccents()
    }

    // MARK: - Timing ("plan ahead")

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)

            HStack(spacing: 10) {
                ForEach(TimingMode.allCases, id: \.self) { mode in
                    pillToggle(title: mode.rawValue, isSelected: timingMode == mode) {
                        timingMode = mode
                    }
                }
            }

            if timingMode == .later {
                DatePicker(
                    "Starts at",
                    selection: $startDate,
                    in: Date()...,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
                .font(DropInFont.body(14))
                .tint(.dropInCoral)
                .padding(.top, 4)

                Text("Friends will be nudged right when it starts, not before.")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 18)
    }

    // MARK: - Visibility (selective friends)

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who can see this")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)

            HStack(spacing: 10) {
                ForEach(VisibilityMode.allCases, id: \.self) { mode in
                    pillToggle(title: mode.rawValue, isSelected: visibilityMode == mode) {
                        visibilityMode = mode
                    }
                }
            }

            if visibilityMode == .selected {
                FlowLayout(spacing: 8) {
                    ForEach(friendOptions, id: \.self) { friendId in
                        friendChip(friendId)
                    }
                }
                .padding(.top, 4)

                if selectedFriendIds.isEmpty {
                    Text("Pick at least one friend, or this hang won't be visible to anyone.")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInCoral)
                }
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 18)
    }

    private func friendChip(_ friendId: String) -> some View {
        let isSelected = selectedFriendIds.contains(friendId)
        let name = MockData.username(forUserId: friendId) ?? "Friend"
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedFriendIds.remove(friendId)
                } else {
                    selectedFriendIds.insert(friendId)
                }
            }
        } label: {
            HStack(spacing: 6) {
                AvatarView(name: name, imageName: MockData.avatar(forUserId: friendId), size: 22)
                Text(name)
                    .font(DropInFont.bodyMedium(13))
            }
            .foregroundColor(isSelected ? .white : .dropInIndigo)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.dropInIndigo : Color.white.opacity(0.75))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.dropInIndigo.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
            )
        }
    }

    private func pillToggle(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DropInFont.bodyMedium(13))
                .foregroundColor(isSelected ? .white : .dropInIndigo)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(isSelected ? Color.dropInIndigo : Color.white.opacity(0.75))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.dropInIndigo.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
                )
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
        let starts = timingMode == .now ? Date() : max(startDate, Date())
        let visibility: [String]? = visibilityMode == .selected ? Array(selectedFriendIds) : nil

        let newStatus = Status(
            userId: authViewModel.currentUser?.id ?? "me",
            username: authViewModel.currentUser?.name ?? "You",
            activityText: activityText,
            category: selectedCategory,
            createdAt: Date(),
            startsAt: starts,
            expiresAt: starts.addingTimeInterval(expirationMinutes * 60),
            attendees: [],
            avatarImageName: authViewModel.currentUser?.avatarUrl,
            visibleToUserIds: visibility
        )
        onBroadcast(newStatus)
        dismiss()
    }
}

/// Minimal wrapping chip layout so friend chips flow onto multiple
/// lines instead of overflowing or squeezing into one scrollable row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += rowHeight + spacing
                totalHeight = origin.y
                rowHeight = 0
            }
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : origin.x, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: .unspecified)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    CreateStatusSheet(onBroadcast: { _ in })
        .environment(AuthViewModel())
}
