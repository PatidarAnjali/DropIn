//
//  HomeViewModel.swift
//  DropIn
//
//  Milestone 1: reads from MockData and filters locally.
//  Milestone 3: swap `loadMockStatuses()` for a Firestore snapshot
//  listener — HomeFeedView won't need to change at all.
//

import Foundation
import Observation

@Observable
final class HomeViewModel {
    var statuses: [Status] = []
    var searchText: String = ""

    init() {
        loadMockStatuses()
    }

    func loadMockStatuses() {
        statuses = MockData.statuses.filter { !$0.isExpired }
    }

    /// Every non-expired hang `viewerId` is allowed to see at all —
    /// i.e. not paused by someone else, and either public or the
    /// viewer is one of the invited friends (or it's their own hang).
    private func visibleStatuses(for viewerId: String) -> [Status] {
        statuses
            .filter { !$0.isExpired }
            .filter { $0.isVisible(to: viewerId) }
    }

    /// Hangs that have already started — the main "Live Now" list.
    func liveStatuses(for viewerId: String) -> [Status] {
        applySearch(to: visibleStatuses(for: viewerId).filter { $0.isLive })
    }

    /// "Plan ahead" hangs that haven't started yet — shown separately
    /// so a friend planning to swing by in 30 minutes doesn't get
    /// buried under (or mistaken for) something happening right now.
    /// Also what keeps the feed from ever feeling totally dead —
    /// rjyo's "empty room problem": even with nothing live, seeing
    /// "Jordan's got dinner starting in 40m" gives someone a reason to
    /// keep the app around instead of forgetting about it.
    func upcomingStatuses(for viewerId: String) -> [Status] {
        applySearch(to: visibleStatuses(for: viewerId).filter { $0.isUpcoming })
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func applySearch(to source: [Status]) -> [Status] {
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.activityText.localizedCaseInsensitiveContains(searchText)
        }
    }

    func addStatus(_ status: Status) {
        statuses.insert(status, at: 0)
        NotificationService.shared.notifyFriends(about: status)
    }

    /// Called when a friend taps "I'm Coming" / "Drop In"
    func toggleAttendance(for status: Status, currentUserId: String) {
        guard let index = statuses.firstIndex(where: { $0.id == status.id }) else { return }
        if statuses[index].attendees.contains(currentUserId) {
            statuses[index].attendees.removeAll { $0 == currentUserId }
        } else {
            statuses[index].attendees.append(currentUserId)
        }
    }

    /// The poster quietly goes invisible (or comes back). Nothing is
    /// sent to friends either way — no "so-and-so paused their hang"
    /// notice — so there's never an awkward "why'd you turn that off"
    /// conversation to have (rjyo's feedback).
    func togglePause(for status: Status) {
        guard let index = statuses.firstIndex(where: { $0.id == status.id }) else { return }
        statuses[index].isPaused.toggle()
        if statuses[index].isPaused {
            NotificationService.shared.cancelNotification(for: statuses[index])
        }
    }

    /// Milestone 4: call this periodically (e.g. via a Timer) to drop
    /// expired statuses from the feed without a full reload.
    func removeExpiredStatuses() {
        statuses.removeAll { $0.isExpired }
    }
}
