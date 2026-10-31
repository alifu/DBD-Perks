//
//  CatalogViewModel.swift
//  DBD Perks
//

import Foundation
import Observation

@Observable
final class CatalogViewModel {
    private static let debounce: Duration = .milliseconds(150)

    var query = CatalogQuery()
    /// What the search field currently holds; copied into `query.text` after a short pause.
    var typedText = ""
    private(set) var results: [CatalogEntry] = []
    private(set) var owners: [String] = []
    private(set) var loadError: String?
    /// Says which perks are listed, e.g. "Perks the model recognises: 321 of 324".
    private(set) var scopeNote = ""
    private var search: CatalogSearch?
    private let perkRepository: PerkRepository?
    private let addonRepository: AddonRepository?
    private let modelPerkIDs: @Sendable () -> Set<String>?

    init(perkRepository: PerkRepository? = try? BundledPerkRepository(),
         addonRepository: AddonRepository? = try? BundledAddonRepository(),
         modelPerkIDs: @escaping @Sendable () -> Set<String>? = { ModelLabels.perkIDs() }) {
        self.perkRepository = perkRepository
        self.addonRepository = addonRepository
        self.modelPerkIDs = modelPerkIDs
        if perkRepository == nil || addonRepository == nil {
            loadError = "The bundled perk and add-on data could not be loaded."
        }
    }

    /// Lists only the perks the classifier knows. Loading the model takes a moment, so it runs off the main thread.
    func load() async {
        guard search == nil, let perkRepository, let addonRepository else { return }
        let readModelPerkIDs = modelPerkIDs
        let known = await Task.detached { readModelPerkIDs() }.value
        let all = perkRepository.allPerks
        let perks = Self.perks(all, knownTo: known)
        scopeNote = known == nil ? "" : "Perks the model recognises: \(perks.count) of \(all.count)"
        let search = CatalogSearch(perks: perks, addons: addonRepository.allAddons)
        self.search = search
        owners = search.owners
        refresh()
    }

    /// Perks whose id is a model label. With no model information (nil) every perk is kept.
    static func perks(_ perks: [PerkInfo], knownTo labels: Set<String>?) -> [PerkInfo] {
        labels.map { known in perks.filter { known.contains($0.id) } } ?? perks
    }

    /// Waits for a pause in typing, then searches. Called from `.task(id:)`, which cancels the previous wait.
    func applyTypedText() async {
        try? await Task.sleep(for: Self.debounce)
        guard !Task.isCancelled else { return }
        query.text = typedText
        refresh()
    }

    func refresh() {
        results = search?.search(query) ?? []
    }

    var hasActiveFilters: Bool {
        query.role != nil || query.rarity != nil || query.owner != nil || query.includeDescriptions
    }

    func clearFilters() {
        query.role = nil
        query.rarity = nil
        query.owner = nil
        query.includeDescriptions = false
        refresh()
    }
}
