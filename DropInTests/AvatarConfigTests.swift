//
//  AvatarConfigTests.swift
//  DropInTests
//
//  Avatars are saved as text in Firestore, so saving and loading must
//  never lose or break anything, even for avatars saved by an older
//  version of the app.
//

import Foundation
import Testing
@testable import DropIn

@MainActor
@Suite("Avatar saving")
struct AvatarConfigTests {

    @Test("Saving and loading gives back the exact same avatar")
    func roundTrip() {
        var avatar = AvatarConfig()
        avatar.hairStyle = .spaceBuns
        avatar.hairColor = AvatarPalette.hair[6]
        avatar.eyewear = .heart
        avatar.headwear = .headphones
        avatar.top = .hoodie

        let saved = avatar.storageString
        #expect(saved.hasPrefix(AvatarConfig.storagePrefix))
        #expect(AvatarConfig(storageString: saved) == avatar)
    }

    @Test("Every quick-start look survives saving")
    func quickStartsRoundTrip() {
        for look in AvatarConfig.quickStarts {
            #expect(AvatarConfig(storageString: look.storageString) == look)
        }
    }

    @Test("Old premade picks and empty values aren't treated as custom avatars", arguments: [
        "Avatar6", "", "dropin-avatar:not json",
    ])
    func notCustom(value: String) {
        #expect(AvatarConfig(storageString: value) == nil)
    }

    @Test("Missing fields fall back to defaults")
    func missingFields() throws {
        let avatar = try #require(AvatarConfig(storageString: #"dropin-avatar:{"hairStyle":"bob"}"#))
        #expect(avatar.hairStyle == .bob)
        #expect(avatar.eyes == AvatarConfig().eyes)
    }

    @Test("Unknown options from a newer app version don't break loading")
    func unknownValues() throws {
        let avatar = try #require(AvatarConfig(storageString: #"dropin-avatar:{"hairStyle":"dreadlocks","eyes":"happy"}"#))
        #expect(avatar.hairStyle == AvatarConfig().hairStyle)
        #expect(avatar.eyes == .happy)
    }
}
