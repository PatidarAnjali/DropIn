//
//  FriendsView.swift
//  DropIn
//
//  Your friend code (with a QR code to scan in person), adding friends,
//  friend requests, and your friends list.
//

import SwiftUI
import PhotosUI
import Photos
import CoreImage.CIFilterBuiltins

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    let homeViewModel: HomeViewModel

    @State private var codeInput = ""
    @State private var isAdding = false
    @State private var resultMessage: (text: String, isError: Bool)?
    @State private var showScanner = false
    @State private var copied = false
    @State private var friendToRemove: User?
    @State private var reportTarget: ReportTarget?
    @State private var blockTarget: (id: String, name: String)?
    @State private var addMethod: AddMethod = .code
    @State private var photoItem: PhotosPickerItem?
    @State private var saveMessage: (text: String, isError: Bool)?

    private enum AddMethod: String, CaseIterable {
        case code = "Enter Code"
        case qr = "Scan QR"

        var icon: String {
            switch self {
            case .code: "keyboard"
            case .qr: "qrcode.viewfinder"
            }
        }
    }
    @FocusState private var codeFieldFocused: Bool

    private var me: String { authViewModel.currentUser?.id ?? "" }
    private var myCode: String? { authViewModel.currentUser?.friendCode }

    private var friends: [User] { homeViewModel.friendOptions(excluding: me) }
    private var incoming: [Friendship] { homeViewModel.incomingRequests(for: me) }
    private var outgoing: [Friendship] { homeViewModel.outgoingRequests(from: me) }

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Friends")
                            .font(DropInFont.heading(24))
                            .foregroundColor(.dropInIndigo)
                        Spacer()
                        DropInCloseButton { dismiss() }
                    }

                    myCodeCard
                    addFriendCard

                    if !incoming.isEmpty {
                        section("Friend Requests", count: incoming.count) {
                            ForEach(incoming) { request in
                                incomingRow(request)
                            }
                        }
                    }

                    if !outgoing.isEmpty {
                        section("Sent", count: outgoing.count) {
                            ForEach(outgoing) { request in
                                outgoingRow(request)
                            }
                        }
                    }

                    let blocked = homeViewModel.blockedUsers()

                    section("Your Friends", count: friends.count) {
                        if friends.isEmpty {
                            Text("No friends yet. Share your code or scan a friend's to get started.")
                                .font(DropInFont.body(13))
                                .foregroundColor(.dropInIndigo.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .dropInCard(cornerRadius: 18)
                        } else {
                            ForEach(friends, id: \.id) { friend in
                                friendRow(friend)
                            }
                        }
                    }

                    if !blocked.isEmpty {
                        section("Blocked", count: blocked.count) {
                            ForEach(blocked.indices, id: \.self) { index in
                                let entry = blocked[index]
                                personRow(userId: entry.block.blockedId, subtitle: "They can't see you or add you") {
                                    Button("Unblock") {
                                        homeViewModel.unblock(entry.block)
                                    }
                                    .buttonStyle(SmallCapsuleButtonStyle(filled: false))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { reason, details, alsoBlock in
                await homeViewModel.submitReport(target, reason: reason, details: details, alsoBlock: alsoBlock, me: me)
            }
        }
        .confirmationDialog(
            "Block \(blockTarget?.name ?? "this person")?",
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let blockTarget {
                    homeViewModel.block(userId: blockTarget.id, me: me)
                }
            }
        } message: {
            Text("You'll unfriend each other and they won't be able to add you. They won't be told.")
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
        .confirmationDialog(
            "Remove friend?",
            isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
            titleVisibility: .visible,
            presenting: friendToRemove
        ) { friend in
            Button("Remove \(friend.name)", role: .destructive) {
                if let id = friend.id, let friendship = homeViewModel.friendship(between: me, and: id) {
                    homeViewModel.removeFriendship(friendship)
                }
            }
        } message: { friend in
            Text("You'll stop seeing each other's plans. You can add \(friend.name) again later.")
        }
    }

    // MARK: - Your code

    private var myCodeCard: some View {
        VStack(spacing: 14) {
            Text("Your friend code")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)

            if let myCode {
                if let qr = Self.qrImage(for: FriendCode.qrPayload(for: myCode)) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                        .accessibilityLabel("QR code for your friend code")
                }

                Text(FriendCode.formatted(myCode))
                    .font(DropInFont.heading(28))
                    .foregroundColor(.dropInIndigo)
                    .monospaced()
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = myCode
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SmallCapsuleButtonStyle(filled: false))

                    ShareLink(item: "Add me on DropIn! My friend code is \(FriendCode.formatted(myCode))") {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SmallCapsuleButtonStyle(filled: true))
                }

                // Save or send the QR itself, not just the code text.
                if let qr = Self.qrImage(for: FriendCode.qrPayload(for: myCode)) {
                    let padded = Self.paddedForSharing(qr)
                    let image = Image(uiImage: padded)
                    HStack(spacing: 18) {
                        Button {
                            saveToPhotos(padded)
                        } label: {
                            Label("Save QR to Photos", systemImage: "square.and.arrow.down")
                        }
                        ShareLink(item: image, preview: SharePreview("My DropIn QR code", image: image)) {
                            Label("Send QR", systemImage: "qrcode")
                        }
                    }
                    .font(DropInFont.bodyMedium(13))
                    .foregroundColor(.dropInCoral)
                    .buttonStyle(.plain)

                    if let saveMessage {
                        Label(saveMessage.text, systemImage: saveMessage.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(DropInFont.body(12))
                            .foregroundColor(saveMessage.isError ? .dropInCoral : .dropInIndigo.opacity(0.7))
                    }
                }

                Text("Friends can scan this or type your code to add you.")
                    .font(DropInFont.body(12))
                    .foregroundColor(.dropInIndigo.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .padding()
                Text("Setting up your code...")
                    .font(DropInFont.body(13))
                    .foregroundColor(.dropInIndigo.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .dropInCard(cornerRadius: 22)
    }

    // MARK: - Add a friend

    private var addFriendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a friend")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)

            methodPicker

            switch addMethod {
            case .code:
                codeEntry
            case .qr:
                qrOptions
            }

            if let resultMessage {
                Label(resultMessage.text, systemImage: resultMessage.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(DropInFont.body(13))
                    .foregroundColor(resultMessage.isError ? .dropInCoral : .dropInIndigo.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .dropInCard(cornerRadius: 20)
        .onChange(of: photoItem) {
            guard let photoItem else { return }
            readQR(from: photoItem)
        }
    }

    /// Enter Code | Scan QR
    private var methodPicker: some View {
        HStack(spacing: 4) {
            ForEach(AddMethod.allCases, id: \.self) { method in
                let isSelected = addMethod == method
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        addMethod = method
                        resultMessage = nil
                    }
                    codeFieldFocused = false
                } label: {
                    Label(method.rawValue, systemImage: method.icon)
                        .font(DropInFont.bodyMedium(14))
                        .foregroundColor(isSelected ? .white : .dropInIndigo.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(isSelected ? Color.dropInIndigo : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.dropInCream))
        .overlay(Capsule().stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1))
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("K7Q-2MX", text: $codeInput)
                    .font(DropInFont.body(17))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($codeFieldFocused)
                    .submitLabel(.send)
                    .onSubmit { add(code: codeInput) }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.dropInCream)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1)
                    )

                Button {
                    add(code: codeInput)
                } label: {
                    Group {
                        if isAdding {
                            ProgressView().tint(.white)
                        } else {
                            Text("Add")
                        }
                    }
                    .frame(width: 56)
                }
                .buttonStyle(SmallCapsuleButtonStyle(filled: true))
                .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }

            Text("Ask your friend for the code on their Friends screen.")
                .font(DropInFont.body(12))
                .foregroundColor(.dropInIndigo.opacity(0.5))
        }
    }

    private var qrOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openScanner()
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SmallCapsuleButtonStyle(filled: true))

            // Works on the simulator too: read a QR code from a screenshot.
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose QR from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SmallCapsuleButtonStyle(filled: false))

            Text("Point the camera at a friend's QR code, or pick a screenshot of it.")
                .font(DropInFont.body(12))
                .foregroundColor(.dropInIndigo.opacity(0.5))
        }
    }

    /// Finds a QR code in a photo (e.g. a screenshot of a friend's code).
    private func readQR(from item: PhotosPickerItem) {
        resultMessage = nil
        Task {
            defer { photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let text = Self.qrText(in: data) else {
                resultMessage = ("Couldn't find a QR code in that photo. Try a clearer screenshot.", true)
                return
            }
            guard FriendCode.normalize(text) != nil else {
                resultMessage = ("That QR code isn't a DropIn friend code.", true)
                return
            }
            add(code: text)
        }
    }

    static func qrText(in imageData: Data) -> String? {
        guard let image = CIImage(data: imageData),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            return nil
        }
        let features = detector.features(in: image).compactMap { $0 as? CIQRCodeFeature }
        return features.first?.messageString
    }

    private func add(code: String) {
        codeFieldFocused = false
        isAdding = true
        resultMessage = nil
        Task {
            let result = await homeViewModel.addFriend(code: code, me: me)
            isAdding = false
            switch result {
            case .success(.requestSent(let name)):
                resultMessage = ("Request sent to \(name)! You'll be friends once they accept.", false)
                codeInput = ""
            case .success(.becameFriends(let name)):
                resultMessage = ("\(name) had already asked, so you're now friends!", false)
                codeInput = ""
            case .failure(let error):
                resultMessage = (error.message, true)
            }
        }
    }

    // MARK: - Scanner

    private func openScanner() {
        switch QRScanner.availability {
        case .ready:
            showScanner = true
        case .needsPermission:
            Task {
                if await QRScanner.requestPermission() {
                    showScanner = true
                } else {
                    resultMessage = ("DropIn needs camera access to scan. You can turn it on in Settings.", true)
                }
            }
        case .denied:
            resultMessage = ("Camera access is off. Turn it on in Settings → DropIn, or type the code instead.", true)
        case .unsupported:
            resultMessage = ("Scanning needs a real iPhone camera. Type the code instead.", true)
        }
    }

    private var scannerSheet: some View {
        ZStack(alignment: .top) {
            QRScannerView { scanned in
                showScanner = false
                if FriendCode.normalize(scanned) != nil {
                    add(code: scanned)
                } else {
                    resultMessage = ("That QR code isn't a DropIn friend code.", true)
                }
            }
            .ignoresSafeArea()

            HStack {
                Text("Point at a friend's DropIn code")
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                Spacer()
                DropInCloseButton { showScanner = false }
            }
            .padding(.horizontal, DropInLayout.sheetMargin)
            .padding(.top, DropInLayout.sheetTopPadding)
        }
    }

    // MARK: - Rows

    private func section<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        .background(Capsule().fill(Color.white.opacity(0.8)))
                }
            }
            content()
        }
    }

    private func personRow<Trailing: View>(userId: String, subtitle: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        let user = homeViewModel.usersById[userId]
        return HStack(spacing: 12) {
            AvatarView(name: user?.name ?? "Friend", imageName: user?.avatarUrl, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.name ?? "Friend")
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.dropInIndigo)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.5))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
                .layoutPriority(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .dropInCard(cornerRadius: 18)
    }

    private func incomingRow(_ request: Friendship) -> some View {
        personRow(userId: request.otherUserId(than: me) ?? "", subtitle: "Wants to be friends") {
            HStack(spacing: 6) {
                Menu {
                    Button {
                        homeViewModel.removeFriendship(request)
                    } label: {
                        Label("Decline", systemImage: "xmark")
                    }
                    if let other = request.otherUserId(than: me) {
                        let name = homeViewModel.usersById[other]?.name ?? "this person"
                        Button {
                            reportTarget = ReportTarget(userId: other, userName: name, kind: .user)
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                        Button(role: .destructive) {
                            blockTarget = (other, name)
                        } label: {
                            Label("Decline & Block", systemImage: "hand.raised.slash")
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.dropInIndigo.opacity(0.6))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white))
                        .contentShape(Circle())
                }
                .accessibilityLabel("Decline options")

                Button("Accept") {
                    homeViewModel.acceptFriendRequest(request)
                }
                .buttonStyle(SmallCapsuleButtonStyle(filled: true))
            }
        }
    }

    private func outgoingRow(_ request: Friendship) -> some View {
        personRow(userId: request.otherUserId(than: me) ?? "", subtitle: "Waiting for them to accept") {
            Button("Cancel") {
                homeViewModel.removeFriendship(request)
            }
            .buttonStyle(SmallCapsuleButtonStyle(filled: false))
        }
    }

    private func friendRow(_ friend: User) -> some View {
        personRow(userId: friend.id ?? "", subtitle: nil) {
            Menu {
                Button(role: .destructive) {
                    friendToRemove = friend
                } label: {
                    Label("Remove Friend", systemImage: "person.fill.xmark")
                }
                if let id = friend.id {
                    Button {
                        reportTarget = ReportTarget(userId: id, userName: friend.name, kind: .user)
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        blockTarget = (id, friend.name)
                    } label: {
                        Label("Block", systemImage: "hand.raised.slash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.dropInIndigo.opacity(0.65))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Options for \(friend.name)")
        }
    }

    // MARK: - QR image

    /// Adds the QR image to the Photos library. Only asks for "add photos"
    /// permission, so DropIn can't see anyone's existing photos.
    private func saveToPhotos(_ image: UIImage) {
        saveMessage = nil
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                saveMessage = ("Photos access is off. Turn it on in Settings → DropIn → Photos.", true)
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                saveMessage = ("Saved to Photos!", false)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                saveMessage = ("Couldn't save the image. Please try again.", true)
            }
        }
    }

    /// Adds a white border so the saved image scans reliably.
    static func paddedForSharing(_ qr: UIImage) -> UIImage {
        let padding: CGFloat = qr.size.width * 0.12
        let size = CGSize(width: qr.size.width + padding * 2, height: qr.size.height + padding * 2)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            qr.draw(in: CGRect(x: padding, y: padding, width: qr.size.width, height: qr.size.height))
        }
    }

    static func qrImage(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Compact pill button used on the Friends and nudge screens.
struct SmallCapsuleButtonStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DropInFont.bodyMedium(14))
            .foregroundColor(filled ? .white : .dropInIndigo)
            // Keep labels on one line; the row around it shrinks instead.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Capsule().fill(filled ? Color.dropInCoral : Color.white))
            .overlay(Capsule().stroke(Color.dropInIndigo.opacity(filled ? 0 : 0.1), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
