//
//  AvatarConfig.swift
//  DropIn
//
//  A custom avatar is just a list of choices (skin tone, hair style,
//  glasses...). AvatarRenderer turns those choices into a drawing, so
//  there are no image files to manage and every combination works.
//
//  Every option is available to everyone. There's intentionally no
//  "pick a gender" step: anyone can have long hair, a beard, lashes,
//  earrings, any build, etc.
//
//  Storage: the config is saved as a string in the existing `avatarUrl`
//  field (prefixed with "dropin-avatar:"), so User, Status and every
//  AvatarView call site keep working without schema changes. Old picks
//  like "Avatar6" still render as images.
//

import Foundation

// MARK: - Option protocol

/// Anything the builder can show as a grid of choices.
protocol AvatarOption: CaseIterable, Hashable, Codable {
    var title: String { get }
}

// MARK: - Options

enum FaceShape: String, AvatarOption {
    case oval, round, square, heart
    var title: String { rawValue.capitalized }
}

enum BodyBuild: String, AvatarOption {
    case narrow, average, broad
    var title: String {
        switch self {
        case .narrow: "Slim"
        case .average: "Average"
        case .broad: "Broad"
        }
    }
}

enum EyeStyle: String, AvatarOption {
    case dots, round, happy, sleepy, lashes, wink
    var title: String {
        switch self {
        case .round: "Bright"
        default: rawValue.capitalized
        }
    }
}

enum BrowStyle: String, AvatarOption {
    case none, soft, bold, raised, angry
    var title: String {
        switch self {
        case .angry: "Fierce"
        default: rawValue.capitalized
        }
    }
}

enum MouthStyle: String, AvatarOption {
    case smile, grin, open, flat, smirk, tongue
    var title: String {
        switch self {
        case .open: "Wow"
        case .flat: "Neutral"
        case .tongue: "Silly"
        default: rawValue.capitalized
        }
    }
}

enum FaceExtras: String, AvatarOption {
    case none, blush, freckles, both
    var title: String {
        switch self {
        case .both: "Both"
        default: rawValue.capitalized
        }
    }
}

enum HairStyle: String, AvatarOption {
    case none, buzz, short, swoop, curly, afro, long, bob, bun, spaceBuns, mohawk
    var title: String {
        switch self {
        case .none: "Bald"
        case .spaceBuns: "Space Buns"
        default: rawValue.capitalized
        }
    }
}

enum FacialHair: String, AvatarOption {
    case none, stubble, mustache, goatee, beard
    var title: String { rawValue.capitalized }
}

enum TopStyle: String, AvatarOption {
    case tee, vneck, hoodie, collar, turtleneck
    var title: String {
        switch self {
        case .tee: "T-Shirt"
        case .vneck: "V-Neck"
        case .collar: "Collared"
        default: rawValue.capitalized
        }
    }
}

enum Headwear: String, AvatarOption {
    case none, beanie, cap, bow, flower, headphones
    var title: String { rawValue.capitalized }

    /// Hats that sit on top of the head hide buns / mohawks underneath.
    var coversTopOfHead: Bool { self == .beanie || self == .cap }
    /// Whether the headwear color swatches make sense for this item.
    var isColorable: Bool { self != .none && self != .flower }
}

enum Eyewear: String, AvatarOption {
    case none, round, square, shades, heart
    var title: String { rawValue.capitalized }
}

enum Earrings: String, AvatarOption {
    case none, studs, hoops
    var title: String { rawValue.capitalized }
}

// MARK: - Palettes (hex, no "#")

enum AvatarPalette {
    static let skin = ["FFE3D1", "F6C8A6", "E3A97F", "C68642", "8D5524", "5A3825", "B9D8F2", "CDBEF0"]
    static let hair = ["2B2521", "4A3226", "7B5134", "E3BE72", "C8612F", "BDB8B2", "F2A7C3", "7FA7E0", "B79CE0", "8FB08A"]
    static let clothing = ["E2735A", "23345C", "AFC2A5", "F2C9CE", "E8B04B", "9CC8E8", "FFFCFA", "3A3A40"]
    static let background = ["F2C9CE", "DDE7D7", "F3E3C8", "D6E8F5", "E6DDF5", "F7D3C7", "FFFFFF"]
}

// MARK: - Config

struct AvatarConfig: Codable, Hashable {
    // Body
    var skinTone: String = AvatarPalette.skin[1]
    var faceShape: FaceShape = .oval
    var build: BodyBuild = .average

    // Face
    var eyes: EyeStyle = .dots
    var brows: BrowStyle = .soft
    var mouth: MouthStyle = .smile
    var extras: FaceExtras = .none

    // Hair
    var hairStyle: HairStyle = .none
    var hairColor: String = AvatarPalette.hair[1]
    var facialHair: FacialHair = .none

    // Style
    var top: TopStyle = .tee
    var topColor: String = AvatarPalette.clothing[0]
    var backgroundColor: String = AvatarPalette.background[0]

    // Accessories
    var headwear: Headwear = .none
    var headwearColor: String = AvatarPalette.clothing[1]
    var eyewear: Eyewear = .none
    var earrings: Earrings = .none
}

// MARK: - Forgiving decoding
// Missing or unknown values fall back to defaults instead of failing, so
// you can add new options later without breaking avatars saved earlier.
extension AvatarConfig {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AvatarConfig()
        func value<T: Decodable>(_ key: CodingKeys, _ defaultValue: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? defaultValue
        }
        skinTone = value(.skinTone, fallback.skinTone)
        faceShape = value(.faceShape, fallback.faceShape)
        build = value(.build, fallback.build)
        eyes = value(.eyes, fallback.eyes)
        brows = value(.brows, fallback.brows)
        mouth = value(.mouth, fallback.mouth)
        extras = value(.extras, fallback.extras)
        hairStyle = value(.hairStyle, fallback.hairStyle)
        hairColor = value(.hairColor, fallback.hairColor)
        facialHair = value(.facialHair, fallback.facialHair)
        top = value(.top, fallback.top)
        topColor = value(.topColor, fallback.topColor)
        backgroundColor = value(.backgroundColor, fallback.backgroundColor)
        headwear = value(.headwear, fallback.headwear)
        headwearColor = value(.headwearColor, fallback.headwearColor)
        eyewear = value(.eyewear, fallback.eyewear)
        earrings = value(.earrings, fallback.earrings)
    }
}

// MARK: - Storage string

extension AvatarConfig {
    static let storagePrefix = "dropin-avatar:"

    /// String saved to Firestore in `avatarUrl`.
    var storageString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return Self.storagePrefix + json
    }

    /// Returns nil for anything that isn't a custom avatar (e.g. "Avatar6").
    init?(storageString: String?) {
        guard let storageString, storageString.hasPrefix(Self.storagePrefix) else { return nil }
        let json = storageString.dropFirst(Self.storagePrefix.count)
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AvatarConfig.self, from: data) else { return nil }
        self = decoded
    }
}

// MARK: - Shuffle & quick starts

extension AvatarConfig {
    static func random() -> AvatarConfig {
        var config = AvatarConfig()
        config.skinTone = AvatarPalette.skin.randomElement()!
        config.faceShape = FaceShape.allCases.randomElement()!
        config.build = BodyBuild.allCases.randomElement()!
        config.eyes = EyeStyle.allCases.randomElement()!
        config.brows = BrowStyle.allCases.randomElement()!
        config.mouth = MouthStyle.allCases.randomElement()!
        config.hairStyle = HairStyle.allCases.randomElement()!
        config.hairColor = AvatarPalette.hair.randomElement()!
        config.top = TopStyle.allCases.randomElement()!
        config.topColor = AvatarPalette.clothing.randomElement()!
        config.backgroundColor = AvatarPalette.background.randomElement()!
        config.headwearColor = AvatarPalette.clothing.randomElement()!
        // Accessories are rarer so shuffles don't look cluttered.
        config.extras = Bool.random() ? FaceExtras.allCases.randomElement()! : .none
        config.facialHair = Int.random(in: 0..<10) < 3 ? FacialHair.allCases.randomElement()! : .none
        config.headwear = Int.random(in: 0..<10) < 4 ? Headwear.allCases.randomElement()! : .none
        config.eyewear = Int.random(in: 0..<10) < 4 ? Eyewear.allCases.randomElement()! : .none
        config.earrings = Int.random(in: 0..<10) < 4 ? Earrings.allCases.randomElement()! : .none
        return config
    }

    /// Ready-made looks to start from. Deliberately unlabeled by gender.
    static let quickStarts: [AvatarConfig] = {
        var cozy = AvatarConfig()
        cozy.hairStyle = .long; cozy.hairColor = AvatarPalette.hair[2]
        cozy.top = .turtleneck; cozy.topColor = AvatarPalette.clothing[2]
        cozy.extras = .blush; cozy.eyes = .happy; cozy.earrings = .studs

        var scholar = AvatarConfig()
        scholar.hairStyle = .swoop; scholar.hairColor = AvatarPalette.hair[0]
        scholar.eyewear = .round; scholar.top = .collar; scholar.topColor = AvatarPalette.clothing[1]
        scholar.backgroundColor = AvatarPalette.background[3]

        var sporty = AvatarConfig()
        sporty.hairStyle = .short; sporty.facialHair = .stubble
        sporty.headwear = .cap; sporty.headwearColor = AvatarPalette.clothing[1]
        sporty.top = .hoodie; sporty.topColor = AvatarPalette.clothing[0]
        sporty.mouth = .grin; sporty.backgroundColor = AvatarPalette.background[1]

        var artsy = AvatarConfig()
        artsy.hairStyle = .bob; artsy.hairColor = AvatarPalette.hair[6]
        artsy.extras = .freckles; artsy.headwear = .bow; artsy.headwearColor = AvatarPalette.clothing[4]
        artsy.top = .vneck; artsy.topColor = AvatarPalette.clothing[5]
        artsy.backgroundColor = AvatarPalette.background[4]

        var chill = AvatarConfig()
        chill.hairStyle = .afro; chill.hairColor = AvatarPalette.hair[0]
        chill.eyes = .sleepy; chill.mouth = .smirk; chill.facialHair = .goatee
        chill.top = .tee; chill.topColor = AvatarPalette.clothing[4]
        chill.backgroundColor = AvatarPalette.background[2]

        var glam = AvatarConfig()
        glam.hairStyle = .bun; glam.hairColor = AvatarPalette.hair[8]
        glam.eyes = .lashes; glam.eyewear = .heart; glam.earrings = .hoops
        glam.top = .vneck; glam.topColor = AvatarPalette.clothing[3]
        glam.backgroundColor = AvatarPalette.background[5]

        return [cozy, scholar, sporty, artsy, chill, glam]
    }()
}
