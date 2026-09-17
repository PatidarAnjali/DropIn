//
//  NotificationService.swift
//  DropIn
//
//  Addresses rjyo's "empty room problem" feedback from the Reddit
//  thread: friends need to be nudged the moment a hang goes live, or
//  they open the app once, see nothing, and forget about it.
//
//  Milestone 1: uses local `UNUserNotificationCenter` notifications so
//  the flow is demoable on-device without a backend. A single device
//  obviously can't notify *other* people's phones; in Milestone 3 this
//  gets replaced by a server function that fans a push out to a
//  friend's actual devices when a Firestore status doc is created, but
//  the call sites in the view models won't need to change.
//
//  Frequency guardrail (also from rjyo's feedback; "you'd need to nail
//  the frequency so it doesn't get annoying"): we only ever send one
//  notification per hang (its start), never repeated pings, and we
//  never notify for a hang the viewer can't even see (paused / private
//  hangs the friend isn't invited to).
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// Called right after a hang is broadcast. If it's live immediately,
    /// this fires "now" (simulating the push a friend would get). If
    /// it's a planned hang, this schedules the nudge for `startsAt`
    /// instead of firing right away; so friends aren't pinged for
    /// something that hasn't started yet.
    func notifyFriends(about status: Status) {
        guard !status.isPaused else { return }

        let content = UNMutableNotificationContent()
        content.title = status.isPrivate ? "\(status.username) invited you to hang" : "\(status.username) is free to hang"
        content.body = status.activityText
        content.sound = .default

        let secondsUntilStart = max(status.startsAt.timeIntervalSinceNow, 0)
        // A tiny minimum delay so an "immediate" hang still fires as a
        // real system notification instead of being swallowed by iOS
        // for firing at effectively t=0.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(secondsUntilStart, 1), repeats: false)

        let request = UNNotificationRequest(identifier: notificationId(for: status), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels a still-pending "hang is starting" nudge; e.g. call this
    /// if a poster deletes or pauses a planned hang before it starts.
    /// Clears every scheduled DropIn notification (used when deleting an account).
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelNotification(for status: Status) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId(for: status)])
    }

    /// A brand-new plan doesn't have a Firestore id yet when its
    /// notification is scheduled, so the id is built from who posted it
    /// and when (to the millisecond), which is the same before and after
    /// saving.
    private func notificationId(for status: Status) -> String {
        "hang-\(status.userId)-\(Int(status.createdAt.timeIntervalSince1970 * 1000))"
    }
}
