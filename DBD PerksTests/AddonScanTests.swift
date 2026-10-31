//
//  AddonScanTests.swift
//  DBD PerksTests
//

import XCTest
@testable import DBD_Perks

final class AddonScanTests: XCTestCase {

    private func addon(_ id: String, stem: String, owner: String = "The Trapper") -> AddonInfo {
        AddonInfo(id: id, name: id, role: .killer, kind: .power, parent: "", ownerName: owner, rarity: .rare,
                  description: "d", iconStem: stem, iconUrl: nil)
    }

    private func makeResolver() -> AddonResolver {
        AddonResolver(repository: BundledAddonRepository(addons: [
            addon("one", stem: "Icon_One"), addon("two_a", stem: "icon_two", owner: "The Wraith"), addon("two_b", stem: "ICON_TWO", owner: "The Hag"),
            addon("three", stem: "icon_three"),
        ]))
    }

    // MARK: Candidates

    func testCandidatesSkipBackgroundAndUnknownLabelsAndAreBestFirst() {
        let scores = ["__background__": 0.5, "icon_one": 0.2, "icon_two": 0.15, "not_an_addon": 0.1, "icon_three": 0.05]

        let candidates = makeResolver().candidates(from: scores)

        XCTAssertEqual(candidates.map(\.perkID), ["icon_one", "icon_two", "icon_three"])
    }

    func testLabelsMatchStemsIgnoringCase() {
        XCTAssertEqual(makeResolver().addons(forLabel: "icon_one").map(\.id), ["one"])
        XCTAssertEqual(Set(makeResolver().addons(forLabel: "icon_two").map(\.id)), ["two_a", "two_b"])
    }

    // MARK: Decision

    func testConfidentWinnerIsChosenWithoutWarning() {
        let result = makeResolver().resolve(from: ["icon_one": 0.9, "icon_two": 0.05])

        XCTAssertEqual(result.chosen?.perkID, "icon_one")
        XCTAssertFalse(result.isLowConfidence)
    }

    func testWeakGuessIsNotRecognisedButKeepsAlternatives() {
        let result = makeResolver().resolve(from: ["icon_one": 0.12, "icon_two": 0.1])

        XCTAssertNil(result.chosen)
        XCTAssertEqual(result.candidates.count, 2)
    }

    func testCloseCallIsFlagged() {
        let result = makeResolver().resolve(from: ["icon_one": 0.45, "icon_two": 0.4])

        XCTAssertEqual(result.chosen?.perkID, "icon_one")
        XCTAssertTrue(result.isLowConfidence)
    }

    func testEmptyScoresGiveNoResult() {
        let result = makeResolver().resolve(from: [:])

        XCTAssertNil(result.chosen)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    // MARK: Layout

    func testAddonGuideIsOneCenteredSquareAndCropsAreSlightlyLargerThanTheTile() throws {
        let slots = PerkSlotLayout.addon.slots(in: CGSize(width: 400, height: 800))

        let slot = try XCTUnwrap(slots.first)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slot.shape, .square)
        XCTAssertEqual(slot.center, CGPoint(x: 200, y: 400))
        XCTAssertGreaterThan(slot.classifierCropRect.width, slot.cropRect.width)
        XCTAssertEqual(slot.classifierCropRect.midX, 200, accuracy: 0.01)
    }

    func testPerkSlotsKeepTheirDiamondShape() {
        XCTAssertTrue(PerkSlotLayout.diamond.slots(in: CGSize(width: 400, height: 800)).allSatisfy { $0.shape == .diamond })
    }

    // MARK: Bundle

    func testEveryBundledAddonHasALabelTheResolverUnderstands() throws {
        let repository = try BundledAddonRepository(bundle: .main)
        let resolver = AddonResolver(repository: repository)

        let orphans = repository.allAddons.filter { resolver.addons(forLabel: $0.iconStem.lowercased()).isEmpty }

        XCTAssertTrue(orphans.isEmpty)
    }
}
