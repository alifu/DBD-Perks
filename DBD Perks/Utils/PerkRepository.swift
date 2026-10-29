//
//  PerkRepository.swift
//  DBD Perks
//

import Foundation

protocol PerkRepository: Sendable {
    func perk(id: String) -> PerkInfo?
    /// The v2 model's labels are perk ids. nil when a label is not in the bundled data (e.g. a newer model).
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

    init(perks: [PerkInfo]) {
        perksByID = Dictionary(perks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    init(bundle: Bundle = .main) throws {
        let document = try Self.decode(PerksDocument.self, resource: "perks", in: bundle)
        guard document.schemaVersion == Self.supportedSchemaVersion else {
            throw PerkRepositoryError.unsupportedSchema(document.schemaVersion)
        }
        self.init(perks: document.perks)
    }

    var allPerks: [PerkInfo] { Array(perksByID.values) }

    func perk(id: String) -> PerkInfo? { perksByID[id] }

    func perkID(forModelLabel label: String) -> String? { perksByID[label] == nil ? nil : label }

    private static func decode<T: Decodable>(_ type: T.Type, resource: String, in bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw PerkRepositoryError.resourceMissing("\(resource).json")
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
