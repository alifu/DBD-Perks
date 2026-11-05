//
//  SynergyData.swift
//  DBD Perks
//

import Foundation

/// One perk or add-on with the mechanics the trainer (tools/synergy) found in its description.
struct SynergyItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case perk
        case addon
    }

    let id: String
    let kind: Kind
    let name: String
    let role: PerkInfo.Role
    /// The power or item an add-on belongs to. Empty for perks.
    let group: String
    /// Statuses this item gives out (e.g. "Exposed").
    let produces: [String]
    /// Statuses this item needs or pays off on.
    let consumes: [String]
    /// Strategies the item leans on; two items with the same theme stack.
    let themes: [String]
    let embedding: [Float]
}

struct SynergyDocument: Codable {
    let schemaVersion: Int
    let dimensions: Int
    let items: [SynergyItem]
}

enum SynergyRepositoryError: Error, Equatable {
    case resourceMissing
    case unsupportedSchema(Int)
}

struct BundledSynergyRepository {
    static let supportedSchemaVersion = 1

    let items: [SynergyItem]
    let dimensions: Int

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "synergy", withExtension: "json") else {
            throw SynergyRepositoryError.resourceMissing
        }
        let document = try JSONDecoder().decode(SynergyDocument.self, from: Data(contentsOf: url))
        guard document.schemaVersion == Self.supportedSchemaVersion else {
            throw SynergyRepositoryError.unsupportedSchema(document.schemaVersion)
        }
        items = document.items
        dimensions = document.dimensions
    }
}
