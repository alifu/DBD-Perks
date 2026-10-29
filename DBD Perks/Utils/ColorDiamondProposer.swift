//
//  ColorDiamondProposer.swift
//  DBD Perks
//

import CoreGraphics

/// Finds perk frames by colour: every perk sits on a saturated rarity-coloured diamond, while the HUD's item and
/// add-on icons are saturated squares and the background is grey or blurred. Pixels are masked by saturation,
/// grouped into connected blobs, and kept only when the blob is a diamond (corners of its bounding box empty,
/// edge midpoints filled). Time and space O(P) for P analysed pixels, since each pixel is visited a constant
/// number of times.
struct ColorDiamondProposer: RegionProposing {
    static let analysisWidth = 256
    static let minimumSaturation: Double = 0.3
    static let minimumBrightness: Double = 0.2
    static let widthFractionRange: ClosedRange<Double> = 0.05...0.4
    static let aspectRatioRange: ClosedRange<Double> = 0.75...1.33
    /// Share of a patch (a tenth of the box side) that may be coloured at a corner of a diamond's bounding box.
    static let maximumCornerFill: Double = 0.2
    static let minimumTipFill: Double = 0.4
    static let patchFraction: Double = 0.1
    static let maximumBlobs = 12
    /// White art often touches a frame's edge and splits its colour; dilating by these many pixels rejoins it.
    static let warmHueUpperBound: Double = 75
    static let warmHueLowerBound: Double = 345
    static let bridgeRadii = [0, 2]

    func proposals(in image: CGImage) -> [CGRect] {
        guard let raw = Self.maskGrid(of: image) else { return [] }
        let scale = Double(image.width) / Double(raw.width)
        // Without bridging, close-together frames stay apart; with it, frames split by white art rejoin.
        let found = Self.bridgeRadii.flatMap { radius -> [CGRect] in
            let grid = radius == 0 ? raw : Self.dilated(raw, radius: radius)
            let inset = Double(radius)
            return Self.blobs(in: grid)
                .filter { Self.isDiamond($0, in: grid) }
                .map { CGRect(x: (Double($0.minX) + inset) * scale, y: (Double($0.minY) + inset) * scale,
                              width: (Double($0.width) - 2 * inset) * scale, height: (Double($0.height) - 2 * inset) * scale) }
        }
        return Array(VisionContourProposer.distinct(found.sorted { $0.width * $0.height > $1.width * $1.height }).prefix(Self.maximumBlobs))
    }

    struct Grid {
        let width: Int
        let height: Int
        let mask: [Bool]
    }

    struct Box {
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int
        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }
    }

    static func maskGrid(of image: CGImage) -> Grid? {
        let width = analysisWidth
        let height = max(Int((Double(image.height) / Double(image.width) * Double(width)).rounded()), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let mask = (0..<(width * height)).map { index -> Bool in
            isRarityColour(red: pixels[index * 4], green: pixels[index * 4 + 1], blue: pixels[index * 4 + 2])
        }
        return Grid(width: width, height: height, mask: mask)
    }

    /// Separable box dilation, O(P) for any radius.
    static func dilated(_ grid: Grid, radius: Int) -> Grid {
        func pass(_ source: [Bool], horizontal: Bool) -> [Bool] {
            var result = source
            for y in 0..<grid.height {
                for x in 0..<grid.width where source[y * grid.width + x] {
                    for offset in -radius...radius {
                        let nx = horizontal ? x + offset : x
                        let ny = horizontal ? y : y + offset
                        if nx >= 0, ny >= 0, nx < grid.width, ny < grid.height { result[ny * grid.width + nx] = true }
                    }
                }
            }
            return result
        }
        return Grid(width: grid.width, height: grid.height, mask: pass(pass(grid.mask, horizontal: true), horizontal: false))
    }

    /// Saturated and not warm: blurred fire, wood and skin tones sit at red-orange-yellow hues and would glue
    /// frames to the background, while the purple, blue and green rarity colours stay outside that band.
    static func isRarityColour(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
        let r = Double(red) / 255, g = Double(green) / 255, b = Double(blue) / 255
        let high = max(r, g, b)
        let delta = high - min(r, g, b)
        guard high >= minimumBrightness, delta / high >= minimumSaturation else { return false }
        let sector: Double
        switch high {
        case r: sector = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        case g: sector = (b - r) / delta + 2
        default: sector = (r - g) / delta + 4
        }
        let hue = (sector * 60 + 360).truncatingRemainder(dividingBy: 360)
        return !(hue <= warmHueUpperBound || hue >= warmHueLowerBound)
    }

    /// Bounding boxes of 4-connected masked blobs whose width is plausible for a perk frame.
    static func blobs(in grid: Grid) -> [Box] {
        var seen = [Bool](repeating: false, count: grid.mask.count)
        var boxes: [Box] = []
        for start in grid.mask.indices where grid.mask[start] && !seen[start] {
            var stack = [start]
            seen[start] = true
            var box = Box(minX: start % grid.width, minY: start / grid.width, maxX: start % grid.width, maxY: start / grid.width)
            while let index = stack.popLast() {
                let x = index % grid.width
                let y = index / grid.width
                box = Box(minX: min(box.minX, x), minY: min(box.minY, y), maxX: max(box.maxX, x), maxY: max(box.maxY, y))
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, ny >= 0, nx < grid.width, ny < grid.height else { continue }
                    let neighbour = ny * grid.width + nx
                    if grid.mask[neighbour] && !seen[neighbour] {
                        seen[neighbour] = true
                        stack.append(neighbour)
                    }
                }
            }
            let widthFraction = Double(box.width) / Double(grid.width)
            let aspect = Double(box.width) / Double(box.height)
            if widthFractionRange.contains(widthFraction) && aspectRatioRange.contains(aspect) { boxes.append(box) }
        }
        return boxes
    }

    static func isDiamond(_ box: Box, in grid: Grid) -> Bool {
        let patch = max(Int((Double(min(box.width, box.height)) * patchFraction).rounded()), 1)
        let corners = [(box.minX, box.minY), (box.maxX - patch + 1, box.minY),
                       (box.minX, box.maxY - patch + 1), (box.maxX - patch + 1, box.maxY - patch + 1)]
        let midX = (box.minX + box.maxX - patch + 1) / 2
        let midY = (box.minY + box.maxY - patch + 1) / 2
        let tips = [(midX, box.minY), (midX, box.maxY - patch + 1), (box.minX, midY), (box.maxX - patch + 1, midY)]
        let cornersEmpty = corners.allSatisfy { fill(of: grid, x: $0.0, y: $0.1, side: patch) <= maximumCornerFill }
        let tipsFilled = tips.filter { fill(of: grid, x: $0.0, y: $0.1, side: patch) >= minimumTipFill }.count >= 3
        return cornersEmpty && tipsFilled
    }

    private static func fill(of grid: Grid, x: Int, y: Int, side: Int) -> Double {
        var filled = 0
        for row in y..<(y + side) {
            for column in x..<(x + side) where column >= 0 && row >= 0 && column < grid.width && row < grid.height {
                if grid.mask[row * grid.width + column] { filled += 1 }
            }
        }
        return Double(filled) / Double(side * side)
    }
}
