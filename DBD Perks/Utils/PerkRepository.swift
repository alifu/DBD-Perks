//
//  PerkRepository.swift
//  DBD Perks
//

import Foundation

protocol PerkRepository {
    func perk(id: String) -> PerkInfo?
    /// nil when the model label is stale (the perk no longer exists in the wiki data).
    func perkID(forModelLabel label: String) -> String?
}

enum PerkRepositoryError: Error, Equatable {
    case resourceMissing(String)
    case unsupportedSchema(Int)
}

/// Dictionary-backed repository: O(N) to build once, O(1) per lookup.
struct BundledPerkRepository: PerkRepository {
    static let supportedSchemaVersion = 1

    private let perksByID: [String: PerkInfo]
    private let idByModelLabel: [String: String]

    init(perks: [PerkInfo], modelLabelMap: [String: String]) {
        let byID = Dictionary(perks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.perksByID = byID
        self.idByModelLabel = modelLabelMap.filter { byID[$0.value] != nil }
    }

    init(bundle: Bundle = .main) throws {
        let document = try Self.decode(PerksDocument.self, resource: "perks", in: bundle)
        guard document.schemaVersion == Self.supportedSchemaVersion else {
            throw PerkRepositoryError.unsupportedSchema(document.schemaVersion)
        }
        let labels = try Self.decode(LegacyLabelMap.self, resource: "legacy_label_map", in: bundle)
        self.init(perks: document.perks, modelLabelMap: labels.map)
    }

    var allPerks: [PerkInfo] { Array(perksByID.values) }

    func perk(id: String) -> PerkInfo? { perksByID[id] }

    func perkID(forModelLabel label: String) -> String? { idByModelLabel[label] }

    private static func decode<T: Decodable>(_ type: T.Type, resource: String, in bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw PerkRepositoryError.resourceMissing("\(resource).json")
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
