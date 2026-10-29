//
//  PerkLocator.swift
//  DBD Perks
//

import UIKit
import os

/// A perk found in a photo.
struct LocatedPerk: Equatable {
    /// The whole diamond frame, in 0...1 coordinates of the photo (top-left origin).
    let region: CGRect
    /// Top candidates for this spot, best first.
    let candidates: [PerkCandidate]
}

/// Finds up to four perk icons anywhere in a photo, without assuming how they are laid out:
/// 1. propose candidate frames (Vision rectangles, then a window grid if fewer than four were verified),
/// 2. keep only the ones the classifier is confident are a perk and not background,
/// 3. keep the best non-overlapping four and sort them in reading order.
///
/// With R proposals and classifier cost C: O(R · F · C) for F crop sizes, plus O(R log R) selection.
struct PerkLocator: Sendable {
    static let analysisMaxSide: CGFloat = 1024
    /// Share of the frame diagonal that is cropped for the classifier (matches the training crop).
    static let cropFractions: [CGFloat] = [0.65, 0.55, 0.75]
    static let minimumPerkProbability = 0.5
    static let maximumBackgroundProbability = 0.3
    static let minimumSeparation: CGFloat = 0.7   // of the larger frame side
    static let refineStep: CGFloat = 0.1          // of the frame side
    static let refineRounds = 2
    private static let minimumCropPixels = 16

    /// Cheapest first: later proposers only run while fewer than four perks were verified.
    static let defaultProposers: [RegionProposing] = [ColorDiamondProposer(), VisionRectangleProposer(), VisionContourProposer(), GridProposer()]

    let scorer: SlotScoring
    let repository: PerkRepository
    let proposers: [RegionProposing]

    private let logger = Logger(subsystem: "DBD Perks", category: "PerkLocator")

    init(scorer: SlotScoring,
         repository: PerkRepository,
         proposers: [RegionProposing] = PerkLocator.defaultProposers) {
        self.scorer = scorer
        self.repository = repository
        self.proposers = proposers
    }

    func locate(in photo: UIImage) -> [LocatedPerk] {
        guard let image = photo.scaled(toMaxSide: Self.analysisMaxSide).cgImage else { return [] }

        var verified: [Detection] = []
        var chosen: [Detection] = []
        for proposer in proposers {
            verified += proposer.proposals(in: image).compactMap { verify(frame: $0, in: image) }
            chosen = select(verified)
            if chosen.count >= PerkSlotLayout.maxSlots { break }
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        return order(chosen.map { refine($0, in: image) }).map { detection in
            LocatedPerk(
                region: CGRect(x: detection.frame.minX / imageSize.width, y: detection.frame.minY / imageSize.height,
                               width: detection.frame.width / imageSize.width, height: detection.frame.height / imageSize.height),
                candidates: detection.candidates)
        }
    }

    // MARK: - Verification

    private struct Detection {
        let frame: CGRect           // whole diamond
        let cropFraction: CGFloat
        let candidates: [PerkCandidate]

        var score: Double { candidates.first?.probability ?? 0 }
        var side: CGFloat { min(frame.width, frame.height) }
    }

    private func verify(frame: CGRect, in image: CGImage) -> Detection? {
        Self.cropFractions
            .compactMap { classify(frame: frame, cropFraction: $0, in: image) }
            .max { $0.score < $1.score }
    }

    /// nil unless the window clearly shows a perk icon.
    private func classify(frame: CGRect, cropFraction: CGFloat, in image: CGImage) -> Detection? {
        let side = min(frame.width, frame.height) * cropFraction
        let crop = CGRect(x: frame.midX - side / 2, y: frame.midY - side / 2, width: side, height: side).integral
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard bounds.contains(crop), Int(crop.width) >= Self.minimumCropPixels,
              let cropped = image.cropping(to: crop) else { return nil }

        let scores: [String: Double]
        do {
            scores = try scorer.labelScores(for: UIImage(cgImage: cropped))
        } catch {
            logger.error("Scoring failed: \(error.localizedDescription)")
            return nil
        }
        let candidates = LoadoutResolver(repository: repository).candidates(from: scores)
        guard let best = candidates.first,
              best.probability >= Self.minimumPerkProbability,
              (scores[ModelLabel.background] ?? 0) <= Self.maximumBackgroundProbability else { return nil }
        return Detection(frame: frame, cropFraction: cropFraction, candidates: candidates)
    }

    /// Greedy: strongest first, skipping anything that overlaps one already kept.
    private func select(_ detections: [Detection]) -> [Detection] {
        var kept: [Detection] = []
        for detection in detections.sorted(by: { $0.score > $1.score }) {
            let overlaps = kept.contains { other in
                hypot(other.frame.midX - detection.frame.midX, other.frame.midY - detection.frame.midY)
                    < max(other.side, detection.side) * Self.minimumSeparation
            }
            if !overlaps { kept.append(detection) }
            if kept.count == PerkSlotLayout.maxSlots { break }
        }
        return kept
    }

    /// Hill-climb the frame centre in small steps; grid windows are rarely centred on the icon.
    private func refine(_ detection: Detection, in image: CGImage) -> Detection {
        var best = detection
        for _ in 0..<Self.refineRounds {
            let step = best.side * Self.refineStep
            let neighbours = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)].compactMap { dx, dy in
                classify(frame: best.frame.offsetBy(dx: CGFloat(dx) * step, dy: CGFloat(dy) * step),
                         cropFraction: best.cropFraction, in: image)
            }
            guard let better = neighbours.max(by: { $0.score < $1.score }), better.score > best.score else { break }
            best = better
        }
        return best
    }

    /// Rows top to bottom, left to right inside a row.
    private func order(_ detections: [Detection]) -> [Detection] {
        guard let side = detections.map(\.side).max() else { return [] }
        return detections.sorted { first, second in
            let firstRow = (first.frame.midY / (side * 0.6)).rounded()
            let secondRow = (second.frame.midY / (side * 0.6)).rounded()
            return firstRow == secondRow ? first.frame.midX < second.frame.midX : firstRow < secondRow
        }
    }
}
