//
//  TestTimeAugmentation.swift
//  DBD Perks
//

import UIKit

/// Mean of several probability tables. Labels missing from a table count as 0, so the result still sums to 1.
enum ScoreAveraging {
    static func mean(of tables: [[String: Double]]) -> [String: Double] {
        guard !tables.isEmpty else { return [:] }
        var totals: [String: Double] = [:]
        for table in tables {
            for (label, score) in table { totals[label, default: 0] += score }
        }
        let count = Double(tables.count)
        return totals.mapValues { $0 / count }
    }
}

/// Scores a crop several times, slightly shifted and zoomed, and averages the results.
/// A camera photo of a screen is never framed exactly like the training icons; averaging makes the
/// answer less dependent on a few pixels of framing. Costs `variants.count` classifier passes per crop,
/// so use it for the few guide crops, not for the hundreds of windows the locator tries.
struct TestTimeAugmentingScorer: SlotScoring {
    /// Sub-rectangles of the crop in 0...1 coordinates: the whole crop, a centered 8% zoom, and two opposite 8% shifts.
    static let variants: [CGRect] = [
        CGRect(x: 0, y: 0, width: 1, height: 1),
        CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92),
        CGRect(x: 0, y: 0, width: 0.92, height: 0.92),
        CGRect(x: 0.08, y: 0.08, width: 0.92, height: 0.92)
    ]

    let base: SlotScoring

    func labelScores(for crop: UIImage) throws -> [String: Double] {
        let images = Self.variants.map { crop.cropped(toNormalizedRect: $0) ?? crop }
        return ScoreAveraging.mean(of: try images.map(base.labelScores(for:)))
    }
}
