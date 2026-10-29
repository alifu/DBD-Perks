//
//  LoadoutLogicTests.swift
//  DBD PerksTests
//

import XCTest
import CoreML
@testable import DBD_Perks

final class LoadoutLogicTests: XCTestCase {

    private func makeRepository() -> BundledPerkRepository {
        func perk(_ id: String) -> PerkInfo {
            PerkInfo(id: id, name: id, role: .survivor, owner: "", iconUrl: URL(string: "https://x.test/\(id).png")!,
                     description: "d", flavor: "", descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/\(id)")!)
        }
        return BundledPerkRepository(perks: ["a", "b", "c", "d"].map(perk))
    }

    // MARK: TopK

    func testTopKReturnsHighestScoresInDescendingOrder() {
        let scores = ["a": 0.1, "b": 0.5, "c": 0.3, "d": 0.05, "e": 0.9]

        let result = TopK.select(from: scores, k: 3)

        XCTAssertEqual(result.map(\.label), ["e", "b", "c"])
    }

    func testTopKRespectsFilterAndSmallInputs() {
        let result = TopK.select(from: ["a": 0.9, "b": 0.4], k: 5) { $0 != "a" }

        XCTAssertEqual(result.map(\.label), ["b"])
        XCTAssertTrue(TopK.select(from: ["a": 1], k: 0).isEmpty)
    }

    // MARK: Repository

    func testRepositoryResolvesOnlyKnownPerkIDsAsModelLabels() {
        let repository = makeRepository()

        XCTAssertEqual(repository.perkID(forModelLabel: "a"), "a")
        XCTAssertNil(repository.perkID(forModelLabel: "ghost"))
        XCTAssertEqual(repository.perk(id: "b")?.name, "b")
    }

    func testBundledResourcesLoadAndEveryModelLabelResolves() throws {
        let repository = try BundledPerkRepository(bundle: Bundle(for: CoreMLPerkScorer.self))
        let model = try DBDPerkClassifierV2(configuration: .init())
        let labels = try XCTUnwrap(model.model.modelDescription.classLabels as? [String])

        let orphans = labels.filter { $0 != ModelLabel.background && repository.perkID(forModelLabel: $0) == nil }

        XCTAssertGreaterThan(repository.allPerks.count, 250)
        XCTAssertEqual(orphans, [], "every label the model can output must have wiki data")
        XCTAssertGreaterThanOrEqual(labels.count, 270)
        XCTAssertTrue(labels.contains(ModelLabel.background), "the detector needs a 'not a perk' class")
    }

    // MARK: Resolver

    func testCandidatesSkipLabelsWithoutWikiData() {
        let resolver = LoadoutResolver(repository: makeRepository())

        let candidates = resolver.candidates(from: ["ghost": 0.9, "a": 0.6, "b": 0.3])

        XCTAssertEqual(candidates.map(\.perkID), ["a", "b"])
    }

    func testResolveNeverRepeatsAPerk() {
        let resolver = LoadoutResolver(repository: makeRepository())
        let slots = [
            [PerkCandidate(perkID: "a", probability: 0.9), PerkCandidate(perkID: "b", probability: 0.05)],
            [PerkCandidate(perkID: "a", probability: 0.6), PerkCandidate(perkID: "c", probability: 0.35)],
            [PerkCandidate(perkID: "d", probability: 0.8)]
        ]

        let results = resolver.resolve(slots)

        XCTAssertEqual(results.compactMap { $0.chosen?.perkID }, ["a", "c", "d"])
        XCTAssertFalse(results[0].isLowConfidence)
        XCTAssertTrue(results[1].isLowConfidence, "slot 2 lost its best guess to slot 1")
    }

    func testResolveFlagsLowProbabilityAndLeavesExhaustedSlotEmpty() {
        let resolver = LoadoutResolver(repository: makeRepository())
        let slots = [
            [PerkCandidate(perkID: "a", probability: 0.4)],
            [PerkCandidate(perkID: "a", probability: 0.9)]
        ]

        let results = resolver.resolve(slots)

        XCTAssertEqual(results[1].chosen?.perkID, "a")
        XCTAssertNil(results[0].chosen)
        XCTAssertTrue(results[0].isLowConfidence)
    }

    func testResolveEmptyLoadout() {
        XCTAssertTrue(LoadoutResolver(repository: makeRepository()).resolve([]).isEmpty)
    }

    // MARK: Geometry

    func testSlotLayoutsProduceFourDistinctSlotsInsideTheScreen() {
        let size = CGSize(width: 390, height: 844)
        let bounds = CGRect(origin: .zero, size: size)

        for layout in PerkSlotLayout.allCases {
            let slots = layout.slots(in: size)

            XCTAssertEqual(slots.count, PerkSlotLayout.maxSlots, layout.title)
            XCTAssertEqual(Set(slots.map { "\($0.center)" }).count, 4, layout.title)
            XCTAssertTrue(slots.allSatisfy { bounds.contains($0.cropRect) }, layout.title)
        }
    }

    func testDiamondCropsDoNotOverlapEachOther() {
        let rects = PerkSlotLayout.diamond.slots(in: CGSize(width: 390, height: 844)).map(\.cropRect)

        for (i, first) in rects.enumerated() {
            for second in rects[(i + 1)...] {
                XCTAssertFalse(first.intersects(second))
            }
        }
    }

    func testCropGeometryMapsCenterOfFilledPreview() throws {
        // 400x300 photo shown scaledToFill in a 200x400 view: scale = 400/300, horizontal overflow only.
        let viewSize = CGSize(width: 200, height: 400)
        let imageSize = CGSize(width: 400, height: 300)
        let center = CGRect(x: 75, y: 175, width: 50, height: 50)

        let rect = try XCTUnwrap(CropGeometry.imageRect(forViewRect: center, viewSize: viewSize, imageSize: imageSize))

        XCTAssertEqual(rect.midX, 200, accuracy: 1)
        XCTAssertEqual(rect.midY, 150, accuracy: 1)
        XCTAssertEqual(rect.width, 37.5, accuracy: 1)
    }

    func testCropGeometryRejectsRectOutsideImageAndEmptySizes() {
        let image = CGSize(width: 100, height: 100)

        XCTAssertNil(CropGeometry.imageRect(forViewRect: CGRect(x: 500, y: 500, width: 10, height: 10), viewSize: CGSize(width: 100, height: 100), imageSize: image))
        XCTAssertNil(CropGeometry.imageRect(forViewRect: .zero, viewSize: .zero, imageSize: image))
    }
}
