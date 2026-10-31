import SwiftUI

/// Minimal SVG path reader for the prototype's line art (M, L, H, V, C, S, Z and lower-case forms; no arcs).
enum SVGPath {
    static func path(_ d: String) -> Path {
        var path = Path()
        let scanner = Tokens(d)
        var current = CGPoint.zero, start = CGPoint.zero, lastControl: CGPoint?
        var command: Character = "M"
        while let next = scanner.next() {
            if case let .command(c) = next { command = c } else { scanner.pushBack(next) }
            let rel = command.isLowercase
            func pt() -> CGPoint {
                let x = scanner.number(), y = scanner.number()
                return rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }
            switch Character(command.uppercased()) {
            case "M":
                current = pt(); start = current; path.move(to: current); lastControl = nil
                command = rel ? "l" : "L" // further pairs are line-tos
            case "L": current = pt(); path.addLine(to: current); lastControl = nil
            case "H": let x = scanner.number(); current.x = rel ? current.x + x : x; path.addLine(to: current); lastControl = nil
            case "V": let y = scanner.number(); current.y = rel ? current.y + y : y; path.addLine(to: current); lastControl = nil
            case "C":
                let c1 = pt(), c2 = pt(), end = pt()
                path.addCurve(to: end, control1: c1, control2: c2); current = end; lastControl = c2
            case "S":
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = pt(), end = pt()
                path.addCurve(to: end, control1: c1, control2: c2); current = end; lastControl = c2
            case "Z": path.closeSubpath(); current = start; lastControl = nil
            default: return path
            }
        }
        return path
    }

    private enum Token { case command(Character), number(CGFloat) }

    private final class Tokens {
        private var tokens: [Token] = []
        private var index = 0

        init(_ d: String) {
            let regex = try! NSRegularExpression(pattern: #"[MmLlHhVvCcSsZz]|-?(?:\d+\.?\d*|\.\d+)"#)
            for m in regex.matches(in: d, range: NSRange(d.startIndex..., in: d)) {
                let s = String(d[Range(m.range, in: d)!])
                if let c = s.first, c.isLetter { tokens.append(.command(c)) } else { tokens.append(.number(CGFloat(Double(s)!))) }
            }
        }

        func next() -> Token? {
            guard index < tokens.count else { return nil }
            defer { index += 1 }
            return tokens[index]
        }

        func pushBack(_: Token) { index -= 1 }

        func number() -> CGFloat {
            if case let .number(n)? = next() { return n }
            return 0
        }
    }
}

/// Scales a path drawn in a fixed view box into the shape's rect.
private func fitted(_ path: Path, box: CGSize, in rect: CGRect) -> Path {
    let scale = min(rect.width / box.width, rect.height / box.height)
    let dx = rect.midX - box.width * scale / 2, dy = rect.midY - box.height * scale / 2
    return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy))
}

/// Botanical line drawing behind the sign-in brand (prototype ART.botanical, 393×210).
struct BotanicalArt: View {
    private static let box = CGSize(width: 393, height: 210)
    private static let layers: [(String, Double)] = [
        ("M-10 190 C 80 150, 120 80, 210 60 S 360 70, 410 20", 0.55),
        ("M60 162 c 10 -22 34 -30 52 -24 c -8 20 -30 32 -52 24z M128 110 c 18 -16 42 -14 56 -2 c -16 14 -40 16 -56 2z " +
            "M196 66 c 6 -24 28 -38 48 -36 c -4 22 -26 38 -48 36z M262 58 c 20 -10 42 -2 52 12 c -20 8 -42 2 -52 -12z " +
            "M330 44 c 8 -20 30 -28 48 -22 c -8 18 -30 28 -48 22z", 0.7),
        ("M40 205 C 110 175, 150 140, 170 100", 0.35),
    ]

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                ForEach(Self.layers.indices, id: \.self) { i in
                    fitted(SVGPath.path(Self.layers[i].0), box: Self.box, in: rect)
                        .stroke(Color.DS.accentGold.opacity(Self.layers[i].1), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
                fitted(Path(ellipseIn: CGRect(x: 211, y: 55, width: 6, height: 6)).union(Path(ellipseIn: CGRect(x: 297.5, y: 49.5, width: 5, height: 5))), box: Self.box, in: rect)
                    .stroke(Color.DS.accentGold.opacity(0.6), lineWidth: 1.2)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension Path {
    func union(_ other: Path) -> Path {
        var p = self
        p.addPath(other)
        return p
    }
}

/// Envelope mark for the "check your e-mail" screens (prototype ART.emptyGuests, 180×140).
struct EnvelopeArt: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: 40, y: 22, width: 100, height: 80), cornerRadius: 10)
        for d in [
            "M40 34 L90 70 L140 34",
            "M20 118 C 50 100, 70 128, 100 112 S 150 104, 166 118",
            "M150 18 l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z",
            "M28 44 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z",
        ] { p.addPath(SVGPath.path(d)) }
        return fitted(p, box: CGSize(width: 180, height: 140), in: rect)
    }
}
