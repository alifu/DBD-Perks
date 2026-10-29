//
//  PredictionViewModel.swift
//  DBD Perks
//
//  Created by Alif on 30/10/25.
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PredictionViewModel {

    private(set) var results: [SlotResult] = []
    private(set) var errorMessage: String?

    @ObservationIgnored private let scorer: SlotScoring?
    @ObservationIgnored private let repository: PerkRepository?

    /// Production wiring: bundled data + Core ML model. Failures are shown instead of swallowed.
    init() {
        do {
            let live = try Self.makeLiveDependencies()
            scorer = live.scorer
            repository = live.repository
        } catch {
            scorer = nil
            repository = nil
            errorMessage = error.localizedDescription
        }
    }

    private static func makeLiveDependencies() throws -> (scorer: SlotScoring, repository: PerkRepository) {
        (try CoreMLPerkScorer(), try BundledPerkRepository())
    }

    init(scorer: SlotScoring, repository: PerkRepository) {
        self.scorer = scorer
        self.repository = repository
    }

    func perk(id: String) -> PerkInfo? { repository?.perk(id: id) }

    /// Recognizes every crop (at most `PerkSlotLayout.maxSlots`) and makes sure no perk repeats.
    func analyze(crops: [UIImage]) {
        guard let scorer, let repository else { return }
        errorMessage = nil
        let resolver = LoadoutResolver(repository: repository)
        do {
            let slotCandidates = try crops.prefix(PerkSlotLayout.maxSlots).map {
                resolver.candidates(from: try scorer.labelScores(for: $0))
            }
            results = resolver.resolve(slotCandidates)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    /// Lets the user correct a guess by picking another candidate of the same slot.
    func select(_ candidate: PerkCandidate, inSlot slot: Int) {
        results = results.map { result in
            guard result.slot == slot, result.candidates.contains(candidate) else { return result }
            return SlotResult(slot: slot, candidates: result.candidates, chosen: candidate, isLowConfidence: false)
        }
    }
}
