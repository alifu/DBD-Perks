//
//  AddonRepository.swift
//  DBD Perks
//

import Foundation

protocol AddonRepository: Sendable {
    var allAddons: [AddonInfo] { get }
    func addon(id: String) -> AddonInfo?
    /// A model label (icon stem, any letter case) can belong to more than one add-on, e.g. the same add-on on two killers.
    func addons(forIconStem stem: String) -> [AddonInfo]
}

/// Dictionary-backed repository: O(N) to build once, O(1) per lookup.
struct BundledAddonRepository: AddonRepository {
    static let supportedSchemaVersion = 1

    let allAddons: [AddonInfo]
    private let addonsByID: [String: AddonInfo]
    private let addonsByStem: [String: [AddonInfo]]

    init(addons: [AddonInfo]) {
        allAddons = addons.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        addonsByID = Dictionary(addons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        addonsByStem = Dictionary(grouping: addons, by: { $0.iconStem.lowercased() })
    }

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "addons", withExtension: "json") else {
            throw PerkRepositoryError.resourceMissing("addons.json")
        }
        let document = try JSONDecoder().decode(AddonsDocument.self, from: Data(contentsOf: url))
        guard document.schemaVersion == Self.supportedSchemaVersion else {
            throw PerkRepositoryError.unsupportedSchema(document.schemaVersion)
        }
        self.init(addons: document.addons)
    }

    func addon(id: String) -> AddonInfo? { addonsByID[id] }

    func addons(forIconStem stem: String) -> [AddonInfo] { addonsByStem[stem.lowercased()] ?? [] }
}
