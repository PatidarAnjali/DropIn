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

    /// Every account's profile (name + avatar), keyed by uid. Kept live,
    /// so if someone changes their avatar it updates everywhere right away.
    var usersById: [String: User] = [:]

    /// Set when an RSVP fails (e.g. the last seat was just taken).
    /// HomeFeedView shows it as an alert.
    var rsvpMessage: String?

    // Not shown on screen, so there's no need for SwiftUI to track these.
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var usersListener: ListenerRegistration?
    @ObservationIgnored private var friendshipsListener: ListenerRegistration?
    @ObservationIgnored private var nudgesToMeListener: ListenerRegistration?
    @ObservationIgnored private var nudgesFromMeListener: ListenerRegistration?
    @ObservationIgnored private var blocksByMeListener: ListenerRegistration?
    @ObservationIgnored private var blocksOfMeListener: ListenerRegistration?
    @ObservationIgnored private var socialUserId: String?

    // MARK: Friends & nudges state

    /// Every friendship document you're part of (requests and friends).
    var friendships: [Friendship] = []
    /// Nudges friends sent you.
    var nudgesToMe: [Nudge] = []
    /// Nudges you sent.
    var nudgesFromMe: [Nudge] = []
    /// Blocks you made.
    var blocksByMe: [Block] = []
    /// Blocks other people made against you.
    var blocksOfMe: [Block] = []

    init() {
        startListening()
        startListeningToUsers()
    }

    // `isolated` runs cleanup on the main actor, the same place the
    // listeners live, so they can be read here safely.
    isolated deinit {
        listener?.remove()
        usersListener?.remove()
        friendshipsListener?.remove()
        nudgesToMeListener?.remove()
        nudgesFromMeListener?.remove()
        blocksByMeListener?.remove()
        blocksOfMeListener?.remove()
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

    /// Keeps every account from the Firestore `users` collection in sync.
    /// Powers attendee names/avatars and the "Choose friends" picker.
    /// Accounts deleted in Firebase disappear here right away.
    ///
    /// Until there's a real friends system, "friends" means everyone with
    /// a DropIn account. That's fine for a small group, but once there
    /// are friend requests this should only load your friends.
    func startListeningToUsers() {
        usersListener = FirestoreService.shared.db.collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { print("Users listener error: \(error)") }
                    return
                }
                var byId: [String: User] = [:]
                for document in documents {
                    if let user = try? document.data(as: User.self) {
                        byId[document.documentID] = user
                    }
                }
                Task { @MainActor in
                    self?.usersById = byId
                }
            }
    }

    /// Your friends, A to Z. Used by the "Choose friends" picker and nudges.
    func friendOptions(excluding userId: String?) -> [User] {
        guard let userId else { return [] }
        return friendIds(of: userId)
            .compactMap { usersById[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Every non-expired hang `viewerId` is allowed to see at all —
    /// i.e. not paused by someone else, and either public or the
    /// viewer is one of the invited friends (or it's their own hang).
    private func visibleStatuses(for viewerId: String) -> [Status] {
        let friends = friendIds(of: viewerId)
        let hidden = hiddenUserIds(for: viewerId)
        return statuses
            .filter { !hidden.contains($0.userId) }
            .filter { !$0.isExpired }
            .filter { $0.userId == viewerId || friends.contains($0.userId) }
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

    /// Called when a friend taps the RSVP button (join or leave).
    ///
    /// Uses a Firestore transaction: it reads the newest copy of the plan
    /// from the server, checks the rules (not your own plan, not expired,
    /// seats left), and saves, all as one step. If two friends tap the
    /// last seat at the same moment, Firestore retries one of them with
    /// the updated attendee list, so that person gets "Plan's full"
    /// instead of both getting in.
    func toggleAttendance(for status: Status, currentUserId: String) {
        guard let id = status.id else { return }

        // Quick local check so obvious cases don't hit the network.
        if case .failure(let reason) = status.toggledAttendees(for: currentUserId) {
            if reason != .ownPlan { rsvpMessage = reason.message }
            return
        }

        let db = FirestoreService.shared.db
        let ref = db.collection("statuses").document(id)
        let block = RSVPTransaction.block(for: ref, userId: currentUserId)

        Task {
            do {
                _ = try await db.runTransaction(block)
            } catch {
                let nsError = error as NSError
                rsvpMessage = nsError.domain == PlanRules.errorDomain
                    ? nsError.localizedDescription
                    : "Couldn't update your RSVP. Check your connection and try again."
            }
        }
    }

    // MARK: - Friends

    /// Starts the listeners that depend on who's signed in. Safe to call
    /// again; it only restarts if the user changed.
    func startSocialListeners(for userId: String) {
        guard !userId.isEmpty, userId != socialUserId else { return }
        socialUserId = userId
        friendshipsListener?.remove()
        nudgesToMeListener?.remove()
        nudgesFromMeListener?.remove()
        blocksByMeListener?.remove()
        blocksOfMeListener?.remove()
        let db = FirestoreService.shared.db

        blocksByMeListener = db.collection("blocks")
            .whereField("blockerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { print("Blocks listener error: \(error)") }
                let parsed = snapshot?.documents.compactMap { try? $0.data(as: Block.self) } ?? []
                Task { @MainActor in self?.blocksByMe = parsed }
            }

        blocksOfMeListener = db.collection("blocks")
            .whereField("blockedId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { print("Blocks listener error: \(error)") }
                let parsed = snapshot?.documents.compactMap { try? $0.data(as: Block.self) } ?? []
                Task { @MainActor in self?.blocksOfMe = parsed }
            }

        friendshipsListener = db.collection("friendships")
            .whereField("userIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { print("Friendships listener error: \(error)") }
                let parsed = snapshot?.documents.compactMap { try? $0.data(as: Friendship.self) } ?? []
                Task { @MainActor in self?.friendships = parsed }
            }

        nudgesToMeListener = db.collection("nudges")
            .whereField("toUserIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { print("Nudges listener error: \(error)") }
                let parsed = snapshot?.documents.compactMap { try? $0.data(as: Nudge.self) } ?? []
                Task { @MainActor in self?.nudgesToMe = parsed }
            }

        nudgesFromMeListener = db.collection("nudges")
            .whereField("fromUserId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { print("Nudges listener error: \(error)") }
                let parsed = snapshot?.documents.compactMap { try? $0.data(as: Nudge.self) } ?? []
                Task { @MainActor in self?.nudgesFromMe = parsed }
            }
    }

    func friendIds(of userId: String) -> Set<String> {
        FriendshipRules.friendIds(of: userId, in: friendships).subtracting(hiddenUserIds(for: userId))
    }

    func incomingRequests(for userId: String) -> [Friendship] {
        let hidden = hiddenUserIds(for: userId)
        return FriendshipRules.incomingRequests(for: userId, in: friendships)
            .filter { !hidden.contains($0.otherUserId(than: userId) ?? "") }
    }

    func outgoingRequests(from userId: String) -> [Friendship] {
        let hidden = hiddenUserIds(for: userId)
        return FriendshipRules.outgoingRequests(from: userId, in: friendships)
            .filter { !hidden.contains($0.otherUserId(than: userId) ?? "") }
    }

    enum AddFriendError: Error {
        case invalidCode, notFound, yourself, alreadyFriends, alreadyRequested, youBlocked, network

        var message: String {
            switch self {
            case .invalidCode: "Friend codes are 6 letters and numbers, like K7Q-2MX."
            case .notFound: "No one has that code. Double-check it with your friend."
            case .yourself: "That's your own code!"
            case .alreadyFriends: "You're already friends."
            case .alreadyRequested: "You already sent them a request."
            case .youBlocked: "You blocked this person. Unblock them on the Friends screen first."
            case .network: "Couldn't send the request. Check your connection and try again."
            }
        }
    }

    enum AddFriendResult {
        case requestSent(name: String)
        /// They had already asked you, so this made you friends.
        case becameFriends(name: String)
    }

    /// Sends a friend request to whoever owns `code`.
    func addFriend(code rawCode: String, me: String) async -> Result<AddFriendResult, AddFriendError> {
        guard let code = FriendCode.normalize(rawCode) else { return .failure(.invalidCode) }
        let db = FirestoreService.shared.db

        let found: User
        let theirId: String
        do {
            let snapshot = try await db.collection("users")
                .whereField("friendCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            guard let document = snapshot.documents.first,
                  let user = try? document.data(as: User.self) else {
                return .failure(.notFound)
            }
            found = user
            theirId = document.documentID
        } catch {
            return .failure(.network)
        }

        if SafetyRules.didBlock(me, theirId, in: blocksByMe) {
            return .failure(.youBlocked)
        }
        // Don't reveal that someone blocked you; it just looks like no match.
        if SafetyRules.isBlocked(by: theirId, me: me, in: blocksOfMe) {
            return .failure(.notFound)
        }

        switch FriendshipRules.relation(between: me, and: theirId, in: friendships) {
        case _ where theirId == me:
            return .failure(.yourself)
        case .friends:
            return .failure(.alreadyFriends)
        case .requestSent:
            return .failure(.alreadyRequested)
        case .requestReceived:
            if let request = friendships.first(where: { Set($0.userIds) == [me, theirId] }) {
                acceptFriendRequest(request)
            }
            return .success(.becameFriends(name: found.name))
        case .none:
            let friendship = Friendship(
                userIds: [me, theirId].sorted(),
                requesterId: me,
                state: .pending
            )
            do {
                let data = try Firestore.Encoder().encode(friendship)
                try await db.collection("friendships")
                    .document(FriendshipRules.documentId(me, theirId))
                    .setData(data)
                return .success(.requestSent(name: found.name))
            } catch {
                return .failure(.network)
            }
        }
    }

    func acceptFriendRequest(_ friendship: Friendship) {
        guard let id = friendship.id else { return }
        FirestoreService.shared.db.collection("friendships").document(id)
            .updateData(["state": FriendshipState.accepted.rawValue])
    }

    /// Declining a request, cancelling one you sent, and unfriending all
    /// remove the friendship document.
    func removeFriendship(_ friendship: Friendship) {
        guard let id = friendship.id else { return }
        FirestoreService.shared.db.collection("friendships").document(id).delete()
    }

    func friendship(between me: String, and other: String) -> Friendship? {
        friendships.first { Set($0.userIds) == [me, other] }
    }

    // MARK: - Blocking & reporting

    /// People you blocked plus people who blocked you.
    func hiddenUserIds(for userId: String) -> Set<String> {
        SafetyRules.hiddenUserIds(for: userId, in: blocksByMe + blocksOfMe)
    }

    /// Ids of people you blocked.
    func blockedByMeIds() -> Set<String> {
        Set(blocksByMe.map(\.blockedId))
    }

    /// Ids of people who blocked you.
    func blockedMeIds() -> Set<String> {
        Set(blocksOfMe.map(\.blockerId))
    }

    /// People you blocked, for the "Blocked" list on the Friends screen.
    func blockedUsers() -> [(block: Block, user: User?)] {
        blocksByMe
            .sorted { $0.createdAt > $1.createdAt }
            .map { ($0, usersById[$0.blockedId]) }
    }

    /// Blocks someone: saves the block and ends any friendship or request.
    func block(userId other: String, me: String) {
        guard other != me else { return }
        let db = FirestoreService.shared.db
        let block = Block(blockerId: me, blockedId: other)
        let batch = db.batch()
        do {
            let data = try Firestore.Encoder().encode(block)
            batch.setData(data, forDocument: db.collection("blocks")
                .document(SafetyRules.blockDocumentId(blocker: me, blocked: other)))
        } catch {
            print("Failed to encode block: \(error)")
            return
        }
        if friendship(between: me, and: other) != nil {
            batch.deleteDocument(db.collection("friendships").document(FriendshipRules.documentId(me, other)))
        }
        batch.commit { error in
            if let error { print("Failed to block: \(error)") }
        }
    }

    func unblock(_ block: Block) {
        guard let id = block.id else { return }
        FirestoreService.shared.db.collection("blocks").document(id).delete()
    }

    /// Saves a report for review. Returns false if it couldn't be sent.
    func submitReport(
        _ target: ReportTarget,
        reason: Report.Reason,
        details: String,
        alsoBlock: Bool,
        me: String
    ) async -> Bool {
        let report = Report(
            reporterId: me,
            reportedUserId: target.userId,
            kind: target.kind,
            contentId: target.contentId,
            contentText: target.contentText,
            reason: reason,
            details: SafetyRules.cleanDetails(details)
        )
        do {
            let data = try Firestore.Encoder().encode(report)
            _ = try await FirestoreService.shared.db.collection("reports").addDocument(data: data)
            if alsoBlock {
                block(userId: target.userId, me: me)
            }
            return true
        } catch {
            print("Failed to send report: \(error)")
            return false
        }
    }

    // MARK: - Who's Down? nudges

    /// Nudges to you that are still going, newest first.
    func activeNudgesToMe() -> [Nudge] {
        let hidden = socialUserId.map { hiddenUserIds(for: $0) } ?? []
        return nudgesToMe
            .filter { $0.isActive() && !hidden.contains($0.fromUserId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Your nudges that are still going, newest first.
    func activeNudgesFromMe() -> [Nudge] {
        nudgesFromMe.filter { $0.isActive() }.sorted { $0.createdAt > $1.createdAt }
    }

    func sendNudge(message: String, to recipients: [String], me: User) -> NudgeRules.ValidationError? {
        guard let myId = me.id else { return .noRecipients }
        let result = NudgeRules.makeNudge(
            from: myId,
            name: me.name,
            message: message,
            to: recipients,
            friendIds: friendIds(of: myId)
        )
        switch result {
        case .failure(let error):
            return error
        case .success(let nudge):
            do {
                try FirestoreService.shared.db.collection("nudges").addDocument(from: nudge)
            } catch {
                print("Failed to send nudge: \(error)")
            }
            return nil
        }
    }

    func respond(to nudge: Nudge, with response: NudgeResponse, me: String) {
        guard let id = nudge.id else { return }
        // Only touches your own reply, so friends answering at the same
        // time never overwrite each other.
        FirestoreService.shared.db.collection("nudges").document(id)
            .updateData(["responses.\(me)": response.rawValue])
    }

    func deleteNudge(_ nudge: Nudge) {
        guard let id = nudge.id else { return }
        FirestoreService.shared.db.collection("nudges").document(id).delete()
    }

    // MARK: - Your plans (Profile)

    /// Your plans that haven't ended yet, soonest first.
    func activePlans(postedBy userId: String) -> [Status] {
        statuses
            .filter { $0.userId == userId && !$0.isExpired }
            .sorted { $0.startsAt < $1.startsAt }
    }

    /// Your plans that have ended, most recent first.
    func pastPlans(postedBy userId: String) -> [Status] {
        statuses
            .filter { $0.userId == userId && $0.isExpired }
            .sorted { $0.expiresAt > $1.expiresAt }
    }

    struct ProfileStats {
        var plansPosted = 0
        var friendsDroppedIn = 0
        var plansJoined = 0
    }

    /// All-time numbers for the Profile page.
    func stats(for userId: String) -> ProfileStats {
        var stats = ProfileStats()
        for status in statuses {
            if status.userId == userId {
                stats.plansPosted += 1
                stats.friendsDroppedIn += status.attendees.count
            } else if status.attendees.contains(userId) {
                stats.plansJoined += 1
            }
        }
        return stats
    }

    /// Saves edits to one of your plans. Only the fields the poster can
    /// change are written, so friends joining at the same moment (the
    /// attendee list) are never overwritten.
    func updateStatus(_ updated: Status, original: Status) {
        guard let id = updated.id else { return }

        let fields: [String: Any] = [
            "activityText": updated.activityText,
            "category": updated.category.rawValue,
            "startsAt": Timestamp(date: updated.startsAt),
            "expiresAt": Timestamp(date: updated.expiresAt),
            "intent": updated.resolvedIntent.rawValue,
            // nil means "remove this field" in Firestore.
            "seatLimit": updated.seatLimit.map { $0 as Any } ?? FieldValue.delete(),
            "visibleToUserIds": updated.visibleToUserIds.map { $0 as Any } ?? FieldValue.delete(),
        ]
        FirestoreService.shared.db.collection("statuses").document(id).updateData(fields) { error in
            if let error { print("Failed to save plan edits: \(error)") }
        }

        // Move the "starting now" nudge if a planned hang's time or text changed.
        if original.isUpcoming,
           original.startsAt != updated.startsAt || original.activityText != updated.activityText {
            NotificationService.shared.cancelNotification(for: original)
            if updated.isUpcoming {
                NotificationService.shared.notifyFriends(about: updated)
            }
        }
    }

    /// Permanently removes one of your plans for everyone.
    func deleteStatus(_ status: Status) {
        guard let id = status.id else { return }
        NotificationService.shared.cancelNotification(for: status)
        FirestoreService.shared.db.collection("statuses").document(id).delete { error in
            if let error { print("Failed to delete plan: \(error)") }
        }
    }

    /// Removes all of your ended plans in one go.
    func deletePastPlans(postedBy userId: String) {
        let ids = pastPlans(postedBy: userId).compactMap(\.id)
        guard !ids.isEmpty else { return }
        let db = FirestoreService.shared.db
        // A batch allows up to 500 writes, so split big histories up.
        for chunk in stride(from: 0, to: ids.count, by: 450).map({ Array(ids[$0..<min($0 + 450, ids.count)]) }) {
            let batch = db.batch()
            for id in chunk {
                batch.deleteDocument(db.collection("statuses").document(id))
            }
            batch.commit { error in
                if let error { print("Failed to clear past plans: \(error)") }
            }
        }
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

// MARK: - RSVP transaction

/// Kept outside the @MainActor view model on purpose: Firestore runs the
/// transaction block on a background thread (and may run it more than
/// once if the plan changed), so it must not be tied to the main actor.
nonisolated enum RSVPTransaction {
    static func block(for ref: DocumentReference, userId: String) -> (Transaction, NSErrorPointer) -> sending Any? {
        return { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let data = snapshot.data() ?? [:]
            let result = PlanRules.toggledAttendees(
                current: data["attendees"] as? [String] ?? [],
                userId: userId,
                ownerId: data["userId"] as? String ?? "",
                intent: PlanIntent(rawValue: data["intent"] as? String ?? "") ?? .openDoor,
                seatLimit: data["seatLimit"] as? Int,
                expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue() ?? .distantFuture
            )

            switch result {
            case .success(let attendees):
                transaction.updateData(["attendees": attendees], forDocument: ref)
            case .failure(let reason):
                errorPointer?.pointee = NSError(
                    domain: PlanRules.errorDomain,
                    code: reason.code,
                    userInfo: [NSLocalizedDescriptionKey: reason.message]
                )
            }
            return nil
        }
    }
}
