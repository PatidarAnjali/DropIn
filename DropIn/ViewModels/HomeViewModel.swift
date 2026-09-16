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

    var filteredStatuses: [Status] {
        guard !searchText.isEmpty else { return statuses }
        return statuses.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.activityText.localizedCaseInsensitiveContains(searchText)
        }
    }

    func addStatus(_ status: Status) {
        statuses.insert(status, at: 0)
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

    /// Milestone 4: call this periodically (e.g. via a Timer) to drop
    /// expired statuses from the feed without a full reload.
    func removeExpiredStatuses() {
        statuses.removeAll { $0.isExpired }
    }
}
