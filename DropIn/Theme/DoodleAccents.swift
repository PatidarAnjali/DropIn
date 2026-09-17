//
//  DoodleAccents.swift
//  DropIn
//
//  Home is the only screen with the full doodle wallpaper. Everywhere
//  else stays a plain cream background, but keeps a little personality
//  with a couple of faint hand-drawn-style accents tucked along the
//  screen's mid-edges; far from headers, close buttons, and bottom
//  CTAs so they never sit on top of anything tappable.
//

//import SwiftUI

//struct DoodleAccentsView: View {
//    var body: some View {
//        GeometryReader { proxy in
//            ZStack {
//                Image(systemName: "star")
//                    .font(.system(size: 20))
//                    .foregroundColor(.dropInDoodleLine.opacity(0.16))
//                    .rotationEffect(.degrees(8))
//                    .position(x: proxy.size.width * 0.06, y: proxy.size.height * 0.42)
//
//                Image(systemName: "circle.dashed")
//                    .font(.system(size: 24))
//                    .foregroundColor(.dropInDoodleLine.opacity(0.13))
//                    .position(x: proxy.size.width * 0.95, y: proxy.size.height * 0.58)
//            }
//        }
//        .allowsHitTesting(false)
//    }
//}

//extension View {
//    /// Adds a couple of faint decorative doodles along the screen's
//    /// mid-edges. Use on every screen except Login, which keeps the full
//    /// wallpaper background instead.
//    func doodleAccents() -> some View {
//        overlay(DoodleAccentsView())
//    }
//}

//#Preview {
//    Color.dropInCream.ignoresSafeArea().doodleAccents()
//}
