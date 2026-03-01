import SwiftUI
@preconcurrency import CoreGraphics
import Foundation

struct TrackPathSampler {
    let path: CGPath
    let points: [CGPoint]
    let lengths: [CGFloat]
    let totalLength: CGFloat
    let viewBox: CGSize

    init?(svgName: String, viewBox: CGSize) {
        self.viewBox = viewBox
        guard let svgPath = SVGPathLoader.loadPath(named: svgName) else {
            return nil
        }
        guard let cgPath = SVGPathParser(pathString: svgPath).makePath() else {
            return nil
        }
        self.path = cgPath
        let sampled = TrackPathSampler.samplePoints(from: cgPath, segmentsPerCurve: 24)
        guard sampled.count > 1 else { return nil }
        points = sampled
        var lengths: [CGFloat] = [0]
        var total: CGFloat = 0
        for idx in 1..<sampled.count {
            let a = sampled[idx - 1]
            let b = sampled[idx]
            let segment = hypot(b.x - a.x, b.y - a.y)
            total += segment
            lengths.append(total)
        }
        self.lengths = lengths
        self.totalLength = total
    }

    func position(for progress: Double, in rect: CGRect, laneOffset: CGFloat) -> CGPoint {
        let fraction = CGFloat(progress.truncatingRemainder(dividingBy: 1.0))
        let (point, angle) = pointAndAngle(at: fraction)
        let mapped = map(point: point, in: rect)
        let normal = CGPoint(x: -sin(angle), y: cos(angle))
        return CGPoint(x: mapped.x + normal.x * laneOffset, y: mapped.y + normal.y * laneOffset)
    }

    func map(point: CGPoint, in rect: CGRect) -> CGPoint {
        let padding: CGFloat = 28
        let availableWidth = rect.width - padding * 2
        let availableHeight = rect.height - padding * 2
        let scale = min(availableWidth / viewBox.width, availableHeight / viewBox.height)
        let scaledWidth = viewBox.width * scale
        let scaledHeight = viewBox.height * scale
        let origin = CGPoint(x: rect.midX - scaledWidth / 2, y: rect.midY - scaledHeight / 2)
        return CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
    }

    func pointAndAngle(at fraction: CGFloat) -> (CGPoint, CGFloat) {
        guard !points.isEmpty else { return (.zero, 0) }
        let target = fraction * totalLength
        var index = lengths.firstIndex(where: { $0 >= target }) ?? (lengths.count - 1)
        if index == 0 { index = 1 }
        let prev = points[index - 1]
        let next = points[index]
        let segmentLength = max(lengths[index] - lengths[index - 1], 0.0001)
        let t = (target - lengths[index - 1]) / segmentLength
        let x = prev.x + (next.x - prev.x) * t
        let y = prev.y + (next.y - prev.y) * t
        let angle = atan2(next.y - prev.y, next.x - prev.x)
        return (CGPoint(x: x, y: y), angle)
    }

    private static func samplePoints(from path: CGPath, segmentsPerCurve: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        var current: CGPoint = .zero
        var start: CGPoint = .zero

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                current = element.points[0]
                start = current
                points.append(current)
            case .addLineToPoint:
                current = element.points[0]
                points.append(current)
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let end = element.points[2]
                let samples = max(8, segmentsPerCurve)
                for step in 1...samples {
                    let t = CGFloat(step) / CGFloat(samples)
                    let point = cubicBezier(t: t, p0: current, p1: control1, p2: control2, p3: end)
                    points.append(point)
                }
                current = end
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let end = element.points[1]
                let samples = max(8, segmentsPerCurve)
                for step in 1...samples {
                    let t = CGFloat(step) / CGFloat(samples)
                    let point = quadBezier(t: t, p0: current, p1: control, p2: end)
                    points.append(point)
                }
                current = end
            case .closeSubpath:
                points.append(start)
                current = start
            @unknown default:
                break
            }
        }

        return points
    }

    private static func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let oneMinusT = 1 - t
        let a = oneMinusT * oneMinusT * oneMinusT
        let b = 3 * oneMinusT * oneMinusT * t
        let c = 3 * oneMinusT * t * t
        let d = t * t * t
        let x = a * p0.x + b * p1.x + c * p2.x + d * p3.x
        let y = a * p0.y + b * p1.y + c * p2.y + d * p3.y
        return CGPoint(x: x, y: y)
    }

    private static func quadBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let oneMinusT = 1 - t
        let a = oneMinusT * oneMinusT
        let b = 2 * oneMinusT * t
        let c = t * t
        let x = a * p0.x + b * p1.x + c * p2.x
        let y = a * p0.y + b * p1.y + c * p2.y
        return CGPoint(x: x, y: y)
    }
}

struct TrackShape: Shape {
    let path: CGPath
    let viewBox: CGSize

    func path(in rect: CGRect) -> Path {
        let padding: CGFloat = 28
        let availableWidth = rect.width - padding * 2
        let availableHeight = rect.height - padding * 2
        let scale = min(availableWidth / viewBox.width, availableHeight / viewBox.height)
        let scaledWidth = viewBox.width * scale
        let scaledHeight = viewBox.height * scale
        let origin = CGPoint(x: rect.midX - scaledWidth / 2, y: rect.midY - scaledHeight / 2)
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
        if let transformed = path.copy(using: &transform) {
            return Path(transformed)
        }
        return Path()
    }
}

enum SVGPathLoader {
    static func loadPath(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "assets")
                ?? Bundle.main.url(forResource: name, withExtension: "svg")
        else { return nil }
        guard let svg = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        if let classRange = svg.range(of: "class=\"st0\"") {
            let tail = svg[classRange.upperBound...]
            if let dRange = tail.range(of: "d=\"") {
                let rest = tail[dRange.upperBound...]
                if let end = rest.firstIndex(of: "\"") {
                    return String(rest[..<end])
                }
            }
        }
        if let dRange = svg.range(of: "d=\"") {
            let rest = svg[dRange.upperBound...]
            if let end = rest.firstIndex(of: "\"") {
                return String(rest[..<end])
            }
        }
        return nil
    }
}

struct SVGVectorAsset {
    let path: CGPath
    let viewBox: CGRect
}

enum SVGVectorLoader {
    static func loadCompositeAsset(named name: String) -> SVGVectorAsset? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "assets")
                ?? Bundle.main.url(forResource: name, withExtension: "svg")
        else { return nil }
        guard let svg = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let combined = CGMutablePath()
        var addedAnyShape = false

        // Paths
        for pathData in captureGroup(
            pattern: #"<path\b[^>]*\bd\s*=\s*"([^"]+)"[^>]*>"#,
            in: svg
        ) {
            if let parsed = SVGPathParser(pathString: pathData).makePath() {
                combined.addPath(parsed)
                addedAnyShape = true
            }
        }

        // Polygons
        for pointsData in captureGroup(
            pattern: #"<polygon\b[^>]*\bpoints\s*=\s*"([^"]+)"[^>]*>"#,
            in: svg
        ) {
            if let polygonPath = polygonPath(pointsString: pointsData) {
                combined.addPath(polygonPath)
                addedAnyShape = true
            }
        }

        // Rectangles
        for tag in capture(
            pattern: #"<rect\b[^>]*/?>"#,
            in: svg
        ) {
            let x = Double(attribute("x", in: tag) ?? "0") ?? 0
            let y = Double(attribute("y", in: tag) ?? "0") ?? 0
            let width = Double(attribute("width", in: tag) ?? "0") ?? 0
            let height = Double(attribute("height", in: tag) ?? "0") ?? 0
            guard width > 0, height > 0 else { continue }
            combined.addRect(CGRect(x: x, y: y, width: width, height: height))
            addedAnyShape = true
        }

        guard addedAnyShape else { return nil }

        let viewBox = parseViewBox(from: svg) ?? combined.boundingBoxOfPath
        return SVGVectorAsset(path: combined, viewBox: viewBox)
    }

    private static func parseViewBox(from svg: String) -> CGRect? {
        guard let value = captureFirstGroup(
            pattern: #"viewBox\s*=\s*"([^"]+)""#,
            in: svg
        ) else {
            return nil
        }
        let numbers = value
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { Double($0) }
        guard numbers.count >= 4 else { return nil }
        return CGRect(
            x: numbers[0],
            y: numbers[1],
            width: numbers[2],
            height: numbers[3]
        )
    }

    private static func polygonPath(pointsString: String) -> CGPath? {
        let values = pointsString
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { Double($0) }
        guard values.count >= 4, values.count.isMultiple(of: 2) else { return nil }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: values[0], y: values[1]))
        var index = 2
        while index + 1 < values.count {
            path.addLine(to: CGPoint(x: values[index], y: values[index + 1]))
            index += 2
        }
        path.closeSubpath()
        return path.copy()
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        captureFirstGroup(
            pattern: #"\#(name)\s*=\s*"([^"]+)""#,
            in: tag
        )
    }

    private static func captureGroup(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text)
            else { return nil }
            return String(text[range])
        }
    }

    private static func capture(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func captureFirstGroup(pattern: String, in text: String) -> String? {
        captureGroup(pattern: pattern, in: text).first
    }
}

final class SVGPathParser {
    private let pathString: String
    private var currentPoint: CGPoint = .zero
    private var startPoint: CGPoint = .zero
    private let path = CGMutablePath()

    init(pathString: String) {
        self.pathString = pathString
    }

    func makePath() -> CGPath? {
        let scanner = Scanner(string: pathString)
        scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))

        while !scanner.isAtEnd {
            if let command = scanCommand(from: scanner) {
                let numbers = scanNumbers(for: scanner)
                apply(command: command, numbers: numbers)
            } else {
                scanner.currentIndex = pathString.index(after: scanner.currentIndex)
            }
        }

        return path.copy()
    }

    private func scanCommand(from scanner: Scanner) -> Character? {
        _ = scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        guard !scanner.isAtEnd else { return nil }
        let current = scanner.string[scanner.currentIndex]
        if current.isLetter {
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
            return current
        }
        return nil
    }

    private func scanNumbers(for scanner: Scanner) -> [Double] {
        let start = scanner.currentIndex
        while !scanner.isAtEnd {
            let ch = scanner.string[scanner.currentIndex]
            if ch.isLetter {
                break
            }
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
        }
        let segment = String(scanner.string[start..<scanner.currentIndex])
        let numberScanner = Scanner(string: segment)
        numberScanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        var numbers: [Double] = []
        while let value = numberScanner.scanDouble() {
            numbers.append(value)
        }
        return numbers
    }

    private func apply(command: Character, numbers: [Double]) {
        switch command {
        case "M", "m":
            guard numbers.count >= 2 else { return }
            let point = CGPoint(x: numbers[0], y: numbers[1])
            currentPoint = command == "m" ? CGPoint(x: currentPoint.x + point.x, y: currentPoint.y + point.y) : point
            startPoint = currentPoint
            path.move(to: currentPoint)
            if numbers.count > 2 {
                let remaining = Array(numbers.dropFirst(2))
                applyLineSequence(relative: command == "m", numbers: remaining)
            }
        case "C", "c":
            applyCurveSequence(relative: command == "c", numbers: numbers)
        case "L", "l":
            applyLineSequence(relative: command == "l", numbers: numbers)
        case "H", "h":
            applyHorizontalSequence(relative: command == "h", numbers: numbers)
        case "V", "v":
            applyVerticalSequence(relative: command == "v", numbers: numbers)
        case "Z", "z":
            path.closeSubpath()
            currentPoint = startPoint
        default:
            break
        }
    }

    private func applyLineSequence(relative: Bool, numbers: [Double]) {
        var index = 0
        while index + 1 < numbers.count {
            let point = CGPoint(x: numbers[index], y: numbers[index + 1])
            let target = relative ? CGPoint(x: currentPoint.x + point.x, y: currentPoint.y + point.y) : point
            path.addLine(to: target)
            currentPoint = target
            index += 2
        }
    }

    private func applyCurveSequence(relative: Bool, numbers: [Double]) {
        var index = 0
        while index + 5 < numbers.count {
            let c1 = CGPoint(x: numbers[index], y: numbers[index + 1])
            let c2 = CGPoint(x: numbers[index + 2], y: numbers[index + 3])
            let end = CGPoint(x: numbers[index + 4], y: numbers[index + 5])
            let control1 = relative ? CGPoint(x: currentPoint.x + c1.x, y: currentPoint.y + c1.y) : c1
            let control2 = relative ? CGPoint(x: currentPoint.x + c2.x, y: currentPoint.y + c2.y) : c2
            let target = relative ? CGPoint(x: currentPoint.x + end.x, y: currentPoint.y + end.y) : end
            path.addCurve(to: target, control1: control1, control2: control2)
            currentPoint = target
            index += 6
        }
    }

    private func applyHorizontalSequence(relative: Bool, numbers: [Double]) {
        for xValue in numbers {
            let x = relative ? currentPoint.x + xValue : xValue
            let target = CGPoint(x: x, y: currentPoint.y)
            path.addLine(to: target)
            currentPoint = target
        }
    }

    private func applyVerticalSequence(relative: Bool, numbers: [Double]) {
        for yValue in numbers {
            let y = relative ? currentPoint.y + yValue : yValue
            let target = CGPoint(x: currentPoint.x, y: y)
            path.addLine(to: target)
            currentPoint = target
        }
    }
}

private extension Character {
    var isLetter: Bool {
        unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }
}
