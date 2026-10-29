//
//  PredictionViewModelTests.swift
//  DBD PerksTests
//

import XCTest
import UIKit
@testable import DBD_Perks

@MainActor
final class PredictionViewModelTests: XCTestCase {

    private struct FakeScorer: SlotScoring {
        var scoresPerCall: [[String: Double]]
        var failure: Error?
        private let counter = Counter()

        final class Counter { var calls = 0 }

        init(_ scores: [[String: Double]], failure: Error? = nil) {
            self.scoresPerCall = scores
            self.failure = failure
        }

        func labelScores(for crop: UIImage) throws -> [String: Double] {
            if let failure { throw failure }
            defer { counter.calls += 1 }
            return scoresPerCall[counter.calls]
        }
    }

    private func repository() -> BundledPerkRepository {
        func perk(_ id: String) -> PerkInfo {
            PerkInfo(id: id, name: id.uppercased(), role: .killer, owner: "", iconUrl: URL(string: "https://x.test/\(id).png")!,
                     description: "d", flavor: "", descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/\(id)")!)
        }
        return BundledPerkRepository(perks: ["a", "b", "c", "d"].map(perk))
    }

    private let blank = UIImage()

    func testAnalyzeReturnsOneResultPerCropWithDistinctPerks() {
        let scorer = FakeScorer([
            ["a": 0.9, "b": 0.1],
            ["a": 0.55, "c": 0.4],
            ["d": 0.8, "b": 0.2],
            ["b": 0.7, "c": 0.3]
        ])
        let viewModel = PredictionViewModel(scorer: scorer, repository: repository())

        viewModel.analyze(crops: Array(repeating: blank, count: 4))

        XCTAssertEqual(viewModel.results.count, 4)
        let ids = viewModel.results.compactMap { $0.chosen?.perkID }
        XCTAssertEqual(ids.count, Set(ids).count, "no perk may appear twice")
        XCTAssertEqual(ids, ["a", "c", "d", "b"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAnalyzeIgnoresCropsBeyondFourSlots() {
        let scores = ["a": 0.9]
        let viewModel = PredictionViewModel(scorer: FakeScorer(Array(repeating: scores, count: 6)), repository: repository())

        viewModel.analyze(crops: Array(repeating: blank, count: 6))

        XCTAssertEqual(viewModel.results.count, PerkSlotLayout.maxSlots)
    }

    func testAnalyzeReportsScorerFailure() {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        let viewModel = PredictionViewModel(scorer: FakeScorer([], failure: Boom()), repository: repository())

        viewModel.analyze(crops: [blank])

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "boom")
    }

    func testSelectSwitchesChosenCandidateAndClearsLowConfidence() throws {
        let scorer = FakeScorer([["a": 0.4, "b": 0.35]])
        let viewModel = PredictionViewModel(scorer: scorer, repository: repository())
        viewModel.analyze(crops: [blank])
        let alternative = try XCTUnwrap(viewModel.results.first?.alternatives.first)

        viewModel.select(alternative, inSlot: 0)

        XCTAssertEqual(viewModel.results.first?.chosen, alternative)
        XCTAssertEqual(viewModel.results.first?.isLowConfidence, false)
        XCTAssertEqual(viewModel.perk(id: alternative.perkID)?.name, "B")
    }

    func testSelectIgnoresCandidateFromAnotherSlot() {
        let scorer = FakeScorer([["a": 0.9], ["b": 0.9]])
        let viewModel = PredictionViewModel(scorer: scorer, repository: repository())
        viewModel.analyze(crops: [blank, blank])
        let before = viewModel.results

        viewModel.select(PerkCandidate(perkID: "b", probability: 0.9), inSlot: 0)

        XCTAssertEqual(viewModel.results, before)
    }
}
