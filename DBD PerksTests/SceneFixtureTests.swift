//
//  SceneFixtureTests.swift
//  DBD PerksTests
//
//  Runs the real model and detector on fake loadout screenshots (made by make_scene_fixtures.py in
//  dbd_perks_dataset). They check the detector logic only: real in-game photos still need a manual check.
//

import XCTest
import UIKit
@testable import DBD_Perks

final class SceneFixtureTests: XCTestCase {

    private struct SceneInfo: Decodable {
        struct Perk: Decodable { let id: String; let cx: Double; let cy: Double; let diagonal: Double }
        let file: String
        let layout: String
        let width: Double
        let height: Double
        let perks: [Perk]
    }

    private struct SceneOutcome {
        let info: SceneInfo
        let foundIDs: [String]
        let correctlyPlaced: Int
        let seconds: Double

        var expectedIDs: Set<String> { Set(info.perks.map(\.id)) }
        var isExact: Bool { Set(foundIDs) == expectedIDs && foundIDs.count == expectedIDs.count }
    }

    /// Regression floors, not goals: the fake scenes guess at the in-game art and are harder than the real
    /// loadout screens (see RealPhotoTests), so these only catch the detector getting worse.
    private let requiredExactRate = 0.15
    private let requiredRecall = 0.5

    /// SCENE_PROPOSERS=rect,contour,grid (any subset, in order) lets one proposer be measured alone.
    private func proposers() -> [RegionProposing] {
        guard let choice = ProcessInfo.processInfo.environment["SCENE_PROPOSERS"] else { return PerkLocator.defaultProposers }
        return choice.split(separator: ",").compactMap { name -> RegionProposing? in
            switch name {
            case "color": return ColorDiamondProposer()
            case "rect": return VisionRectangleProposer()
            case "contour": return VisionContourProposer()
            case "grid": return GridProposer()
            default: return nil
            }
        }
    }

    private func loadManifest(_ bundle: Bundle) throws -> [SceneInfo] {
        let url = try XCTUnwrap(bundle.url(forResource: "manifest", withExtension: "json")
                                ?? bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "Fixtures/scenes"))
        return try JSONDecoder().decode([SceneInfo].self, from: Data(contentsOf: url))
    }

    private func imagePath(_ file: String, in bundle: Bundle) -> String? {
        let name = (file as NSString).deletingPathExtension
        return (bundle.path(forResource: name, ofType: "jpg") ?? bundle.path(forResource: name, ofType: "jpg", inDirectory: "Fixtures/scenes"))
    }

    private func run(_ info: SceneInfo, with locator: PerkLocator, repository: PerkRepository, bundle: Bundle) throws -> SceneOutcome {
        let path = try XCTUnwrap(imagePath(info.file, in: bundle), "missing fixture \(info.file)")
        let photo = try XCTUnwrap(UIImage(contentsOfFile: path))

        let start = Date()
        let found = locator.locate(in: photo)
        let results = LoadoutResolver(repository: repository).resolve(found.map(\.candidates))
        let seconds = Date().timeIntervalSince(start)

        let placed = zip(found, results).filter { located, result in
            guard let id = result.chosen?.perkID, let truth = info.perks.first(where: { $0.id == id }) else { return false }
            let dx = located.region.midX * info.width - truth.cx
            let dy = located.region.midY * info.height - truth.cy
            return hypot(dx, dy) < truth.diagonal * 0.5
        }.count
        return SceneOutcome(info: info, foundIDs: results.compactMap { $0.chosen?.perkID }, correctlyPlaced: placed, seconds: seconds)
    }

    private func report(_ outcomes: [SceneOutcome], exactRate: Double, recall: Double) -> String {
        var lines = ["scenes=\(outcomes.count) exactRate=\(exactRate) recall=\(recall)"]
        for outcome in outcomes {
            let missing = outcome.expectedIDs.subtracting(outcome.foundIDs).sorted()
            let extra = Set(outcome.foundIDs).subtracting(outcome.expectedIDs).sorted()
            lines.append("\(outcome.isExact ? "OK " : "BAD") \(outcome.info.file) \(outcome.info.layout) found=\(outcome.foundIDs.count)/\(outcome.info.perks.count) placed=\(outcome.correctlyPlaced) "
                         + "\(String(format: "%.2fs", outcome.seconds)) missing=\(missing) extra=\(extra)")
        }
        return lines.joined(separator: "\n")
    }

    func testDetectorFindsPerksInSyntheticLoadoutScreens() throws {
        let bundle = Bundle(for: Self.self)
        let appBundle = Bundle(for: CoreMLPerkScorer.self)
        let repository = try BundledPerkRepository(bundle: appBundle)
        let locator = PerkLocator(scorer: try CoreMLPerkScorer(), repository: repository, proposers: proposers())

        let outcomes = try loadManifest(bundle).map { try run($0, with: locator, repository: repository, bundle: bundle) }

        let expected = outcomes.reduce(0) { $0 + $1.info.perks.count }
        let recall = Double(outcomes.reduce(0) { $0 + Set($1.foundIDs).intersection($1.expectedIDs).count }) / Double(expected)
        let exactRate = Double(outcomes.filter(\.isExact).count) / Double(outcomes.count)
        let text = report(outcomes, exactRate: exactRate, recall: recall)

        if let path = ProcessInfo.processInfo.environment["SCENE_REPORT_PATH"] {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        }
        XCTContext.runActivity(named: "Scene report") { $0.add(XCTAttachment(string: text)) }

        XCTAssertGreaterThanOrEqual(exactRate, requiredExactRate, text)
        XCTAssertGreaterThanOrEqual(recall, requiredRecall, text)
    }
}
