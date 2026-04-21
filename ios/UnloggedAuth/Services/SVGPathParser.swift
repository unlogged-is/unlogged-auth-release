import CoreGraphics
import Foundation

/// Parses SVG path data (the `d` attribute) into a `CGPath`.
/// Supports all standard SVG path commands: M, L, H, V, C, S, Q, T, A, Z.
enum SVGPathParser {

    /// Parse an SVG path `d` attribute string into a CGPath.
    static func parse(_ pathData: String) -> CGPath? {
        let path = CGMutablePath()
        var scanner = PathScanner(pathData)

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var previousCommand: Character = "\0"

        while true {
            scanner.skipSeparators()
            guard !scanner.isAtEnd else { break }

            let command: Character
            if let c = scanner.peekCommand() {
                command = c
                scanner.advance()
            } else {
                guard previousCommand != "\0" else { break }
                if previousCommand == "M" { command = "L" }
                else if previousCommand == "m" { command = "l" }
                else if previousCommand == "Z" || previousCommand == "z" { break }
                else { command = previousCommand }
            }

            let isRelative = command.isLowercase
            let cmd = Character(command.uppercased())

            if cmd == "Z" {
                path.closeSubpath()
                current = subpathStart
                lastControl = nil
                previousCommand = command
                continue
            }

            var parsed = false

            while true {
                scanner.skipSeparators()
                let savedPos = scanner.position
                var success = false

                switch cmd {
                case "M":
                    if let p = scanner.scanPoint(relative: isRelative, to: current) {
                        if parsed {
                            path.addLine(to: p)
                        } else {
                            path.move(to: p)
                            subpathStart = p
                        }
                        current = p
                        lastControl = nil
                        success = true
                    }

                case "L":
                    if let p = scanner.scanPoint(relative: isRelative, to: current) {
                        path.addLine(to: p)
                        current = p
                        lastControl = nil
                        success = true
                    }

                case "H":
                    if let v = scanner.scanNumber() {
                        current.x = isRelative ? current.x + v : v
                        path.addLine(to: current)
                        lastControl = nil
                        success = true
                    }

                case "V":
                    if let v = scanner.scanNumber() {
                        current.y = isRelative ? current.y + v : v
                        path.addLine(to: current)
                        lastControl = nil
                        success = true
                    }

                case "C":
                    if let c1 = scanner.scanPoint(relative: isRelative, to: current),
                       let c2 = scanner.scanPoint(relative: isRelative, to: current),
                       let end = scanner.scanPoint(relative: isRelative, to: current) {
                        path.addCurve(to: end, control1: c1, control2: c2)
                        lastControl = c2
                        current = end
                        success = true
                    }

                case "S":
                    if let c2 = scanner.scanPoint(relative: isRelative, to: current),
                       let end = scanner.scanPoint(relative: isRelative, to: current) {
                        let c1 = Self.reflect(lastControl, over: current)
                        path.addCurve(to: end, control1: c1, control2: c2)
                        lastControl = c2
                        current = end
                        success = true
                    }

                case "Q":
                    if let c = scanner.scanPoint(relative: isRelative, to: current),
                       let end = scanner.scanPoint(relative: isRelative, to: current) {
                        path.addQuadCurve(to: end, control: c)
                        lastControl = c
                        current = end
                        success = true
                    }

                case "T":
                    if let end = scanner.scanPoint(relative: isRelative, to: current) {
                        let c = Self.reflect(lastControl, over: current)
                        path.addQuadCurve(to: end, control: c)
                        lastControl = c
                        current = end
                        success = true
                    }

                case "A":
                    if let params = scanner.scanArcParameters(relative: isRelative, to: current) {
                        Self.addArc(to: path, from: current, params: params)
                        current = params.endPoint
                        lastControl = nil
                        success = true
                    }

                default:
                    break
                }

                if !success {
                    scanner.position = savedPos
                    break
                }
                parsed = true
            }

            if !parsed { break }
            previousCommand = command
        }

        return path.isEmpty ? nil : path
    }

    // MARK: - Helpers

    private static func reflect(_ point: CGPoint?, over anchor: CGPoint) -> CGPoint {
        guard let p = point else { return anchor }
        return CGPoint(x: 2 * anchor.x - p.x, y: 2 * anchor.y - p.y)
    }

    // MARK: - Arc conversion (SVG endpoint parameterization → cubic bezier curves)

    struct ArcParameters {
        let rx: CGFloat, ry: CGFloat
        let rotation: CGFloat // in radians
        let largeArc: Bool, sweep: Bool
        let endPoint: CGPoint
    }

    private static func addArc(to path: CGMutablePath, from start: CGPoint, params: ArcParameters) {
        var rx = abs(params.rx), ry = abs(params.ry)
        let phi = params.rotation
        let end = params.endPoint

        guard rx > 0, ry > 0, start != end else {
            path.addLine(to: end)
            return
        }

        let cosPhi = cos(phi), sinPhi = sin(phi)

        // F.6.5.1: Compute (x1', y1')
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // F.6.6: Correct out-of-range radii
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s
            ry *= s
        }

        let rxSq = rx * rx, rySq = ry * ry
        let x1pSq = x1p * x1p, y1pSq = y1p * y1p

        // F.6.5.2-3: Compute center point
        let num = max(0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
        let den = rxSq * y1pSq + rySq * x1pSq
        let coeff = (den > 0 ? sqrt(num / den) : 0) * (params.largeArc == params.sweep ? -1 : 1)

        let cxp = coeff * rx * y1p / ry
        let cyp = coeff * -ry * x1p / rx

        let mx = (start.x + end.x) / 2
        let my = (start.y + end.y) / 2
        let cx = cosPhi * cxp - sinPhi * cyp + mx
        let cy = sinPhi * cxp + cosPhi * cyp + my

        // F.6.5.5-6: Compute angles
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry

        let theta1 = vectorAngle(1, 0, ux, uy)
        var dtheta = vectorAngle(ux, uy, vx, vy)

        if !params.sweep && dtheta > 0 { dtheta -= 2 * .pi }
        if params.sweep && dtheta < 0 { dtheta += 2 * .pi }

        // Split into bezier segments (max 90° each)
        let segmentCount = max(1, Int(ceil(abs(dtheta) / (.pi / 2))))
        let segmentAngle = dtheta / CGFloat(segmentCount)

        for i in 0..<segmentCount {
            let t1 = theta1 + CGFloat(i) * segmentAngle
            arcSegmentToBezier(path: path, cx: cx, cy: cy, rx: rx, ry: ry,
                               cosPhi: cosPhi, sinPhi: sinPhi,
                               theta: t1, dtheta: segmentAngle)
        }
    }

    private static func vectorAngle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
        guard len > 0 else { return 0 }
        var angle = acos(max(-1, min(1, dot / len)))
        if ux * vy - uy * vx < 0 { angle = -angle }
        return angle
    }

    private static func arcSegmentToBezier(path: CGMutablePath, cx: CGFloat, cy: CGFloat,
                                            rx: CGFloat, ry: CGFloat,
                                            cosPhi: CGFloat, sinPhi: CGFloat,
                                            theta: CGFloat, dtheta: CGFloat) {
        let t = tan(dtheta / 2)
        let alpha = sin(dtheta) * (sqrt(4 + 3 * t * t) - 1) / 3

        let cosT1 = cos(theta), sinT1 = sin(theta)
        let cosT2 = cos(theta + dtheta), sinT2 = sin(theta + dtheta)

        func transform(_ ex: CGFloat, _ ey: CGFloat) -> CGPoint {
            CGPoint(x: cosPhi * rx * ex - sinPhi * ry * ey + cx,
                    y: sinPhi * rx * ex + cosPhi * ry * ey + cy)
        }

        let p1 = transform(cosT1, sinT1)
        let p2 = transform(cosT2, sinT2)

        let d1x = -sinT1, d1y = cosT1
        let d2x = -sinT2, d2y = cosT2

        let cp1 = CGPoint(
            x: p1.x + alpha * (cosPhi * rx * d1x - sinPhi * ry * d1y),
            y: p1.y + alpha * (sinPhi * rx * d1x + cosPhi * ry * d1y)
        )
        let cp2 = CGPoint(
            x: p2.x - alpha * (cosPhi * rx * d2x - sinPhi * ry * d2y),
            y: p2.y - alpha * (sinPhi * rx * d2x + cosPhi * ry * d2y)
        )

        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
}

// MARK: - Path Scanner

private struct PathScanner {
    private let characters: [Character]
    var position: Int

    var isAtEnd: Bool { position >= characters.count }

    init(_ string: String) {
        characters = Array(string)
        position = 0
    }

    mutating func skipSeparators() {
        while !isAtEnd {
            let c = characters[position]
            guard c == " " || c == "\t" || c == "\n" || c == "\r" || c == "," else { break }
            position += 1
        }
    }

    func peekCommand() -> Character? {
        guard !isAtEnd else { return nil }
        let c = characters[position]
        if c.isLetter && c != "e" && c != "E" { return c }
        return nil
    }

    mutating func advance() {
        if !isAtEnd { position += 1 }
    }

    mutating func scanNumber() -> CGFloat? {
        skipSeparators()
        guard !isAtEnd else { return nil }

        let start = position

        // Optional sign
        if !isAtEnd && (characters[position] == "-" || characters[position] == "+") {
            position += 1
        }

        var hasDigits = false

        // Integer part
        while !isAtEnd && characters[position].isNumber {
            position += 1
            hasDigits = true
        }

        // Fractional part
        if !isAtEnd && characters[position] == "." {
            position += 1
            while !isAtEnd && characters[position].isNumber {
                position += 1
                hasDigits = true
            }
        }

        guard hasDigits else {
            position = start
            return nil
        }

        // Exponent
        if !isAtEnd && (characters[position] == "e" || characters[position] == "E") {
            position += 1
            if !isAtEnd && (characters[position] == "-" || characters[position] == "+") {
                position += 1
            }
            while !isAtEnd && characters[position].isNumber {
                position += 1
            }
        }

        let str = String(characters[start..<position])
        guard let value = Double(str) else {
            position = start
            return nil
        }
        return CGFloat(value)
    }

    mutating func scanFlag() -> Bool? {
        skipSeparators()
        guard !isAtEnd else { return nil }
        if characters[position] == "0" { position += 1; return false }
        if characters[position] == "1" { position += 1; return true }
        return nil
    }

    mutating func scanPoint(relative: Bool, to base: CGPoint) -> CGPoint? {
        guard let x = scanNumber(), let y = scanNumber() else { return nil }
        if relative {
            return CGPoint(x: base.x + x, y: base.y + y)
        }
        return CGPoint(x: x, y: y)
    }

    mutating func scanArcParameters(relative: Bool, to base: CGPoint) -> SVGPathParser.ArcParameters? {
        guard let rx = scanNumber(),
              let ry = scanNumber(),
              let rotation = scanNumber(),
              let largeArc = scanFlag(),
              let sweep = scanFlag(),
              let endPoint = scanPoint(relative: relative, to: base) else { return nil }

        return SVGPathParser.ArcParameters(
            rx: rx, ry: ry,
            rotation: rotation * .pi / 180,
            largeArc: largeArc, sweep: sweep,
            endPoint: endPoint
        )
    }
}
