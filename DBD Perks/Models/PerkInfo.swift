//
//  PerkInfo.swift
//  DBD Perks
//

import Foundation

/// One perk from the bundled `perks.json` (produced by the crawler in dbd_perks_dataset).
struct PerkInfo: Codable, Identifiable, Equatable {
    enum Role: String, Codable {
        case survivor
        case killer
    }

    let id: String
    let name: String
    let role: Role
    /// Empty for generic (teachable) perks.
    let owner: String
    /// nil for perks newer than the wiki icons the app bundles; the card then shows the scanned crop instead.
    let iconUrl: URL?
    let description: String
    let flavor: String
    /// Set when the wiki text describes an upcoming patch rather than the live game.
    let descriptionPatch: String?
    let wikiUrl: URL
}

struct PerksDocument: Codable {
    let schemaVersion: Int
    let perks: [PerkInfo]
}
