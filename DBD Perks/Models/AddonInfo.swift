//
//  AddonInfo.swift
//  DBD Perks
//

import Foundation

/// One add-on from the bundled `addons.json` (produced by tools/convert_addons.py in dbd_perks_dataset).
struct AddonInfo: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        /// A killer power add-on.
        case power
        /// A survivor item add-on (flashlight, medkit, ...).
        case item
    }

    enum Rarity: String, Codable, CaseIterable, Comparable {
        case none
        case common
        case uncommon
        case rare
        case veryRare = "veryrare"
        case visceral

        var title: String {
            switch self {
            case .none: return "None"
            case .common: return "Common"
            case .uncommon: return "Uncommon"
            case .rare: return "Rare"
            case .veryRare: return "Very rare"
            case .visceral: return "Visceral"
            }
        }

        static func < (lhs: Rarity, rhs: Rarity) -> Bool {
            allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
        }
    }

    let id: String
    let name: String
    let role: PerkInfo.Role
    let kind: Kind
    /// The killer power id, or the item type ("flashlight") for survivor add-ons.
    let parent: String
    /// The killer's name. Empty for survivor add-ons.
    let ownerName: String
    let rarity: Rarity
    let description: String
    /// The icon texture name: the label of the add-on classifier. Two add-ons can share one.
    let iconStem: String
    /// nil until the wiki icons are resolved; the UI then shows a rarity-coloured placeholder.
    let iconUrl: URL?
}

struct AddonsDocument: Codable {
    let schemaVersion: Int
    let addons: [AddonInfo]
}
