//
//  HomeViewModel.swift
//  DropIn
//
//  Live Firestore version — HomeFeedView didn't need to change at all
//  to make this swap, which was the whole point of keeping Milestone 1
//  behind this view model instead of in the view.
//

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class HomeViewModel {
    var statuses: [Status] = []
    var searchText: String = ""

    // `deinit` is nonisolated, so the registration must be readable from there.
    nonisolated(unsafe) private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    /// Real-time listener — any hang anyone broadcasts, pauses, or gets
    /// an attendee added to shows up here immediately without a manual
    /// refresh, on every device signed into the same Firebase project.
    func startListening() {
        listener = FirestoreService.shared.db.collection("statuses")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { print("Statuses listener error: \(error)") }
                    return
                }
                let parsed = documents.compactMap { try? $0.data(as: Status.self) }
                Task { @MainActor in
                    self?.statuses = parsed
                }
            }
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

    /// "Plan ahead" hangs that haven't started yet.
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

    /// Writes a new hang to Firestore. We don't insert it into
    /// `statuses` locally — the snapshot listener above will pick it up
    /// (with its real, server-assigned id) a moment later.
    func addStatus(_ status: Status) {
        do {
            try FirestoreService.shared.db.collection("statuses").addDocument(from: status)
            NotificationService.shared.notifyFriends(about: status)
        } catch {
            print("Failed to broadcast hang: \(error)")
        }
    }

    /// Called when a friend taps "I'm Coming" / "Can't Make It".
    func toggleAttendance(for status: Status, currentUserId: String) {
        guard let id = status.id else { return }
        var attendees = status.attendees
        if attendees.contains(currentUserId) {
            attendees.removeAll { $0 == currentUserId }
        } else {
            attendees.append(currentUserId)
        }
        FirestoreService.shared.db.collection("statuses").document(id)
            .updateData(["attendees": attendees])
    }

    /// The poster quietly goes invisible (or comes back) — no notice
    /// goes to friends either way.
    func togglePause(for status: Status) {
        guard let id = status.id else { return }
        let newValue = !status.isPaused
        FirestoreService.shared.db.collection("statuses").document(id)
            .updateData(["isPaused": newValue])
        if newValue {
            NotificationService.shared.cancelNotification(for: status)
        }
    }
}
