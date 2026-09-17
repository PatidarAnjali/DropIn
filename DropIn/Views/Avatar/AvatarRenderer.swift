//
//  AvatarRenderer.swift
//  DropIn
//
//  Draws an AvatarConfig with SwiftUI's Canvas. Everything is drawn on a
//  100×100 grid and scaled to whatever size the view is, so the same
//  avatar looks crisp as a 22pt attendee bubble or a 180pt preview.
//
//  Layers are painted back to front:
//  background → back hair → body/outfit → ears → head → cheeks →
//  facial hair → nose/eyes/brows/mouth → front hair → earrings →
//  headwear → glasses.
//
//  Shapes are written as SVG-style path strings ("M x y C ..."), which
//  makes them easy to tweak or to design in a vector app (Figma, etc.)
//  and paste in. Supported commands: M, L, Q, C, Z (absolute).
//

import SwiftUI

/// How much of the avatar to show. The builder zooms option thumbnails
/// in so small details (eyes, brows) are easy to see.
enum AvatarFocus {
    case full, head, face

    fileprivate var zoom: CGFloat {
        switch self {
        case .full: 1.1
        case .head: 1.4
        case .face: 1.9
        }
    }
    /// Point on the 100×100 grid to zoom around...
    fileprivate var anchorY: CGFloat {
        switch self {
        case .full: 56
        case .head: 40
        case .face: 47
        }
    }
    /// ...and where that point ends up.
    fileprivate var targetY: CGFloat {
        switch self {
        case .full: 56
        case .head: 50
        case .face: 50
        }
    }
}

struct AvatarRenderer: View {
    let config: AvatarConfig
    var focus: AvatarFocus = .full

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let scale = side / 100
            context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            context.scaleBy(x: scale, y: scale)

            context.translateBy(x: 50, y: focus.targetY)
            context.scaleBy(x: focus.zoom, y: focus.zoom)
            context.translateBy(x: -50, y: -focus.anchorY)

            AvatarPainter(c: config, ctx: context).draw()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Avatar")
    }
}

// MARK: - Painter

private struct AvatarPainter {
    let c: AvatarConfig
    let ctx: GraphicsContext

    let ink = "3B2E2A"

    func draw() {
        ctx.fill(Path(CGRect(x: -100, y: -100, width: 300, height: 300)),
                 with: .color(color(c.backgroundColor)))
        drawHairBack()
        drawBody()
        let earX = drawEars()
        fill(facePath, c.skinTone)
        drawCheeks()
        drawFacialHair()
        stroke("M50 47 Q48.5 50 50.8 50.4", c.skinTone, amt: -0.3, width: 1.2) // nose
        drawEyes()
        drawBrows()
        drawMouth()
        drawHairFront()
        drawEarrings(leftX: earX.left, rightX: earX.right)
        drawHeadwear()
        drawEyewear()
    }

    // MARK: Head

    private var facePath: String {
        switch c.faceShape {
        case .oval:   "M50 20 C62 20 69 30 69 43 C69 57 61 66 50 66 C39 66 31 57 31 43 C31 30 38 20 50 20 Z"
        case .round:  "M50 22 C62 22 71 31 71 44 C71 57 62 66 50 66 C38 66 29 57 29 44 C29 31 38 22 50 22 Z"
        case .square: "M41 21 L59 21 C66 21 70 25 70 32 L70 54 C70 62 64 66 57 66 L43 66 C36 66 30 62 30 54 L30 32 C30 25 34 21 41 21 Z"
        case .heart:  "M50 21 C63 21 70 29 70 40 C70 53 60 63 50 67 C40 63 30 53 30 40 C30 29 37 21 50 21 Z"
        }
    }

    private func drawEars() -> (left: CGFloat, right: CGFloat) {
        let right: CGFloat = switch c.faceShape {
        case .round: 71
        case .square, .heart: 70
        case .oval: 69
        }
        let left = 100 - right
        for x in [left, right] {
            ellipse(x, 45, 4.5, 6, c.skinTone)
            ellipse(x, 45, 2, 3.2, c.skinTone, amt: -0.12)
        }
        return (left, right)
    }

    private func drawCheeks() {
        if c.extras == .blush || c.extras == .both {
            ellipse(38, 52, 4, 2.4, "F08FA0", opacity: 0.35)
            ellipse(62, 52, 4, 2.4, "F08FA0", opacity: 0.35)
        }
        if c.extras == .freckles || c.extras == .both {
            let spots: [(CGFloat, CGFloat)] = [(37, 49), (40, 50.5), (38.5, 52), (63, 49), (60, 50.5), (61.5, 52)]
            for (x, y) in spots {
                ellipse(x, y, 0.6, 0.6, c.skinTone, amt: -0.35)
            }
        }
    }

    // MARK: Body

    private func drawBody() {
        let halfWidth: CGFloat = switch c.build {
        case .narrow: 26
        case .average: 32
        case .broad: 38
        }
        let l = 50 - halfWidth
        let r = 50 + halfWidth
        let top = c.topColor

        // Neck + chin shadow
        roundRect(43, 56, 14, 20, 6, c.skinTone)
        fill("M43 60 L57 60 L57 65 Q50 72 43 65 Z", c.skinTone, amt: -0.15)

        let torso = "M\(l) 104 C\(l) 86 \(l + 8) 78 42 75 Q50 79 58 75 C\(r - 8) 78 \(r) 86 \(r) 104 Z"

        switch c.top {
        case .tee:
            fill(torso, top)
            stroke("M42 75 Q50 81 58 75", top, amt: -0.25, width: 1.6)
        case .vneck:
            fill(torso, top)
            fill("M42 75 L50 86 L58 75 Q50 78 42 75 Z", c.skinTone)
            stroke("M42 75 L50 86 L58 75", top, amt: -0.25, width: 1.6)
        case .hoodie:
            fill("M34 78 Q50 64 66 78 Q50 86 34 78 Z", top, amt: -0.2) // hood
            fill(torso, top)
            stroke("M46 80 L45 92", "FFFFFF", width: 1.3)
            stroke("M54 80 L55 92", "FFFFFF", width: 1.3)
            roundRect(38, 93, 24, 8, 4, top, amt: -0.12) // pocket
        case .collar:
            fill(torso, top)
            fill("M42 74 L50 80 L44 86 L39 77 Z", "FFFFFF")
            fill("M58 74 L50 80 L56 86 L61 77 Z", "FFFFFF")
            stroke("M50 80 L50 104", top, amt: -0.25, width: 1.2)
        case .turtleneck:
            fill(torso, top)
            roundRect(41, 66, 18, 13, 5, top, amt: -0.08)
        }
    }

    // MARK: Face features

    private func drawEyes() {
        for x: CGFloat in [42, 58] {
            var style = c.eyes
            if style == .wink { style = (x == 42) ? .dots : .happy }

            switch style {
            case .dots, .wink:
                ellipse(x, 44, 2.2, 2.6, ink)
            case .round:
                ellipse(x, 44, 3.6, 3.8, "FFFFFF")
                ellipse(x, 44.6, 2.1, 2.3, ink)
                ellipse(x + 0.8, 43.6, 0.7, 0.7, "FFFFFF")
            case .happy:
                stroke("M\(x - 3) 45 Q\(x) 41 \(x + 3) 45", ink, width: 1.6)
            case .sleepy:
                stroke("M\(x - 3) 44 Q\(x) 47 \(x + 3) 44", ink, width: 1.6)
            case .lashes:
                ellipse(x, 44.5, 2.2, 2.6, ink)
                let side: CGFloat = (x == 42) ? -1 : 1
                stroke("M\(x + 2 * side) 42.5 L\(x + 3.6 * side) 41", ink, width: 1.1)
            }
        }
    }

    private func drawBrows() {
        let browColor = c.hairColor
        for x: CGFloat in [42, 58] {
            let side: CGFloat = (x == 42) ? -1 : 1
            switch c.brows {
            case .none:
                break
            case .soft:
                stroke("M\(x - 3) 38.5 Q\(x) 36.5 \(x + 3) 38.5", browColor, amt: -0.1, width: 1.3)
            case .bold:
                stroke("M\(x - 3.2) 38 L\(x + 3.2) 38", browColor, amt: -0.1, width: 2.4)
            case .raised:
                stroke("M\(x - 3 * side) 38.5 Q\(x) 35.5 \(x + 3 * side) 36.8", browColor, amt: -0.1, width: 1.5)
            case .angry:
                stroke("M\(x + 3 * side) 36.5 L\(x - 3 * side) 38.8", browColor, amt: -0.1, width: 1.8)
            }
        }
    }

    private func drawMouth() {
        let openMouth = "M44 54 Q50 54 56 54 Q55.5 61 50 61 Q44.5 61 44 54 Z"
        switch c.mouth {
        case .smile:
            stroke("M45 55 Q50 59 55 55", ink, width: 1.6)
        case .grin:
            fill(openMouth, ink)
            fill("M45 54.2 L55 54.2 Q54.8 56 54 56.4 L46 56.4 Q45.2 56 45 54.2 Z", "FFFFFF")
        case .open:
            ellipse(50, 56.5, 2.6, 3.2, ink)
        case .flat:
            stroke("M46 56 L54 56", ink, width: 1.6)
        case .smirk:
            stroke("M45.5 56 Q51 57.5 55 53.8", ink, width: 1.6)
        case .tongue:
            fill(openMouth, ink)
            ellipse(51, 59, 3, 2.4, "F08FA0")
        }
    }

    private func drawFacialHair() {
        let hair = c.hairColor
        switch c.facialHair {
        case .none:
            break
        case .stubble:
            fill("M31 48 C32 60 40 67 50 67 C60 67 68 60 69 48 C66 56 60 61 50 61 C40 61 34 56 31 48 Z", hair, opacity: 0.28)
        case .mustache:
            fill("M50 51.5 C46 50.5 42.5 52 42 55 C44.5 53.5 47 54 50 53.8 C53 54 55.5 53.5 58 55 C57.5 52 54 50.5 50 51.5 Z", hair)
        case .goatee:
            fill("M45 60 Q50 62 55 60 Q55 67 50 68 Q45 67 45 60 Z", hair)
            fill("M50 51.5 C46 50.5 43 52 43 54.5 C45 53.5 47 53.8 50 53.6 C53 53.8 55 53.5 57 54.5 C57 52 54 50.5 50 51.5 Z", hair)
        case .beard:
            fill("M30 42 C30 60 38 70 50 70 C62 70 70 60 70 42 L67 42 C66 50 62 52 57 52 C54 50 46 50 43 52 C38 52 34 50 33 42 Z", hair)
        }
    }

    // MARK: Hair

    private func drawHairBack() {
        let hair = c.hairColor
        let hatOnTop = c.headwear.coversTopOfHead
        switch c.hairStyle {
        case .long:
            fill("M26 40 C26 20 38 13 50 13 C62 13 74 20 74 40 L76 82 Q50 90 24 82 Z", hair, amt: -0.1)
        case .bob:
            fill("M26 40 C26 20 38 14 50 14 C62 14 74 20 74 40 L74 62 Q72 66 66 66 L34 66 Q28 66 26 62 Z", hair, amt: -0.1)
        case .afro:
            ellipse(50, 38, 30, 27, hair)
        case .bun where !hatOnTop:
            ellipse(50, 13, 9, 8, hair)
        case .spaceBuns where !hatOnTop:
            ellipse(31, 22, 8, 8, hair)
            ellipse(69, 22, 8, 8, hair)
        case .curly:
            for (x, y) in [(29, 40), (71, 40), (28, 31), (72, 31)] as [(CGFloat, CGFloat)] {
                ellipse(x, y, 7, 7, hair)
            }
        default:
            break
        }
    }

    private func drawHairFront() {
        let hair = c.hairColor
        let topKnot = "M30 40 C29 23 39 18 50 18 C61 18 71 23 70 40 C67 30 60 25 50 25 C40 25 33 30 30 40 Z"
        switch c.hairStyle {
        case .none:
            break
        case .buzz:
            fill("M30 40 C29 24 38 18 50 18 C62 18 71 24 70 40 C68 31 62 26 50 26 C38 26 32 31 30 40 Z", hair, opacity: 0.85)
        case .short:
            fill("M29 42 C26 22 37 14 51 14 C65 14 74 22 71 42 C69 35 66 31 63 29 C56 32 44 32 37 28 C33 31 30 36 29 42 Z", hair)
        case .swoop:
            fill("M29 42 C25 20 40 12 54 14 C69 16 75 26 71 42 C69 33 65 28 61 26 C53 32 40 32 33 33 C31 36 30 39 29 42 Z", hair)
        case .curly:
            let curls: [(CGFloat, CGFloat)] = [(33, 25), (42, 19), (51, 17), (60, 19), (67, 26), (38, 28), (62, 28), (50, 24)]
            for (x, y) in curls {
                ellipse(x, y, 7, 7, hair)
            }
        case .afro:
            fill("M31 38 C31 30 40 27 50 29 C60 27 69 30 69 38 C69 24 62 19 50 19 C38 19 31 24 31 38 Z", hair, amt: -0.08)
        case .long:
            fill("M29 46 C27 22 38 15 50 15 C62 15 73 22 71 46 C69 34 62 27 51 25 C50 30 44 34 36 35 C32 38 30 42 29 46 Z", hair)
        case .bob:
            fill("M29 40 C28 22 38 16 50 16 C62 16 72 22 71 40 L71 33 Q50 36 29 33 Z", hair)
        case .bun, .spaceBuns:
            fill(topKnot, hair)
        case .mohawk:
            if !c.headwear.coversTopOfHead {
                fill("M45 30 C44 18 46 8 50 6 C54 8 56 18 55 30 C53 27 47 27 45 30 Z", hair)
            }
        }
    }

    // MARK: Accessories

    private func drawEarrings(leftX: CGFloat, rightX: CGFloat) {
        let gold = "E8B04B"
        for x in [leftX, rightX] {
            switch c.earrings {
            case .none:
                break
            case .studs:
                ellipse(x, 51.5, 1.6, 1.6, gold)
            case .hoops:
                ctx.stroke(ellipsePath(x, 54, 2.8, 2.8), with: .color(color(gold)), lineWidth: 1.2)
            }
        }
    }

    private func drawHeadwear() {
        let hat = c.headwearColor
        switch c.headwear {
        case .none:
            break
        case .beanie:
            fill("M27 36 C27 16 38 10 50 10 C62 10 73 16 73 36 Z", hat)
            roundRect(25, 30, 50, 9, 4.5, hat, amt: -0.15)
            ellipse(50, 9, 5, 5, "FFFCFA")
        case .cap:
            fill("M29 33 C29 17 39 12 50 12 C61 12 71 17 71 33 Z", hat)
            fill("M27 31 Q50 27 73 31 Q74 36 70 36 Q50 32 30 36 Q26 36 27 31 Z", hat, amt: -0.25)
            ellipse(50, 13, 2, 1.5, hat, amt: 0.3)
        case .bow:
            fill("M66 22 L58 16 Q56 22 58 28 Z", hat)
            fill("M66 22 L74 16 Q76 22 74 28 Z", hat)
            ellipse(66, 22, 2.4, 2.4, hat, amt: -0.15)
        case .flower:
            let petals: [(CGFloat, CGFloat)] = [(0, -3.5), (3.3, -1.1), (2.1, 2.9), (-2.1, 2.9), (-3.3, -1.1)]
            for (dx, dy) in petals {
                ellipse(66 + dx, 22 + dy, 2.8, 2.8, "FFFCFA")
            }
            ellipse(66, 22, 2.2, 2.2, "E8B04B")
        case .headphones:
            stroke("M28 44 C26 14 74 14 72 44", "3A3A40", width: 3)
            roundRect(24, 38, 8, 14, 4, hat)
            roundRect(68, 38, 8, 14, 4, hat)
        }
    }

    private func drawEyewear() {
        let lens = color("FFFFFF", opacity: 0.15)
        switch c.eyewear {
        case .none:
            break
        case .round:
            for x: CGFloat in [42, 58] {
                let p = ellipsePath(x, 44, 6, 6)
                ctx.fill(p, with: .color(lens))
                ctx.stroke(p, with: .color(color(ink)), lineWidth: 1.4)
            }
            stroke("M48 44 Q50 42.5 52 44", ink, width: 1.4)
        case .square:
            for x: CGFloat in [42, 58] {
                let p = Path(roundedRect: CGRect(x: x - 6.5, y: 39, width: 13, height: 10), cornerRadius: 3)
                ctx.fill(p, with: .color(lens))
                ctx.stroke(p, with: .color(color(ink)), lineWidth: 1.6)
            }
            stroke("M48.5 43 L51.5 43", ink, width: 1.6)
        case .shades:
            for x: CGFloat in [42, 58] {
                roundRect(x - 6.5, 40, 13, 8.5, 4, "2B2521")
                stroke("M\(x - 4.5) 42 L\(x - 2) 42", "FFFFFF", width: 1, opacity: 0.5)
            }
            stroke("M48.5 43 L51.5 43", "2B2521", width: 1.6)
        case .heart:
            for x: CGFloat in [42, 58] {
                fill("M\(x) 49 C\(x - 4) 46.5 \(x - 7) 44 \(x - 6.5) 41.5 C\(x - 6) 39 \(x - 2) 38.5 \(x) 41 C\(x + 2) 38.5 \(x + 6) 39 \(x + 6.5) 41.5 C\(x + 7) 44 \(x + 4) 46.5 \(x) 49 Z", "F08FA0", opacity: 0.9)
            }
            stroke("M48 42 L52 42", "F08FA0", width: 1.4)
        }
    }

    // MARK: Drawing helpers

    private func fill(_ d: String, _ hex: String, amt: Double = 0, opacity: Double = 1) {
        ctx.fill(SVGPath.parse(d), with: .color(color(hex, amt, opacity: opacity)))
    }

    private func stroke(_ d: String, _ hex: String, amt: Double = 0, width: CGFloat, opacity: Double = 1) {
        ctx.stroke(SVGPath.parse(d),
                   with: .color(color(hex, amt, opacity: opacity)),
                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                         _ hex: String, amt: Double = 0, opacity: Double = 1) {
        ctx.fill(ellipsePath(cx, cy, rx, ry), with: .color(color(hex, amt, opacity: opacity)))
    }

    private func ellipsePath(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat,
                           _ hex: String, amt: Double = 0) {
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r),
                 with: .color(color(hex, amt)))
    }

    /// Hex → Color. `amt` < 0 darkens (shadows), > 0 lightens (highlights).
    private func color(_ hex: String, _ amt: Double = 0, opacity: Double = 1) -> Color {
        let value = UInt64(hex, radix: 16) ?? 0
        func channel(_ shift: UInt64) -> Double {
            let v = Double((value >> shift) & 0xFF) / 255
            return amt < 0 ? v * (1 + amt) : v + (1 - v) * amt
        }
        return Color(red: channel(16), green: channel(8), blue: channel(0)).opacity(opacity)
    }
}

// MARK: - Tiny SVG path parser

enum SVGPath {
    /// Parses absolute M, L, Q, C and Z commands into a SwiftUI Path.
    static func parse(_ d: String) -> Path {
        var spaced = ""
        for ch in d {
            if ch.isLetter { spaced += " \(ch) " }
            else if ch == "," { spaced += " " }
            else { spaced.append(ch) }
        }
        let tokens = spaced.split(separator: " ")

        var path = Path()
        var i = 0
        var command: Character = "M"

        func hasNumbers(_ count: Int) -> Bool {
            guard i + count <= tokens.count else { return false }
            return tokens[i..<(i + count)].allSatisfy { Double($0) != nil }
        }
        func point() -> CGPoint {
            let x = CGFloat(Double(tokens[i]) ?? 0)
            let y = CGFloat(Double(tokens[i + 1]) ?? 0)
            i += 2
            return CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            if let first = tokens[i].first, first.isLetter {
                command = first
                i += 1
                if command == "Z" || command == "z" {
                    path.closeSubpath()
                    continue
                }
            }
            switch command {
            case "M" where hasNumbers(2):
                path.move(to: point())
            case "L" where hasNumbers(2):
                path.addLine(to: point())
            case "Q" where hasNumbers(4):
                let control = point()
                path.addQuadCurve(to: point(), control: control)
            case "C" where hasNumbers(6):
                let c1 = point()
                let c2 = point()
                path.addCurve(to: point(), control1: c1, control2: c2)
            default:
                i += 1 // skip anything unexpected rather than loop forever
            }
        }
        return path
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
            ForEach(0..<24, id: \.self) { _ in
                AvatarRenderer(config: .random())
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    .background(Color.dropInCream)
}
