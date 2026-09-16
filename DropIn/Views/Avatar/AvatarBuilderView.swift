//
//  AvatarBuilderView.swift
//  DropIn
//
//  Build-your-own avatar. Starts from a plain body (or whatever the user
//  saved last), with a live preview on top and tabs of choices below.
//  Every option thumbnail shows *your* avatar wearing that option, so
//  people can see exactly what they're picking.
//

import SwiftUI

struct AvatarBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var config: AvatarConfig
    @State private var tab: BuilderTab = .body
    @State private var previewBounce = false

    let onSave: (AvatarConfig) -> Void

    init(initial: AvatarConfig = AvatarConfig(), onSave: @escaping (AvatarConfig) -> Void) {
        _config = State(initialValue: initial)
        self.onSave = onSave
    }

    private enum BuilderTab: String, CaseIterable {
        case body = "Body"
        case hair = "Hair"
        case face = "Face"
        case style = "Style"
        case extras = "Extras"

        var icon: String {
            switch self {
            case .body: "figure.stand"
            case .hair: "comb.fill"
            case .face: "face.smiling"
            case .style: "tshirt.fill"
            case .extras: "sparkles"
            }
        }
    }

    private let optionColumns = [GridItem(.adaptive(minimum: 72), spacing: 14)]

    var body: some View {
        ZStack {
            Color.dropInCream.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                preview
                tabBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        tabContent
                    }
                    .padding(.horizontal, DropInLayout.sheetMargin)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, DropInLayout.sheetTopPadding)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save Avatar") {
                onSave(config)
                dismiss()
            }
            .buttonStyle(DropInPrimaryButtonStyle())
            .padding(.horizontal, DropInLayout.sheetMargin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.dropInCream.opacity(0.95))
        }
        .onChange(of: config) {
            // Little "pop" on the preview whenever something changes.
            previewBounce = true
            Task {
                try? await Task.sleep(for: .milliseconds(120))
                previewBounce = false
            }
        }
    }

    // MARK: - Header & preview

    private var header: some View {
        HStack {
            Text("Make your avatar")
                .font(DropInFont.heading(24))
                .foregroundColor(.dropInIndigo)
            Spacer()
            DropInCloseButton { dismiss() }
        }
        .padding(.horizontal, DropInLayout.sheetMargin)
    }

    private var preview: some View {
        HStack(alignment: .bottom, spacing: 18) {
            roundIconButton("arrow.counterclockwise", label: "Reset") {
                config = AvatarConfig()
            }

            AvatarRenderer(config: config)
                .frame(width: 150, height: 150)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(color: Color.dropInIndigo.opacity(0.12), radius: 14, y: 6)
                .scaleEffect(previewBounce ? 1.04 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: previewBounce)

            roundIconButton("dice.fill", label: "Shuffle") {
                config = .random()
            }
        }
    }

    private func roundIconButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.dropInCoral)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(color: Color.dropInIndigo.opacity(0.06), radius: 6, y: 3)
                Text(label)
                    .font(DropInFont.body(11))
                    .foregroundColor(.dropInIndigo.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(BuilderTab.allCases, id: \.self) { item in
                    let selected = item == tab
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { tab = item }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(item.rawValue)
                                .font(DropInFont.bodyMedium(14))
                        }
                        .foregroundColor(selected ? .white : .dropInIndigo.opacity(0.75))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(selected ? Color.dropInCoral : Color.white.opacity(0.75))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DropInLayout.sheetMargin)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .body:
            quickStartSection
            section("Skin tone") { swatches(AvatarPalette.skin, \.skinTone) }
            section("Face shape") { options(\.faceShape, focus: .head) }
            section("Build") { options(\.build, focus: .full) }

        case .hair:
            section("Hair style") { options(\.hairStyle, focus: .head) }
            section("Hair color") { swatches(AvatarPalette.hair, \.hairColor) }
            section("Facial hair") { options(\.facialHair, focus: .face) }

        case .face:
            section("Eyes") { options(\.eyes, focus: .face) }
            section("Eyebrows") { options(\.brows, focus: .face) }
            section("Mouth") { options(\.mouth, focus: .face) }
            section("Cheeks") { options(\.extras, focus: .face) }

        case .style:
            section("Top") { options(\.top, focus: .full) }
            section("Top color") { swatches(AvatarPalette.clothing, \.topColor) }
            section("Background") { swatches(AvatarPalette.background, \.backgroundColor) }

        case .extras:
            section("Headwear") { options(\.headwear, focus: .head) }
            if config.headwear.isColorable {
                section("Headwear color") { swatches(AvatarPalette.clothing, \.headwearColor) }
            }
            section("Glasses") { options(\.eyewear, focus: .face) }
            section("Earrings") { options(\.earrings, focus: .head) }
        }
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)
            content()
        }
    }

    /// Ready-made looks. Tapping one keeps your current skin tone.
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick start")
                .font(DropInFont.bodyMedium(15))
                .foregroundColor(.dropInIndigo)
            Text("Pick a look to start from, then make it yours.")
                .font(DropInFont.body(13))
                .foregroundColor(.dropInIndigo.opacity(0.55))

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(AvatarConfig.quickStarts.enumerated()), id: \.offset) { _, look in
                        quickStartButton(look)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func quickStartButton(_ look: AvatarConfig) -> some View {
        var styled = look
        styled.skinTone = config.skinTone
        return Button {
            config = styled
        } label: {
            AvatarRenderer(config: styled)
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    /// Grid of thumbnails, each one showing the current avatar with that option applied.
    private func options<Option: AvatarOption>(
        _ keyPath: WritableKeyPath<AvatarConfig, Option>,
        focus: AvatarFocus
    ) -> some View {
        LazyVGrid(columns: optionColumns, spacing: 14) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                optionTile(option, keyPath: keyPath, focus: focus)
            }
        }
    }

    private func optionTile<Option: AvatarOption>(
        _ option: Option,
        keyPath: WritableKeyPath<AvatarConfig, Option>,
        focus: AvatarFocus
    ) -> some View {
        var previewConfig = config
        previewConfig[keyPath: keyPath] = option
        let isSelected = config[keyPath: keyPath] == option

        return Button {
            config[keyPath: keyPath] = option
        } label: {
            VStack(spacing: 6) {
                AvatarRenderer(config: previewConfig, focus: focus)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(isSelected ? Color.dropInCoral : Color.white,
                                        lineWidth: isSelected ? 3 : 2)
                    )
                    .scaleEffect(isSelected ? 1.05 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)

                Text(option.title)
                    .font(isSelected ? DropInFont.bodyMedium(12) : DropInFont.body(12))
                    .foregroundColor(isSelected ? .dropInCoral : .dropInIndigo.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private func swatches(_ colors: [String], _ keyPath: WritableKeyPath<AvatarConfig, String>) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { hex in
                    let isSelected = config[keyPath: keyPath] == hex
                    Button {
                        config[keyPath: keyPath] = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(Color.dropInIndigo.opacity(0.08), lineWidth: 1))
                            .padding(3)
                            .overlay(
                                Circle().stroke(isSelected ? Color.dropInCoral : Color.clear, lineWidth: 2.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    AvatarBuilderView { _ in }
}
