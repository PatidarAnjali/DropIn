//
//  ReportSheet.swift
//  DropIn
//
//  Report a person, plan, or nudge. Reports are saved to Firestore's
//  `reports` collection for review; nobody in the app can read them.
//

import SwiftUI

struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: ReportTarget
    /// Sends the report. Returns false if it couldn't be sent.
    let onSubmit: (_ reason: Report.Reason, _ details: String, _ alsoBlock: Bool) async -> Bool

    @State private var reason: Report.Reason?
    @State private var details = ""
    @State private var alsoBlock = true
    @State private var isSending = false
    @State private var sent = false
    @State private var failed = false

    private var subject: String {
        switch target.kind {
        case .user: target.userName
        case .plan: "\(target.userName)'s plan"
        case .nudge: "\(target.userName)'s nudge"
        }
    }

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sent ? "Thanks for telling us" : "Report \(subject)")
                                .font(DropInFont.heading(22))
                                .foregroundColor(.dropInIndigo)
                            if let text = target.contentText, !sent {
                                Text("\u{201C}\(text)\u{201D}")
                                    .font(DropInFont.body(13))
                                    .foregroundColor(.dropInIndigo.opacity(0.55))
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        DropInCloseButton { dismiss() }
                    }

                    if sent {
                        confirmation
                    } else {
                        form
                    }
                }
                .padding(.horizontal, DropInLayout.sheetMargin)
                .padding(.top, DropInLayout.sheetTopPadding)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your report is private. \(target.userName) won't know who sent it.")
                .font(DropInFont.body(13))
                .foregroundColor(.dropInIndigo.opacity(0.6))

            VStack(spacing: 8) {
                ForEach(Report.Reason.allCases, id: \.self) { option in
                    reasonRow(option)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Anything else? (optional)")
                    .font(DropInFont.bodyMedium(14))
                    .foregroundColor(.dropInIndigo)
                TextField("Add details", text: $details, axis: .vertical)
                    .font(DropInFont.body(15))
                    .lineLimit(3...6)
                    .padding(14)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1)
                    )
            }

            Toggle(isOn: $alsoBlock) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Also block \(target.userName)")
                        .font(DropInFont.bodyMedium(14))
                        .foregroundColor(.dropInIndigo)
                    Text("You'll stop seeing each other and they can't add you.")
                        .font(DropInFont.body(12))
                        .foregroundColor(.dropInIndigo.opacity(0.5))
                }
            }
            .tint(.dropInCoral)
            .padding(14)
            .dropInCard(cornerRadius: 16)

            if failed {
                Label("Couldn't send your report. Check your connection and try again.", systemImage: "exclamationmark.circle.fill")
                    .font(DropInFont.body(13))
                    .foregroundColor(.dropInCoral)
            }

            Button {
                guard let reason else { return }
                isSending = true
                failed = false
                Task {
                    let ok = await onSubmit(reason, details, alsoBlock)
                    isSending = false
                    withAnimation {
                        if ok { sent = true } else { failed = true }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isSending { ProgressView().tint(.white) }
                    Text("Send Report")
                }
            }
            .buttonStyle(DropInPrimaryButtonStyle())
            .disabled(reason == nil || isSending)
            .opacity(reason == nil ? 0.5 : 1)
        }
    }

    private func reasonRow(_ option: Report.Reason) -> some View {
        let isSelected = reason == option
        return Button {
            reason = option
        } label: {
            HStack {
                Text(option.title)
                    .font(DropInFont.bodyMedium(15))
                    .foregroundColor(.dropInIndigo)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .dropInCoral : .dropInIndigo.opacity(0.2))
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(isSelected ? 0.95 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.dropInCoral.opacity(0.6) : Color.dropInIndigo.opacity(0.06), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var confirmation: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.dropInCoral)
            Text(alsoBlock
                 ? "We got your report, and \(target.userName) is blocked."
                 : "We got your report and will take a look.")
                .font(DropInFont.bodyMedium(16))
                .foregroundColor(.dropInIndigo)
                .multilineTextAlignment(.center)
            Text("If you're ever in danger, contact local emergency services.")
                .font(DropInFont.body(13))
                .foregroundColor(.dropInIndigo.opacity(0.55))
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(DropInPrimaryButtonStyle())
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
}
