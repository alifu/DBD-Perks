//
//  SuggestViewModel.swift
//  DBD Perks
//

import Foundation
import Observation

@Observable
final class SuggestViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case perks = "Perks"
        case addons = "Add-ons"

        var id: Self { self }
        var kind: CatalogKind { self == .perks ? .perk : .addon }
    }

    static let perksPerSet = 4
    private static let maxSearchResults = 10

    var mode: Mode = .perks
    /// What the search field holds; picking a result turns it into the seed.
    var typedText = ""
    private(set) var seed: CatalogEntry?
    /// The suggested set, the seed first when there is one.
    private(set) var picks: [CatalogEntry] = []
    private(set) var reasons: [String] = []
    private(set) var searchResults: [CatalogEntry] = []
    private(set) var loadError: String?

    private var engine: SynergyEngine?
    private var search: CatalogSearch?
    private var entriesByID: [String: CatalogEntry] = [:]
    private var rng = SystemRandomNumberGenerator()

    init(synergy: BundledSynergyRepository? = try? BundledSynergyRepository(),
         perkRepository: PerkRepository? = try? BundledPerkRepository(),
         addonRepository: AddonRepository? = try? BundledAddonRepository()) {
        guard let synergy, let perkRepository, let addonRepository else {
            loadError = "The bundled suggestion data could not be loaded."
            return
        }
        let perks = perkRepository.allPerks
        let addons = addonRepository.allAddons
        engine = SynergyEngine(items: synergy.items)
        search = CatalogSearch(perks: perks, addons: addons)
        entriesByID = Dictionary(perks.map { ($0.id, CatalogEntry.perk($0)) } + addons.map { ($0.id, CatalogEntry.addon($0)) },
                                 uniquingKeysWith: { first, _ in first })
        shuffle()
    }

    var isSearching: Bool { !typedText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// A fresh suggestion: random, or built around the seed.
    func shuffle() {
        guard let engine else { return }
        var generator = rng
        defer { rng = generator }
        let suggestion: SynergySuggestion?
        switch (mode, seed) {
        case (.perks, nil): suggestion = engine.randomPerkSet(count: Self.perksPerSet, using: &generator)
        case (.addons, nil): suggestion = engine.randomAddonPair(using: &generator)
        case (.perks, let seed?): suggestion = engine.completePerk(seedID: seed.id, count: Self.perksPerSet - 1, using: &generator)
        case (.addons, let seed?): suggestion = engine.completeAddon(seedID: seed.id, using: &generator)
        }
        picks = suggestion?.items.compactMap { entriesByID[$0.id] } ?? []
        reasons = suggestion?.reasons ?? []
    }

    func modeChanged() {
        seed = nil
        typedText = ""
        searchResults = []
        shuffle()
    }

    func updateSearch() {
        guard isSearching, let search else {
            searchResults = []
            return
        }
        let query = CatalogQuery(text: typedText, kind: mode.kind)
        searchResults = Array(search.search(query).prefix(Self.maxSearchResults))
    }

    func select(_ entry: CatalogEntry) {
        seed = entry
        typedText = ""
        searchResults = []
        shuffle()
    }

    func clearSeed() {
        seed = nil
        shuffle()
    }
}
