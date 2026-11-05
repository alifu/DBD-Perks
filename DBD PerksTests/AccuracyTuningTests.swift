//
//  AccuracyTuningTests.swift
//  DBD PerksTests
//

import XCTest
import UIKit
@testable import DBD_Perks

@MainActor
final class AccuracyTuningTests: XCTestCase {

    private func solidImage(side: CGFloat = 100) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    private func repository() -> BundledPerkRepository {
        func perk(_ id: String) -> PerkInfo {
            PerkInfo(id: id, name: id.uppercased(), role: .killer, owner: "", iconUrl: URL(string: "https://x.test/\(id).png")!,
                     description: "d", flavor: "", descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/\(id)")!)
        }
        return BundledPerkRepository(perks: ["a", "b", "c"].map(perk))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // MARK: 3A.3 test-time augmentation

    func testMeanAveragesProbabilitiesAndTreatsMissingLabelsAsZero() {
        let mean = ScoreAveraging.mean(of: [["a": 0.8, "b": 0.2], ["a": 0.4, "c": 0.6]])

        XCTAssertEqual(mean["a"] ?? 0, 0.6, accuracy: 1e-9)
        XCTAssertEqual(mean["b"] ?? 0, 0.1, accuracy: 1e-9)
        XCTAssertEqual(mean["c"] ?? 0, 0.3, accuracy: 1e-9)
        XCTAssertEqual(mean.values.reduce(0, +), 1, accuracy: 1e-9)
        XCTAssertTrue(ScoreAveraging.mean(of: []).isEmpty)
    }

    func testAugmentingScorerScoresEveryVariantOfTheCropAndAverages() throws {
        struct SizeScorer: SlotScoring {
            let seenWidths = Seen()
            final class Seen: @unchecked Sendable { var widths: [CGFloat] = [] }
            func labelScores(for crop: UIImage) throws -> [String: Double] {
                seenWidths.widths.append(crop.size.width)
                return crop.size.width < 100 ? ["a": 1] : ["b": 1]
            }
        }
        let base = SizeScorer()

        let scores = try TestTimeAugmentingScorer(base: base).labelScores(for: solidImage())

        XCTAssertEqual(base.seenWidths.widths.count, TestTimeAugmentingScorer.variants.count)
        XCTAssertEqual(scores["b"] ?? 0, 0.25, accuracy: 1e-9, "only the uncropped variant is 100 px wide")
        XCTAssertEqual(scores["a"] ?? 0, 0.75, accuracy: 1e-9)
    }

    func testAugmentingScorerPropagatesBaseFailure() {
        struct Boom: Error {}
        struct Failing: SlotScoring { func labelScores(for crop: UIImage) throws -> [String: Double] { throw Boom() } }

        XCTAssertThrowsError(try TestTimeAugmentingScorer(base: Failing()).labelScores(for: solidImage()))
    }

    // MARK: 3A.4 framing

    func testClassifierCropIsWiderThanGuideCropAndSharesItsCenter() {
        let slots = PerkSlotLayout.single.slots(in: CGSize(width: 390, height: 844)) + PerkSlotLayout.diamond.slots(in: CGSize(width: 390, height: 844))

        for slot in slots {
            XCTAssertGreaterThan(slot.classifierCropRect.width, slot.cropRect.width)
            XCTAssertEqual(slot.classifierCropRect.midX, slot.cropRect.midX, accuracy: 1e-6)
            XCTAssertEqual(slot.classifierCropRect.midY, slot.cropRect.midY, accuracy: 1e-6)
            XCTAssertEqual(slot.classifierCropRect.width / slot.diagonal, PerkLocator.cropFractions[0], accuracy: 1e-6)
        }
    }

    func testClassifierCropsStayInsideTheScreenForEveryLayout() {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)

        for layout in PerkSlotLayout.allCases {
            XCTAssertTrue(layout.slots(in: bounds.size).allSatisfy { bounds.contains($0.classifierCropRect) }, layout.title)
        }
    }

    // MARK: 3A.5 margin rule

    func testCloseCallBetweenLookAlikesIsFlaggedEvenWhenAboveThreshold() {
        let resolver = LoadoutResolver(repository: repository())
        let close = [PerkCandidate(perkID: "a", probability: 0.55), PerkCandidate(perkID: "b", probability: 0.44)]

        let result = resolver.resolve([close])[0]

        XCTAssertEqual(result.chosen?.perkID, "a")
        XCTAssertTrue(result.isLowConfidence)
        XCTAssertEqual(result.alternatives.map(\.perkID), ["b"], "the look-alike is offered as the alternative")
    }

    func testClearWinnerIsNotFlagged() {
        let resolver = LoadoutResolver(repository: repository())
        let clear = [PerkCandidate(perkID: "a", probability: 0.8), PerkCandidate(perkID: "b", probability: 0.15)]

        XCTAssertFalse(resolver.resolve([clear])[0].isLowConfidence)
    }

    func testMarginIsExactlyAtTheLimitNotFlagged() {
        let resolver = LoadoutResolver(repository: repository())
        let atLimit = [PerkCandidate(perkID: "a", probability: 0.75), PerkCandidate(perkID: "b", probability: 0.75 - LoadoutResolver.minimumMargin)]

        XCTAssertFalse(resolver.resolve([atLimit])[0].isLowConfidence)
    }

    // MARK: not recognised

    func testGuessBelowRecognitionThresholdChoosesNoPerkButKeepsGuessesAsAlternatives() {
        let resolver = LoadoutResolver(repository: repository())
        let guessing = [PerkCandidate(perkID: "a", probability: 0.11), PerkCandidate(perkID: "b", probability: 0.03)]

        let result = resolver.resolve([guessing])[0]

        XCTAssertNil(result.chosen)
        XCTAssertTrue(result.isLowConfidence)
        XCTAssertEqual(result.alternatives.map(\.perkID), ["a", "b"], "the user can still pick the closest guess")
    }

    func testGuessAtRecognitionThresholdIsStillChosen() {
        let resolver = LoadoutResolver(repository: repository())
        let atLimit = [PerkCandidate(perkID: "a", probability: LoadoutResolver.recognitionThreshold)]

        XCTAssertEqual(resolver.resolve([atLimit])[0].chosen?.perkID, "a")
    }

    func testUnrecognisedSlotDoesNotBlockTheOthers() {
        let resolver = LoadoutResolver(repository: repository())
        let slots = [
            [PerkCandidate(perkID: "a", probability: 0.05)],
            [PerkCandidate(perkID: "a", probability: 0.9)]
        ]

        let results = resolver.resolve(slots)

        XCTAssertNil(results[0].chosen)
        XCTAssertEqual(results[1].chosen?.perkID, "a")
    }

    // MARK: 3A.1 scan log

    func testRecordScanWritesCropsAndOneJSONLine() throws {
        let recorder = ScanRecorder(directory: try temporaryDirectory())
        let results = [SlotResult(slot: 0, candidates: [PerkCandidate(perkID: "a", probability: 0.9)],
                                  chosen: PerkCandidate(perkID: "a", probability: 0.9), isLowConfidence: false)]

        let id = try XCTUnwrap(recorder.recordScan(source: "guide", crops: [solidImage()], results: results))
        recorder.recordScan(source: "auto", crops: [], results: [])

        let log = try String(contentsOf: recorder.directory.appendingPathComponent("scans.jsonl"), encoding: .utf8)
        let lines = log.split(separator: "\n")
        XCTAssertEqual(lines.count, 2, "one line per scan, appended")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let first = try decoder.decode(ScanRecord.self, from: Data(lines[0].utf8))
        XCTAssertEqual(first.id, id)
        XCTAssertEqual(first.source, "guide")
        XCTAssertEqual(first.slots.first?.chosenPerkID, "a")
        XCTAssertTrue(FileManager.default.fileExists(atPath: recorder.directory.appendingPathComponent("crops/\(id)_0.jpg").path))
    }

    func testSaveCorrectionFilesCropUnderTheRightPerk() throws {
        let recorder = ScanRecorder(directory: try temporaryDirectory())
        let correction = CorrectionRecord(scanID: "scan1", slot: 2, correctPerkID: "b", predictedPerkID: "a",
                                          topCandidates: [PerkCandidate(perkID: "a", probability: 0.6)])

        XCTAssertTrue(recorder.saveCorrection(correction, crop: solidImage()))

        let folder = recorder.directory.appendingPathComponent("corrections/b")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("scan1_2.jpg").path))
        let saved = try JSONDecoder().decode(CorrectionRecord.self, from: Data(contentsOf: folder.appendingPathComponent("scan1_2.json")))
        XCTAssertEqual(saved, correction)
    }

    func testReportWrongRecordsPredictedAndCorrectPerk() async throws {
        struct Fixed: SlotScoring { func labelScores(for crop: UIImage) throws -> [String: Double] { ["a": 0.6, "b": 0.4] } }
        let recorder = ScanRecorder(directory: try temporaryDirectory())
        let viewModel = PredictionViewModel(scorer: Fixed(), repository: repository(), recorder: recorder)
        await viewModel.analyze(crops: [solidImage()])

        XCTAssertTrue(viewModel.canReportWrongPerk)
        XCTAssertTrue(viewModel.reportWrong(slot: 0, correctPerkID: "b"))

        let folder = recorder.directory.appendingPathComponent("corrections/b")
        let json = try XCTUnwrap(try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first { $0.pathExtension == "json" })
        let saved = try JSONDecoder().decode(CorrectionRecord.self, from: Data(contentsOf: json))
        XCTAssertEqual(saved.predictedPerkID, "a")
        XCTAssertEqual(saved.correctPerkID, "b")
    }

    func testReportWrongIsDisabledWithoutARecorder() async {
        struct Fixed: SlotScoring { func labelScores(for crop: UIImage) throws -> [String: Double] { ["a": 1] } }
        let viewModel = PredictionViewModel(scorer: Fixed(), repository: repository())
        await viewModel.analyze(crops: [solidImage()])

        XCTAssertFalse(viewModel.canReportWrongPerk)
        XCTAssertFalse(viewModel.reportWrong(slot: 0, correctPerkID: "b"))
    }
}
