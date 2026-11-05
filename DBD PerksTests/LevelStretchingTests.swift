//
//  LevelStretchingTests.swift
//  DBD PerksTests
//

import XCTest
import UIKit
@testable import DBD_Perks

final class LevelStretchingTests: XCTestCase {

    /// Left half `dark`, right half `light`, both as gray levels 0...1.
    private func halves(dark: CGFloat, light: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            UIColor(white: dark, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 64))
            UIColor(white: light, alpha: 1).setFill()
            context.fill(CGRect(x: 32, y: 0, width: 32, height: 64))
        }
    }

    private func span(of image: UIImage) throws -> Double {
        try XCTUnwrap(LevelStretching.levels(of: try XCTUnwrap(image.cgImage))).span
    }

    func testDimCropGetsFullRange() throws {
        let dim = halves(dark: 0.1, light: 0.5)

        let stretched = try XCTUnwrap(LevelStretching.stretched(dim))

        XCTAssertGreaterThan(try span(of: stretched), 0.9)
        XCTAssertEqual(stretched.size, dim.size)
    }

    func testBrightCropIsLeftAlone() {
        XCTAssertNil(LevelStretching.stretched(halves(dark: 0.05, light: 0.95)))
    }

    func testFlatCropIsLeftAlone() {
        XCTAssertNil(LevelStretching.stretched(halves(dark: 0.4, light: 0.4)))
    }

    func testAdaptiveScorerUsesStretchedCropWhenItIsMoreConfident() throws {
        struct BrightnessScorer: SlotScoring {
            func labelScores(for crop: UIImage) throws -> [String: Double] {
                let high = try XCTUnwrap(LevelStretching.levels(of: try XCTUnwrap(crop.cgImage))).high
                return ["a": high, ModelLabel.background: 1 - high]
            }
        }

        let scores = try LevelAdaptiveScorer(base: BrightnessScorer()).labelScores(for: halves(dark: 0.1, light: 0.5))

        XCTAssertGreaterThan(try XCTUnwrap(scores["a"]), 0.9, "a dim icon is scored as if it were bright")
    }

    func testAdaptiveScorerKeepsOriginalScoresForBrightCrop() throws {
        struct Fixed: SlotScoring { func labelScores(for crop: UIImage) throws -> [String: Double] { ["a": 0.7, "b": 0.3] } }

        let scores = try LevelAdaptiveScorer(base: Fixed()).labelScores(for: halves(dark: 0.05, light: 0.95))

        XCTAssertEqual(scores, ["a": 0.7, "b": 0.3])
    }

    func testAdaptiveScorerPropagatesFailure() {
        struct Boom: Error {}
        struct Failing: SlotScoring { func labelScores(for crop: UIImage) throws -> [String: Double] { throw Boom() } }

        XCTAssertThrowsError(try LevelAdaptiveScorer(base: Failing()).labelScores(for: halves(dark: 0.1, light: 0.5)))
    }
}
