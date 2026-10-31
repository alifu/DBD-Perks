//
//  AddonResolver.swift
//  DBD Perks
//

import Foundation

/// Turns the add-on model's scores for one crop into a `SlotResult`.
/// Model labels are lower-cased icon stems, so lookups ignore case. `PerkCandidate.perkID` holds that label.
struct AddonResolver {
    let repository: AddonRepository

    func addons(forLabel label: String) -> [AddonInfo] {
        repository.addons(forIconStem: label)
    }

    func candidates(from scores: [String: Double], k: Int = LoadoutResolver.candidatesPerSlot) -> [PerkCandidate] {
        TopK.select(from: scores, k: k) { label in
            label != ModelLabel.background && !addons(forLabel: label).isEmpty
        }
        .map { PerkCandidate(perkID: $0.label, probability: $0.score) }
    }

    /// One add-on per scan, so there is no duplicate assignment: take the best candidate when it is strong enough.
    func resolve(from scores: [String: Double]) -> SlotResult {
        let candidates = candidates(from: scores)
        guard let best = candidates.first, best.probability >= LoadoutResolver.recognitionThreshold else {
            return SlotResult(slot: 0, candidates: candidates, chosen: nil, isLowConfidence: true)
        }
        let margin = best.probability - (candidates.dropFirst().first?.probability ?? 0)
        let isUnsure = best.probability < LoadoutResolver.lowConfidenceThreshold || margin < LoadoutResolver.minimumMargin
        return SlotResult(slot: 0, candidates: candidates, chosen: best, isLowConfidence: isUnsure)
    }
}
