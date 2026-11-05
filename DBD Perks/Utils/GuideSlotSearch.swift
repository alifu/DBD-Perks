//
//  GuideSlotSearch.swift
//  DBD Perks
//

import UIKit

/// Finds the perk icon inside a guide window that was cut a little wider than the slot (`PerkSlot.searchRect`).
/// A fixed guide never lines up exactly with the screen: lobby, in-game and after-match perks are spaced
/// differently and a hand-held phone drifts. An off-centre crop in a tight diamond also picks up a corner of
/// the neighbouring perk. So try the locator's crop sizes, then hill-climb the centre, and keep the crop the
/// classifier is surest about.
///
/// Costs at most `cropFractions.count + rounds · 8` classifier passes per slot.
struct GuideSlotSearch: Sendable {
    /// How far the icon may sit from the guide centre, each way, as a share of the slot diagonal.
    static let maxShift: CGFloat = 0.1
    static let step: CGFloat = 0.05
    static let rounds = 2
    /// Side of the window cut from the photo, as a share of the slot diagonal: the widest crop plus the shift room.
    static var windowFraction: CGFloat { (PerkLocator.cropFractions.max() ?? 1) + 2 * maxShift }

    /// One crop inside the window: its size and centre offset, all as shares of the slot diagonal.
    struct Placement: Equatable {
        let fraction: CGFloat
        let dx: CGFloat
        let dy: CGFloat

        /// The crop in 0...1 coordinates of the window.
        var normalizedRect: CGRect {
            let window = GuideSlotSearch.windowFraction
            let side = fraction / window
            return CGRect(x: 0.5 + dx / window - side / 2, y: 0.5 + dy / window - side / 2, width: side, height: side)
        }

        func shifted(_ x: Int, _ y: Int) -> Placement? {
            let moved = Placement(fraction: fraction, dx: dx + CGFloat(x) * GuideSlotSearch.step,
                                  dy: dy + CGFloat(y) * GuideSlotSearch.step)
            let limit = GuideSlotSearch.maxShift + 1e-6
            return abs(moved.dx) <= limit && abs(moved.dy) <= limit ? moved : nil
        }
    }

    private static let directions = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)]

    let scorer: SlotScoring

    /// The best-framed crop of `window`. Falls back to the whole window when it cannot be cut.
    func bestCrop(in window: UIImage) throws -> UIImage {
        guard let best = try bestPlacement(in: window) else { return window }
        return window.cropped(toNormalizedRect: best.placement.normalizedRect) ?? window
    }

    private func bestPlacement(in window: UIImage) throws -> (placement: Placement, confidence: Double)? {
        let sizes = try PerkLocator.cropFractions.compactMap { try evaluate(Placement(fraction: $0, dx: 0, dy: 0), in: window) }
        guard var best = sizes.max(by: { $0.confidence < $1.confidence }) else { return nil }
        for _ in 0..<Self.rounds {
            let neighbours = try Self.directions
                .compactMap { best.placement.shifted($0.0, $0.1) }
                .compactMap { try evaluate($0, in: window) }
            guard let better = neighbours.max(by: { $0.confidence < $1.confidence }),
                  better.confidence > best.confidence else { break }
            best = better
        }
        return best
    }

    private func evaluate(_ placement: Placement, in window: UIImage) throws -> (placement: Placement, confidence: Double)? {
        guard let crop = window.cropped(toNormalizedRect: placement.normalizedRect) else { return nil }
        return (placement, Self.confidence(try scorer.labelScores(for: crop)))
    }

    /// How sure the model is that the crop shows one particular perk.
    static func confidence(_ scores: [String: Double]) -> Double {
        scores.filter { $0.key != ModelLabel.background }.values.max() ?? 0
    }
}
