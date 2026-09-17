//
//  AppBackground.swift
//  DropIn
//
//  Full-bleed background used on the Login screen ONLY; the moment the
//  app opens. It's a cream fallback fill with the hand-drawn doodle
//  wallpaper layered on top, both extending under the status bar /
//  dynamic island / home indicator so there's never a seam at the edges
//  of the screen.
//
//  Every screen the user reaches after signing in (Home, Create Status,
//  Profile) intentionally stays a plain cream background with a few
//  scattered doodle accents instead) see DoodleAccents.swift) so the
//  wallpaper doesn't compete with content during everyday use.
//

import SwiftUI

struct AppBackground: View {
    /// Dial the wallpaper back on screens that already have a lot going on
    /// (like a scrolled feed full of cards) so the doodles read as texture,
    /// not clutter.
    var wallpaperOpacity: Double = 1.0

    var body: some View {
        // The wallpaper is an overlay on the cream color rather than a
        // sibling in a ZStack. A .fill image is wider than the screen, and
        // inside a ZStack it would stretch the whole layout (pushing the
        // login form past the screen edges). As an overlay it can't affect
        // size; it just gets cropped to the screen.
        Color.dropInCream
            .overlay(
                Image("DoodleWallpaper")
                    .resizable()
                    .scaledToFill()
                    .opacity(wallpaperOpacity)
            )
            .clipped()
            .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
}
