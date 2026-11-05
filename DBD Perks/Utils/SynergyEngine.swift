//
//  SynergyEngine.swift
//  DBD Perks
//

import Foundation

/// A small, deterministic generator so tests (and a "same shuffle" option) can repeat a draw.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A suggested set. The first item is the seed when the user picked one.
struct SynergySuggestion: Equatable {
    let items: [SynergyItem]
    let score: Double
    /// Plain-language links between the items, strongest first.
    let reasons: [String]
}

/// Scores how well perks or add-ons support each other, using what `tools/synergy` learned offline.
///
/// Synergy is complementarity: one item gives a status (Exposed, Hindered, ...) another one uses. Text that is
/// merely similar adds only a little and near-duplicates are penalised. All maths is on-device and offline.
struct SynergyEngine {
    enum Weight {
        static let statusLink = 3.0
        static let maxStatusLinks = 2
        static let sharedTheme = 1.0
        static let maxSharedThemes = 2
        static let similarity = 0.8
        static let similarityCap: Float = 0.6
        static let duplicateCosine: Float = 0.9
        static let duplicatePenalty = 2.5
    }

    /// Candidates this close to the best one are all fair picks, so repeated shuffles differ.
    private static let pickTolerance = 1.0
    private static let pickPoolSize = 4
    private static let maxReasons = 3

    private let items: [SynergyItem]
    private let itemsByID: [String: SynergyItem]

    init(items: [SynergyItem]) {
        self.items = items
        itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func item(_ id: String) -> SynergyItem? { itemsByID[id] }

    // MARK: Pair score

    func pairScore(_ first: SynergyItem, _ second: SynergyItem) -> (score: Double, reasons: [String]) {
        var score = 0.0
        var reasons: [String] = []

        let links = statusLinks(from: first, to: second) + statusLinks(from: second, to: first)
        for link in links.prefix(Weight.maxStatusLinks) {
            score += Weight.statusLink
            reasons.append(link)
        }

        let shared = Set(first.themes).intersection(second.themes).sorted()
        for theme in shared.prefix(Weight.maxSharedThemes) {
            score += Weight.sharedTheme
            reasons.append("both lean on \(theme)")
        }

        let cosine = Self.cosine(first.embedding, second.embedding)
        score += Weight.similarity * Double(min(max(cosine, 0), Weight.similarityCap))
        if cosine > Weight.duplicateCosine { score -= Weight.duplicatePenalty }
        return (score, reasons)
    }

    private func statusLinks(from giver: SynergyItem, to user: SynergyItem) -> [String] {
        Set(giver.produces).intersection(user.consumes).sorted()
            .map { "\(giver.name) applies \($0), which \(user.name) uses" }
    }

    private static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Float {
        zip(lhs, rhs).reduce(0) { $0 + $1.0 * $1.1 }
    }

    // MARK: Suggestions

    /// A random set of `count` perks of one role (a random role when `role` is nil).
    func randomPerkSet<G: RandomNumberGenerator>(count: Int, role: PerkInfo.Role? = nil, using rng: inout G) -> SynergySuggestion? {
        let perks = items.filter { $0.kind == .perk && (role == nil || $0.role == role) }
        let byRole = Dictionary(grouping: perks, by: \.role).filter { $0.value.count >= count }
        guard let pool = byRole.sorted(by: { $0.key.rawValue < $1.key.rawValue }).randomElement(using: &rng)?.value else { return nil }
        return grow(from: randomStart(in: pool, using: &rng), pool: pool, count: count, using: &rng)
    }

    /// A random pair of add-ons of one killer power or survivor item.
    func randomAddonPair<G: RandomNumberGenerator>(using rng: inout G) -> SynergySuggestion? {
        let groups = Dictionary(grouping: items.filter { $0.kind == .addon }, by: \.group).filter { $0.value.count >= 2 }
        guard let pool = groups.sorted(by: { $0.key < $1.key }).randomElement(using: &rng)?.value else { return nil }
        return grow(from: randomStart(in: pool, using: &rng), pool: pool, count: 2, using: &rng)
    }

    /// The seed perk plus `count` perks of the same role that support it.
    func completePerk<G: RandomNumberGenerator>(seedID: String, count: Int, using rng: inout G) -> SynergySuggestion? {
        guard let seed = item(seedID), seed.kind == .perk else { return nil }
        let pool = items.filter { $0.kind == .perk && $0.role == seed.role }
        guard pool.count > count else { return nil }
        return grow(from: seed, pool: pool, count: count + 1, using: &rng)
    }

    /// The seed add-on plus one add-on of the same power or item that supports it.
    func completeAddon<G: RandomNumberGenerator>(seedID: String, using rng: inout G) -> SynergySuggestion? {
        guard let seed = item(seedID), seed.kind == .addon else { return nil }
        let pool = items.filter { $0.kind == .addon && $0.group == seed.group }
        guard pool.count > 1 else { return nil }
        return grow(from: seed, pool: pool, count: 2, using: &rng)
    }

    // MARK: Building

    /// Starts from an item that has status tags when there is one, so the set has something to build on.
    private func randomStart<G: RandomNumberGenerator>(in pool: [SynergyItem], using rng: inout G) -> SynergyItem {
        let tagged = pool.filter { !$0.produces.isEmpty || !$0.consumes.isEmpty }
        return (tagged.isEmpty ? pool : tagged).randomElement(using: &rng)!
    }

    /// Adds one item at a time: a random pick among the candidates that fit the set so far almost as well as the best.
    private func grow<G: RandomNumberGenerator>(from seed: SynergyItem, pool: [SynergyItem], count: Int,
                                                using rng: inout G) -> SynergySuggestion? {
        guard pool.count >= count else { return nil }
        var chosen = [seed]
        while chosen.count < count {
            let taken = Set(chosen.map(\.id))
            var ranked: [(item: SynergyItem, score: Double)] = []
            for candidate in pool where !taken.contains(candidate.id) {
                let fit = chosen.reduce(0.0) { $0 + pairScore($1, candidate).score }
                ranked.append((candidate, fit))
            }
            ranked.sort { $0.score != $1.score ? $0.score > $1.score : $0.item.id < $1.item.id }
            guard let best = ranked.first else { return nil }
            let fair = ranked.prefix(Self.pickPoolSize).filter { best.score - $0.score <= Self.pickTolerance }
            chosen.append(fair.randomElement(using: &rng)!.item)
        }
        return suggestion(for: chosen)
    }

    private func suggestion(for chosen: [SynergyItem]) -> SynergySuggestion {
        var total = 0.0
        var scored: [(Double, String)] = []
        for (index, first) in chosen.enumerated() {
            for second in chosen[(index + 1)...] {
                let pair = pairScore(first, second)
                total += pair.score
                scored += pair.reasons.map { (pair.score, $0) }
            }
        }
        var reasons: [String] = []
        for (_, reason) in scored.sorted(by: { $0.0 > $1.0 }) where !reasons.contains(reason) {
            reasons.append(reason)
        }
        return SynergySuggestion(items: chosen, score: total, reasons: Array(reasons.prefix(Self.maxReasons)))
    }
}
