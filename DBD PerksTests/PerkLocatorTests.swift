//
//  PerkLocatorTests.swift
//  DBD PerksTests
//

import XCTest
import UIKit
@testable import DBD_Perks

/// "Recognises" solid coloured squares: the score of a perk is the share of the crop that has its colour.
private struct ColorScorer: SlotScoring {
    let palette: [String: UIColor]
    private static let grid = 8

    func labelScores(for crop: UIImage) throws -> [String: Double] {
        let pixels = Self.rgbaPixels(of: crop, size: Self.grid)
        var counts: [String: Int] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) {
            for (id, color) in palette where Self.matches(pixels[index], pixels[index + 1], pixels[index + 2], color) {
                counts[id, default: 0] += 1
            }
        }
        let total = Double(Self.grid * Self.grid)
        var scores = counts.mapValues { Double($0) / total }
        scores[ModelLabel.background] = 1 - scores.values.reduce(0, +)
        return scores
    }

    private static func matches(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return abs(Double(r) - Double(red * 255)) < 40 && abs(Double(g) - Double(green * 255)) < 40 && abs(Double(b) - Double(blue * 255)) < 40
    }

    private static func rgbaPixels(of image: UIImage, size: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let context = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
        return pixels
    }
}

private struct FixedProposer: RegionProposing {
    let rects: [CGRect]
    func proposals(in image: CGImage) -> [CGRect] { rects }
}

final class PerkLocatorTests: XCTestCase {

    private let palette: [String: UIColor] = [
        "red": .red, "green": .green, "blue": .blue, "yellow": .yellow, "magenta": .magenta, "cyan": .cyan
    ]
    private let canvas = CGSize(width: 400, height: 300)
    private let square: CGFloat = 40

    private func repository() -> BundledPerkRepository {
        let perks = palette.keys.map { id in
            PerkInfo(id: id, name: id, role: .survivor, owner: "", iconUrl: URL(string: "https://x.test/\(id).png")!,
                     description: "d", flavor: "", descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/\(id)")!)
        }
        return BundledPerkRepository(perks: perks)
    }

    /// Black photo with a coloured square centred at each point.
    private func photo(_ squares: [(String, CGPoint)]) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            for (id, centre) in squares {
                palette[id]!.setFill()
                context.fill(CGRect(x: centre.x - square / 2, y: centre.y - square / 2, width: square, height: square))
            }
        }
    }

    private func frame(around centre: CGPoint, side: CGFloat = 80) -> CGRect {
        CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
    }

    private func locator(proposing rects: [CGRect]) -> PerkLocator {
        PerkLocator(scorer: ColorScorer(palette: palette), repository: repository(), proposers: [FixedProposer(rects: rects)])
    }

    private let centres: [(String, CGPoint)] = [
        ("red", CGPoint(x: 100, y: 80)), ("green", CGPoint(x: 220, y: 80)),
        ("blue", CGPoint(x: 100, y: 200)), ("yellow", CGPoint(x: 220, y: 200))
    ]

    func testFindsAllFourPerksInReadingOrder() {
        let shuffled = [centres[3], centres[0], centres[2], centres[1]]
        let found = locator(proposing: shuffled.map { frame(around: $0.1) }).locate(in: photo(centres))

        XCTAssertEqual(found.map { $0.candidates.first?.perkID }, ["red", "green", "blue", "yellow"])
        XCTAssertEqual(found[0].region.midX, 100 / canvas.width, accuracy: 0.03)
        XCTAssertEqual(found[3].region.midY, 200 / canvas.height, accuracy: 0.03)
    }

    func testRejectsBackgroundProposals() {
        let empty = [CGPoint(x: 330, y: 250), CGPoint(x: 330, y: 40)]
        let found = locator(proposing: (centres.map(\.1) + empty).map { frame(around: $0) }).locate(in: photo(centres))

        XCTAssertEqual(found.count, 4)
    }

    func testOverlappingProposalsOfTheSamePerkCollapseToOne() {
        let near = [CGPoint(x: 100, y: 80), CGPoint(x: 108, y: 84), CGPoint(x: 94, y: 78)]
        let found = locator(proposing: near.map { frame(around: $0) }).locate(in: photo([centres[0]]))

        XCTAssertEqual(found.count, 1)
    }

    func testKeepsOnlyTheFourStrongestPerks() {
        let six = centres + [("magenta", CGPoint(x: 340, y: 80)), ("cyan", CGPoint(x: 340, y: 200))]
        let found = locator(proposing: six.map { frame(around: $0.1) }).locate(in: photo(six))

        XCTAssertEqual(found.count, PerkSlotLayout.maxSlots)
    }

    func testRefinementMovesAnOffCentreFrameOntoTheIcon() throws {
        let target = CGPoint(x: 200, y: 150)
        let offCentre = frame(around: CGPoint(x: target.x + 6, y: target.y - 5), side: 80)

        let found = try XCTUnwrap(locator(proposing: [offCentre]).locate(in: photo([("blue", target)])).first)

        XCTAssertEqual(found.region.midX * canvas.width, target.x, accuracy: 6)
        XCTAssertEqual(found.region.midY * canvas.height, target.y, accuracy: 6)
    }

    func testNothingFoundOnAnEmptyPhoto() {
        XCTAssertTrue(locator(proposing: [frame(around: CGPoint(x: 100, y: 100))]).locate(in: photo([])).isEmpty)
        XCTAssertTrue(locator(proposing: []).locate(in: photo(centres)).isEmpty)
    }

    func testGridProposerCoversTheImageWithSquareWindows() throws {
        let image = try XCTUnwrap(photo([]).cgImage)

        let windows = GridProposer().proposals(in: image)

        XCTAssertGreaterThan(windows.count, 50)
        XCTAssertTrue(windows.allSatisfy { $0.width == $0.height })
        XCTAssertTrue(windows.allSatisfy { CGRect(x: 0, y: 0, width: image.width, height: image.height).contains($0) })
    }

    func testPhotoIsDownscaledForAnalysisButKeepsAspect() {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000), format: format).image { _ in }
        let scaled = big.scaled(toMaxSide: 1024)

        XCTAssertEqual(max(scaled.size.width, scaled.size.height) * scaled.scale, 1024, accuracy: 1)
        XCTAssertEqual(scaled.size.width / scaled.size.height, 1.5, accuracy: 0.01)
        XCTAssertEqual(big.scaled(toMaxSide: 5000).size, big.size)
    }
}
