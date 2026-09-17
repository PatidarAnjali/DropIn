//
//  Theme.swift
//  DropIn
//
//  Central place for colors, fonts, and spacing so every screen
//  pulls from the same palette instead of hardcoding hex values.
//

import SwiftUI
import CoreText

// MARK: - Colors
// Pulled directly from your branding showcase swatches.
extension Color {
    static let dropInCoral = Color(hex: "E2735A") // Warm Coral: primary actions
    static let dropInIndigo = Color(hex: "23345C") // Indigo Blue: headings/nav
    static let dropInCream = Color(hex: "FFFCFA") // Cream: app background
    static let dropInSageGreen = Color(hex: "AFC2A5") // Soft Sage Green: accents/cards
    static let dropInPalePink = Color(hex: "F2C9CE") // Pale Pink: accents/cards

    // Doodle background icons — soft, low-opacity scribbles scattered behind
    // content (clocks, stars, mugs, clouds). Keep these muted so they read
    // as texture, not UI.
    static let dropInDoodleLine = Color(hex: "8A8175") // gray-brown outline doodles
    static let dropInDoodleAccent = Color(hex: "E8C9A0") // pale tan stars/sparkles

    /// Convenience hex initializer, e.g. Color(hex: "E2735A")
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Layout
enum DropInLayout {
    /// Standard horizontal margin used at the edges of every screen so
    /// content never touches the sides of the device.
    static let screenMargin: CGFloat = 24

    /// Side margin for sheets (Profile, What are you up to?, avatar
    /// builder, who's dropping in). Roomier than `screenMargin`.
    static let sheetMargin: CGFloat = 36

    /// Space above the title row on sheets.
    static let sheetTopPadding: CGFloat = 32

    /// How far the sheet close (X) button sits from the right edge of the
    /// screen. Smaller than `sheetMargin` on purpose: the X sits a little
    /// closer to the corner than the content does.
    static let closeButtonEdgeInset: CGFloat = 20
}

// MARK: - Sheet close button
/// Circled X used at the top-right of every sheet.
///
/// Place it at the end of a header row inside a view padded with
/// `DropInLayout.sheetMargin`. It pulls itself out past that margin so
/// it sits `closeButtonEdgeInset` from the screen edge.
struct DropInCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.dropInIndigo.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.dropInIndigo.opacity(0.18), lineWidth: 1.5))
                .shadow(color: Color.dropInIndigo.opacity(0.06), radius: 4, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .padding(.trailing, -(DropInLayout.sheetMargin - DropInLayout.closeButtonEdgeInset))
    }
}

// MARK: - Fonts
// Raleway Bold  → the "DropIn" name only (DropInFont.brand)
// Open Sans → every other piece of text
//
// The .ttf files live in Resources/Fonts. They're registered in code the
// first time any DropInFont is used, so there's no Info.plist setup and
// they also work in Xcode Previews. If a file is ever missing, SwiftUI
// falls back to the system font instead of crashing.
enum DropInFont {
    /// The "DropIn" wordmark.
    static func brand(_ size: CGFloat) -> Font {
        FontRegistrar.ensureRegistered()
        return .custom("Raleway-Bold", size: size)
    }
    /// Screen and section titles.
    static func heading(_ size: CGFloat) -> Font {
        FontRegistrar.ensureRegistered()
        return .custom("OpenSans-Bold", size: size)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        FontRegistrar.ensureRegistered()
        return .custom("OpenSans-Regular", size: size)
    }
    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        FontRegistrar.ensureRegistered()
        return .custom("OpenSans-SemiBold", size: size)
    }
}

/// Registers the bundled .ttf files with the system once per launch.
enum FontRegistrar {
    private static var didRegister = false

    static func ensureRegistered() {
        guard !didRegister else { return }
        didRegister = true
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Reusable button style
struct DropInPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DropInFont.bodyMedium(17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color.dropInCoral, Color.dropInCoral.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.dropInCoral.opacity(configuration.isPressed ? 0.15 : 0.35), radius: 12, y: 6)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Cute card style
// A soft, rounded, gently-shadowed white card — the base look for form
// panels, sheets, and content containers across the app.
struct DropInCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 22
    var fill: Color = .white

    func body(content: Content) -> some View {
        content
            .background(fill.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.dropInIndigo.opacity(0.08), radius: 16, y: 8)
    }
}

extension View {
    func dropInCard(cornerRadius: CGFloat = 22, fill: Color = .white) -> some View {
        modifier(DropInCardStyle(cornerRadius: cornerRadius, fill: fill))
    }
}
