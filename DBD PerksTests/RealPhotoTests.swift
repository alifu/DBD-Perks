//
//  RealPhotoTests.swift
//  DBD PerksTests
//
//  Runs the detector on real in-game screenshots (Fixtures/real). Loadout-screen shots must give at least three
//  perks. The blurred in-game HUD shots are a known gap: they are reported but not asserted.
//  The report lists each region and top guess so a person can compare it with the picture.
//

import XCTest
import UIKit
@testable import DBD_Perks

final class RealPhotoTests: XCTestCase {

    private let minimumLoadoutPerks = 3

    func testDetectorFindsPerksInRealLoadoutScreenshots() throws {
        let bundle = Bundle(for: Self.self)
        let repository = try BundledPerkRepository(bundle: Bundle(for: CoreMLPerkScorer.self))
        let locator = PerkLocator(scorer: try CoreMLPerkScorer(), repository: repository)
        let paths = bundle.paths(forResourcesOfType: "jpeg", inDirectory: "Fixtures/real") + bundle.paths(forResourcesOfType: "jpeg", inDirectory: nil)
        let unique = Array(Set(paths)).sorted().filter { $0.contains("HUD_") || $0.contains("LOADOUT_") }
        XCTAssertFalse(unique.isEmpty, "no real fixtures bundled")

        var lines: [String] = []
        var counts: [String: Int] = [:]
        for path in unique {
            let name = (path as NSString).lastPathComponent
            let photo = try XCTUnwrap(UIImage(contentsOfFile: path))
            let start = Date()
            let found = locator.locate(in: photo)
            let seconds = Date().timeIntervalSince(start)
            counts[name] = found.count
            lines.append("\(name) found=\(found.count) \(String(format: "%.2fs", seconds))")
            if let cg = photo.scaled(toMaxSide: PerkLocator.analysisMaxSide).cgImage {
                let scorer = try CoreMLPerkScorer()
                for frame in ColorDiamondProposer().proposals(in: cg) {
                    for fraction in PerkLocator.cropFractions {
                        let side = min(frame.width, frame.height) * fraction
                        let crop = CGRect(x: frame.midX - side / 2, y: frame.midY - side / 2, width: side, height: side).integral
                        guard let part = cg.cropping(to: crop) else { continue }
                        let scores = try scorer.labelScores(for: UIImage(cgImage: part))
                        let top = scores.sorted { $0.value > $1.value }.prefix(2).map { "\($0.key)=\(String(format: "%.2f", $0.value))" }.joined(separator: " ")
                        lines.append(String(format: "  PROPOSAL x=%.0f y=%.0f w=%.0f f=%.2f  %@", frame.midX, frame.midY, frame.width, fraction, top))
                    }
                }
            }
            for item in found {
                let top = item.candidates.prefix(2).map { "\($0.perkID)=\(String(format: "%.2f", $0.probability))" }.joined(separator: " ")
                lines.append(String(format: "  x=%.2f y=%.2f w=%.2f  %@", item.region.midX, item.region.midY, item.region.width, top))
            }
        }
        let text = lines.joined(separator: "\n")
        if let path = ProcessInfo.processInfo.environment["REAL_REPORT_PATH"] {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        }
        for (name, count) in counts where name.hasPrefix("LOADOUT_") {
            XCTAssertGreaterThanOrEqual(count, minimumLoadoutPerks, "\(name)\n\(text)")
        }
    }
}
