//
//  CatalogSearch.swift
//  DBD Perks
//

import Foundation

enum CatalogKind: Hashable {
    case perk
    case addon
}

enum CatalogEntry: Identifiable, Equatable {
    case perk(PerkInfo)
    case addon(AddonInfo)

    var id: String {
        switch self {
        case .perk(let perk): return perk.id
        case .addon(let addon): return addon.id
        }
    }

    var name: String {
        switch self {
        case .perk(let perk): return perk.name
        case .addon(let addon): return addon.name
        }
    }
}

struct CatalogQuery: Equatable {
    var text = ""
    /// Also look in the descriptions (slower, ranked after name matches).
    var includeDescriptions = false
    var role: PerkInfo.Role?
    var kind: CatalogKind?
    /// Only add-ons have a rarity: setting this hides perks.
    var rarity: AddonInfo.Rarity?
    /// The killer or survivor name that owns the perk or add-on.
    var owner: String?
}

/// Search over perks and add-ons. Keys are folded once in `init` (O(N·L)); each query is one linear
/// pass over the entries (O(N·L)) plus a sort of the m matches (O(m log m)).
struct CatalogSearch {
    private struct Indexed {
        let entry: CatalogEntry
        let kind: CatalogKind
        let role: PerkInfo.Role
        let owner: String
        let rarity: AddonInfo.Rarity?
        let nameKey: String
        let descriptionKey: String
    }

    private enum Rank: Int {
        case exact, namePrefix, wordPrefix, nameContains, description
    }

    private let indexed: [Indexed]
    /// Sorted, unique owner names for the filter menu.
    let owners: [String]

    init(perks: [PerkInfo], addons: [AddonInfo]) {
        let perkRows = perks.map {
            Indexed(entry: .perk($0), kind: .perk, role: $0.role, owner: $0.owner, rarity: nil,
                    nameKey: Self.fold($0.name), descriptionKey: Self.fold($0.description))
        }
        let addonRows = addons.map {
            Indexed(entry: .addon($0), kind: .addon, role: $0.role, owner: $0.ownerName, rarity: $0.rarity,
                    nameKey: Self.fold($0.name), descriptionKey: Self.fold($0.description))
        }
        indexed = perkRows + addonRows
        owners = Set(indexed.map(\.owner).filter { !$0.isEmpty }).sorted()
    }

    /// Lower-case, no accents, apostrophes dropped, other punctuation turned into single spaces.
    static func fold(_ text: String) -> String {
        let simple = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var result = ""
        var pendingSpace = false
        for scalar in simple.unicodeScalars {
            if scalar == "'" || scalar == "\u{2019}" { continue }
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingSpace && !result.isEmpty { result.append(" ") }
                pendingSpace = false
                result.unicodeScalars.append(scalar)
            } else {
                pendingSpace = true
            }
        }
        return result
    }

    func search(_ query: CatalogQuery) -> [CatalogEntry] {
        let needle = Self.fold(query.text)
        let matches: [(row: Indexed, rank: Rank)] = indexed.compactMap { row in
            guard passesFilters(row, query) else { return nil }
            guard !needle.isEmpty else { return (row, .exact) }
            guard let rank = rank(of: row, for: needle, includeDescriptions: query.includeDescriptions) else { return nil }
            return (row, rank)
        }
        return matches.sorted { lhs, rhs in
            lhs.rank != rhs.rank ? lhs.rank.rawValue < rhs.rank.rawValue
                : lhs.row.entry.name.localizedCaseInsensitiveCompare(rhs.row.entry.name) == .orderedAscending
        }.map(\.row.entry)
    }

    private func passesFilters(_ row: Indexed, _ query: CatalogQuery) -> Bool {
        if let kind = query.kind, row.kind != kind { return false }
        if let role = query.role, row.role != role { return false }
        if let owner = query.owner, row.owner != owner { return false }
        if let rarity = query.rarity, row.rarity != rarity { return false }
        return true
    }

    private func rank(of row: Indexed, for needle: String, includeDescriptions: Bool) -> Rank? {
        if row.nameKey == needle { return .exact }
        if row.nameKey.hasPrefix(needle) { return .namePrefix }
        if row.nameKey.contains(" " + needle) { return .wordPrefix }
        if row.nameKey.contains(needle) { return .nameContains }
        if includeDescriptions, row.descriptionKey.contains(needle) { return .description }
        return nil
    }
}
