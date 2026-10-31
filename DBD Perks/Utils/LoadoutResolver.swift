//
//  LoadoutResolver.swift
//  DBD Perks
//

import Foundation

struct PerkCandidate: Equatable, Codable {
    let perkID: String
    let probability: Double
}

struct SlotResult: Identifiable, Equatable {
    let slot: Int
    /// Top candidates for this slot, best first (what the user can switch between).
    let candidates: [PerkCandidate]
    let chosen: PerkCandidate?
    /// True when the model is unsure, or the best guess was taken by another slot.
    let isLowConfidence: Bool

    var id: Int { slot }

    var alternatives: [PerkCandidate] { candidates.filter { $0 != chosen } }
}

/// Turns raw per-slot model scores into a loadout in which no perk appears twice.
struct LoadoutResolver {
    static let candidatesPerSlot = 5
    static let lowConfidenceThreshold = 0.5
    /// Below this the model is guessing (typically a perk newer than its training data): no perk is chosen at all.
    static let recognitionThreshold = 0.2
    /// A pick whose lead over the next-best different perk is smaller than this is flagged, so look-alike icons get a second look.
    static let minimumMargin = 0.15
    private static let probabilityFloor = 1e-6

    let repository: PerkRepository

    /// Top-k known perks for one slot. Labels the wiki no longer has are skipped.
    func candidates(from scores: [String: Double], k: Int = LoadoutResolver.candidatesPerSlot) -> [PerkCandidate] {
        TopK.select(from: scores, k: k) { repository.perkID(forModelLabel: $0) != nil }
            .compactMap { entry in
                repository.perkID(forModelLabel: entry.label).map { PerkCandidate(perkID: $0, probability: entry.score) }
            }
    }

    /// Picks one candidate per slot, all different, maximizing the summed log-probability.
    /// Exhaustive search is O(k^n): at most 5^4 = 625 leaves, so no Hungarian algorithm is needed.
    func resolve(_ slotCandidates: [[PerkCandidate]]) -> [SlotResult] {
        let recognizable = slotCandidates.map { $0.filter { $0.probability >= Self.recognitionThreshold } }
        let picks = search(slot: 0, slots: recognizable, used: []).picks
        return slotCandidates.enumerated().map { index, candidates in
            let chosen = picks[index]
            let wasDisplaced = chosen != nil && chosen != candidates.first
            let isUnsure = (chosen?.probability ?? 0) < Self.lowConfidenceThreshold || Self.isCloseCall(chosen, among: candidates)
            return SlotResult(slot: index, candidates: candidates, chosen: chosen, isLowConfidence: wasDisplaced || isUnsure)
        }
    }

    private static func isCloseCall(_ chosen: PerkCandidate?, among candidates: [PerkCandidate]) -> Bool {
        guard let chosen, let runnerUp = candidates.first(where: { $0.perkID != chosen.perkID }) else { return false }
        return chosen.probability - runnerUp.probability < minimumMargin
    }

    private func search(slot: Int, slots: [[PerkCandidate]], used: Set<String>) -> (score: Double, picks: [PerkCandidate?]) {
        guard slot < slots.count else { return (0, []) }

        // Leaving the slot empty is an option too, so one weak guess cannot force a duplicate-free
        // assignment that is worse than skipping it.
        let skipped = search(slot: slot + 1, slots: slots, used: used)
        var best: (score: Double, picks: [PerkCandidate?]) = (log(Self.probabilityFloor) + skipped.score, [nil] + skipped.picks)

        for candidate in slots[slot] where !used.contains(candidate.perkID) {
            let rest = search(slot: slot + 1, slots: slots, used: used.union([candidate.perkID]))
            let total = log(max(candidate.probability, Self.probabilityFloor)) + rest.score
            if total > best.score {
                best = (total, [candidate] + rest.picks)
            }
        }
        return best
    }
}
