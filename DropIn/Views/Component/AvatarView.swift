//
//  AvatarView.swift
//  DropIn
//
//  Shows a friend's picture avatar when we have one (either a local asset
//  name for mock/demo data, or later a remote URL from Firebase Storage),
//  and falls back to a soft initials bubble otherwise so the UI never
//  shows a broken image.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    var imageName: String? = nil
    var size: CGFloat = 34
    var ringColor: Color = .white

    var body: some View {
        Group {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(DropInFont.bodyMedium(size * 0.42))
                            .foregroundColor(.dropInIndigo)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ringColor, lineWidth: 2))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

#Preview {
    HStack(spacing: -10) {
        AvatarView(name: "Mara", imageName: "Avatar6", size: 40)
        AvatarView(name: "Rarian", imageName: "Avatar12", size: 40)
        AvatarView(name: "Name", imageName: nil, size: 40)
    }
    .padding()
    .background(Color.dropInCream)
}
