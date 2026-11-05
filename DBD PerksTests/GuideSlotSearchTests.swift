//
//  GuideSlotSearchTests.swift
//  DBD PerksTests
//

import XCTest
import UIKit
@testable import DBD_Perks

final class GuideSlotSearchTests: XCTestCase {

    /// "Perk" confidence is the share of red in the crop, so the best crop is the one sitting on the red icon.
    private struct RedShareScorer: SlotScoring {
        func labelScores(for crop: UIImage) throws -> [String: Double] {
            let red = GuideSlotSearchTests.redShare(of: crop)
            return ["a": red, ModelLabel.background: 1 - red]
        }
    }

    /// Mean red-minus-green of the image, 0 for white, 1 for pure red.
    static func redShare(of image: UIImage) -> Double {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let cgImage = image.cgImage,
              let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Double(Int(pixel[0]) - Int(pixel[1])) / 255
    }

    /// A white window for a slot of `diagonal` px with a red icon `iconFraction` of the diagonal wide, moved by `shift`.
    private func window(diagonal: CGFloat, iconFraction: CGFloat, shift: CGPoint) -> UIImage {
        let side = (diagonal * GuideSlotSearch.windowFraction).rounded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let icon = diagonal * iconFraction
            UIColor.red.setFill()
            context.fill(CGRect(x: side / 2 + shift.x - icon / 2, y: side / 2 + shift.y - icon / 2, width: icon, height: icon))
        }
    }

    func testRecentresOnAnIconTheGuideMissed() throws {
        let diagonal: CGFloat = 200
        let offCentre = window(diagonal: diagonal, iconFraction: 0.55, shift: CGPoint(x: diagonal * 0.1, y: -diagonal * 0.05))
        let centred = try XCTUnwrap(offCentre.cropped(toNormalizedRect: GuideSlotSearch.Placement(fraction: 0.65, dx: 0, dy: 0).normalizedRect))

        let best = try GuideSlotSearch(scorer: RedShareScorer()).bestCrop(in: offCentre)

        XCTAssertGreaterThan(Self.redShare(of: best), 0.9)
        XCTAssertGreaterThan(Self.redShare(of: best), Self.redShare(of: centred) + 0.2)
    }

    func testKeepsTheCentreWhenTheGuideIsAlreadyOnTheIcon() throws {
        let centred = window(diagonal: 200, iconFraction: 0.55, shift: .zero)

        let best = try GuideSlotSearch(scorer: RedShareScorer()).bestCrop(in: centred)

        XCTAssertGreaterThan(Self.redShare(of: best), 0.95)
    }

    func testPropagatesScorerFailure() {
        struct Boom: Error {}
        struct Failing: SlotScoring { func labelScores(for crop: UIImage) throws -> [String: Double] { throw Boom() } }

        XCTAssertThrowsError(try GuideSlotSearch(scorer: Failing()).bestCrop(in: window(diagonal: 100, iconFraction: 0.5, shift: .zero)))
    }

    func testConfidenceIgnoresBackground() {
        XCTAssertEqual(GuideSlotSearch.confidence(["a": 0.2, ModelLabel.background: 0.8]), 0.2, accuracy: 1e-9)
        XCTAssertEqual(GuideSlotSearch.confidence([:]), 0)
    }

    func testEveryReachablePlacementStaysInsideTheWindow() {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: -1e-6, dy: -1e-6)
        let steps = Int((GuideSlotSearch.maxShift / GuideSlotSearch.step).rounded())

        for fraction in PerkLocator.cropFractions {
            for x in -steps...steps {
                for y in -steps...steps {
                    let placement = GuideSlotSearch.Placement(fraction: fraction, dx: 0, dy: 0).shifted(x, y)
                    XCTAssertNotNil(placement)
                    XCTAssertTrue(unit.contains(placement!.normalizedRect), "\(fraction) \(x) \(y)")
                }
            }
            XCTAssertNil(GuideSlotSearch.Placement(fraction: fraction, dx: 0, dy: 0).shifted(steps + 1, 0))
        }
    }

    func testSearchWindowsContainTheClassifierCropAndStayOnScreenForEveryLayout() {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)

        for layout in PerkSlotLayout.allCases {
            for slot in layout.slots(in: bounds.size) {
                XCTAssertTrue(bounds.contains(slot.searchRect), layout.title)
                XCTAssertTrue(slot.searchRect.contains(slot.classifierCropRect), layout.title)
            }
        }
    }

    @MainActor
    func testGuideAnalysisScoresTheRecentredCrop() async throws {
        let diagonal: CGFloat = 200
        let offCentre = window(diagonal: diagonal, iconFraction: 0.55, shift: CGPoint(x: -diagonal * 0.1, y: 0))
        let perk = PerkInfo(id: "a", name: "A", role: .killer, owner: "", iconUrl: URL(string: "https://x.test/a.png")!,
                            description: "d", flavor: "", descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/a")!)
        let viewModel = PredictionViewModel(scorer: RedShareScorer(), repository: BundledPerkRepository(perks: [perk]),
                                            guideSearch: GuideSlotSearch(scorer: RedShareScorer()))

        await viewModel.analyze(crops: [offCentre])

        let probability = try XCTUnwrap(viewModel.results.first?.chosen?.probability)
        XCTAssertGreaterThan(probability, 0.9)
        XCTAssertLessThan(try XCTUnwrap(viewModel.slotImages.first).size.width, offCentre.size.width)
    }
}
