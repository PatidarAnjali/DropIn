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

    // Vibe of the plan (Open Door / Quiet / Limited Seats).
    @State private var intent: PlanIntent = .openDoor
    @State private var seatLimit: Int = 2

    // AI autofill
    @State private var isAutofilling = false
    @State private var autofillSource: PlanAssistant.Source?

    // "Plan ahead" (bdenzer's feedback): let a hang start later instead
    // of only ever being live right now.
    @State private var timingMode: TimingMode = .now
    @State private var startDate: Date = Date().addingTimeInterval(30 * 60)

    // Selective visibility (This-Establishment26 / achilltrainer's
    // feedback): not every hang should go to the whole friend group.
    @State private var visibilityMode: VisibilityMode = .everyone
    @State private var selectedFriendIds: Set<String> = []

    /// The plan being edited, or nil when posting a new one.
    private let editing: Status?
    /// Real DropIn accounts to share with (from HomeViewModel).
    private let friends: [User]
    let onBroadcast: (Status) -> Void

    /// - Parameters:
    ///   - editing: pass an existing plan to edit it; leave nil to post a new one.
    ///   - onBroadcast: receives the new plan, or the edited copy (same id).
    init(editing: Status? = nil, friends: [User] = [], onBroadcast: @escaping (Status) -> Void) {
        self.editing = editing
        self.friends = friends
        self.onBroadcast = onBroadcast
        guard let plan = editing else { return }

        // Pre-fill the form with the plan's current values.
        _activityText = State(initialValue: plan.activityText)
        _selectedCategory = State(initialValue: plan.category)
        _intent = State(initialValue: plan.resolvedIntent)
        _seatLimit = State(initialValue: max(plan.seatLimit ?? 2, plan.attendees.count, 1))
        _timingMode = State(initialValue: plan.isUpcoming ? .later : .now)
        if plan.isUpcoming {
            _startDate = State(initialValue: plan.startsAt)
        }
        let minutes = Int(plan.expiresAt.timeIntervalSince(plan.startsAt) / 60)
        _expirationMinutes = State(initialValue: Double(min(max((minutes + 7) / 15 * 15, 15), 720)))
        if let visibleTo = plan.visibleToUserIds {
            _visibilityMode = State(initialValue: .selected)
            _selectedFriendIds = State(initialValue: Set(visibleTo))
        }
    }

    private var isEditing: Bool { editing != nil }

    /// Friends who already grabbed a seat keep it, so the limit can't go below them.
    private var minimumSeats: Int {
        min(max(1, editing?.attendees.count ?? 0), PlanRules.seatRange.upperBound)
    }

    /// Selected friends who still have an account. Drops ids of deleted
    /// accounts (or old sample friends) that an edited plan might still have.
    private var validSelectedIds: Set<String> {
        guard !friendOptions.isEmpty else { return selectedFriendIds }
        return selectedFriendIds.intersection(friendOptions.compactMap(\.id))
    }

    private var friendOptions: [User] {
        friends.filter { $0.id != nil && $0.id != authViewModel.currentUser?.id }
    }

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 8) {
                        Image(systemName: isEditing ? "pencil.circle.fill" : "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.dropInCoral)
                        Text(isEditing ? "Edit your plan" : "What are you up to?")
                            .font(DropInFont.heading(22))
                            .foregroundColor(.dropInIndigo)
                        Spacer()
                        DropInCloseButton { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("E.g., dinner at Chipotle, room for 2", text: $activityText, axis: .vertical)
                            .font(DropInFont.body(16))
                            .padding(16)
                            .background(Color.white.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1)
                            )

                        autofillRow
                    }

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

                    intentSection

                    timingSection

                    visibilitySection

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Expiration")
                            .font(DropInFont.bodyMedium(15))
                            .foregroundColor(.dropInIndigo)

                        Slider(value: $expirationMinutes, in: 15...720, step: 15)
                            .tint(.dropInCoral)

                        HStack {
                            Text("Lasts")
                                .foregroundColor(.dropInIndigo.opacity(0.5))
                            Spacer()
                            Text(durationLabel)
                                .font(DropInFont.bodyMedium(13))
                                .foregroundColor(.dropInIndigo)
                        }
                        .font(DropInFont.body(13))
                    }
                    .padding(18)
                    .dropInCard(cornerRadius: 18)

                    Button(isEditing ? "Save Changes" : "Broadcast Plan") {
                        broadcast()
                    }
                    .buttonStyle(DropInPrimaryButtonStyle())
                    .disabled(trimmedText.isEmpty || isAutofilling)
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 28)
            }
        }
//        .doodleAccents()
    }

    // MARK: - AI autofill

    private var trimmedText: String {
        activityText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var autofillRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                autofill()
            } label: {
                HStack(spacing: 6) {
                    if isAutofilling {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isAutofilling ? "Filling in..." : "Autofill from text")
                        .font(DropInFont.bodyMedium(13))
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Color.dropInCoral)
                .clipShape(Capsule())
                .shadow(color: Color.dropInCoral.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(trimmedText.isEmpty || isAutofilling)
            .opacity(trimmedText.isEmpty ? 0.45 : 1)

            if autofillSource == nil || trimmedText.isEmpty {
                // Explains the feature until it's been used.
                Text("Describe your plan in your own words, then tap Autofill. It picks the category, vibe, time, and seats for you.")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let autofillSource, !trimmedText.isEmpty {
                Label(
                    autofillSource == .appleIntelligence
                        ? "Filled in with Apple Intelligence. Double-check before posting."
                        : "Filled in automatically. Double-check before posting.",
                    systemImage: autofillSource == .appleIntelligence ? "apple.intelligence" : "wand.and.stars"
                )
                .font(DropInFont.body(12))
                .foregroundColor(.dropInIndigo.opacity(0.55))
            }
        }
    }

    private func autofill() {
        let text = trimmedText
        guard !text.isEmpty else { return }
        isAutofilling = true
        Task {
            let result = await PlanAssistant.draft(from: text)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                apply(result.draft)
                autofillSource = result.source
            }
            isAutofilling = false
        }
    }

    private func apply(_ draft: PlanDraft) {
        activityText = draft.activityText
        selectedCategory = draft.category
        intent = draft.intent
        if let seats = draft.seatLimit {
            seatLimit = max(seats, minimumSeats)
        }
        if draft.startsInMinutes > 0 {
            timingMode = .later
            startDate = Date().addingTimeInterval(Double(draft.startsInMinutes) * 60)
        } else {
            timingMode = .now
        }
        // Snap to the slider's 15-minute steps.
        let snapped = ((draft.durationMinutes + 7) / 15) * 15
        expirationMinutes = Double(min(max(snapped, 15), 720))
    }

    private var durationLabel: String {
        let total = Int(expirationMinutes)
        let hours = total / 60
        let minutes = total % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return hours == 1 ? "1 hour" : "\(hours) hours"
        default: return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Intent ("vibe")

    private var intentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vibe")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)

            VStack(spacing: 8) {
                ForEach(PlanIntent.allCases, id: \.self) { option in
                    intentRow(option)
                }
            }

            if intent == .capped {
                HStack(spacing: 12) {
                    Text("Open seats")
                        .font(DropInFont.bodyMedium(14))
                        .foregroundColor(.dropInIndigo)
                    Spacer()
                    Text("\(seatLimit)")
                        .font(DropInFont.heading(18))
                        .foregroundColor(.dropInIndigo)
                        .monospacedDigit()
                    Stepper("Open seats", value: $seatLimit, in: minimumSeats...PlanRules.seatRange.upperBound)
                        .labelsHidden()
                }
                .padding(.top, 4)

                if let taken = editing?.attendees.count, taken > 0 {
                    Text("\(taken) \(taken == 1 ? "friend already has a seat" : "friends already have seats"), so the limit can't go below \(taken).")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.5))
                }

                Text("Locks automatically once \(seatLimit) \(seatLimit == 1 ? "friend joins" : "friends join").")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 18)
    }

    private func intentRow(_ option: PlanIntent) -> some View {
        let isSelected = intent == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                intent = option
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .dropInIndigo)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Color.dropInIndigo : Color.white))

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(DropInFont.bodyMedium(14))
                        .foregroundColor(.dropInIndigo)
                    Text(option.subtitle)
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.55))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .dropInCoral : .dropInIndigo.opacity(0.2))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(isSelected ? 0.9 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.dropInCoral.opacity(0.6) : Color.dropInIndigo.opacity(0.06), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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

            if timingMode == .now, let editing, !editing.isUpcoming {
                Text("Already live. It keeps its original start time.")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
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
                if friendOptions.isEmpty {
                    Text("No one else has a DropIn account yet. Once friends sign up, they'll show up here.")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(friendOptions, id: \.id) { friend in
                            friendChip(friend)
                        }
                    }
                    .padding(.top, 4)
                }

                if validSelectedIds.isEmpty && !friendOptions.isEmpty {
                    Text("Pick at least one friend, or this hang won't be visible to anyone.")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInCoral)
                }
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 18)
    }

    private func friendChip(_ friend: User) -> some View {
        let friendId = friend.id ?? ""
        let isSelected = selectedFriendIds.contains(friendId)
        let name = friend.name
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
                AvatarView(name: name, imageName: friend.avatarUrl, size: 22)
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
        let visibility: [String]? = visibilityMode == .selected ? Array(validSelectedIds) : nil

        let starts: Date
        switch timingMode {
        case .later:
            starts = max(startDate, Date())
        case .now:
            // An already-live plan keeps its start; everything else starts now.
            if let editing, !editing.isUpcoming {
                starts = editing.startsAt
            } else {
                starts = Date()
            }
        }
        // Never save a plan that has already ended.
        let expires = max(starts.addingTimeInterval(expirationMinutes * 60), Date().addingTimeInterval(15 * 60))

        if var updated = editing {
            // Keeps id, attendees, pause state, and who posted it.
            updated.activityText = trimmedText
            updated.category = selectedCategory
            updated.startsAt = starts
            updated.expiresAt = expires
            updated.visibleToUserIds = visibility
            updated.intent = intent
            updated.seatLimit = intent == .capped ? max(seatLimit, minimumSeats) : nil
            onBroadcast(updated)
            dismiss()
            return
        }

        let newStatus = Status(
            userId: authViewModel.currentUser?.id ?? "me",
            username: authViewModel.currentUser?.name ?? "You",
            activityText: trimmedText,
            category: selectedCategory,
            createdAt: Date(),
            startsAt: starts,
            expiresAt: expires,
            attendees: [],
            avatarImageName: authViewModel.currentUser?.avatarUrl,
            visibleToUserIds: visibility,
            intent: intent,
            seatLimit: intent == .capped ? seatLimit : nil
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
