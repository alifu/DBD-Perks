//
//  CatalogSearchTests.swift
//  DBD PerksTests
//

import XCTest
@testable import DBD_Perks

final class CatalogSearchTests: XCTestCase {

    private func perk(_ id: String, _ name: String, role: PerkInfo.Role = .survivor, owner: String = "", description: String = "d") -> PerkInfo {
        PerkInfo(id: id, name: name, role: role, owner: owner, iconUrl: nil, description: description, flavor: "",
                 descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/\(id)")!)
    }

    private func addon(_ id: String, _ name: String, owner: String = "The Trapper", rarity: AddonInfo.Rarity = .rare,
                       description: String = "d") -> AddonInfo {
        AddonInfo(id: id, name: name, role: .killer, kind: .power, parent: "Item_Slasher_Beartrap", ownerName: owner,
                  rarity: rarity, description: description, iconStem: "icon_\(id)", iconUrl: nil)
    }

    private func makeSearch() -> CatalogSearch {
        CatalogSearch(perks: [
            perk("a_nurses_calling", "A Nurse's Calling", description: "See auras of healing survivors."),
            perk("nurse_extra", "Nurse Extra"),
            perk("adrenaline", "Adrenaline"),
            perk("hex_ruin", "Hex: Ruin", role: .killer, owner: "The Hag"),
        ], addons: [
            addon("honing_stone", "Honing Stone"),
            addon("ghost_nurse_bell", "Ghost Nurse Bell", owner: "The Wraith", rarity: .veryRare),
            addon("rusty", "Rusty Spring", rarity: .common, description: "Speeds up nurse healing."),
        ])
    }

    // MARK: Folding

    func testFoldingIgnoresCaseAccentsAndPunctuation() {
        XCTAssertEqual(CatalogSearch.fold("A Nurse’s  Calling!"), "a nurses calling")
        XCTAssertEqual(CatalogSearch.fold("Déjà Vu"), "deja vu")
        XCTAssertEqual(CatalogSearch.fold("Hex: Ruin"), "hex ruin")
    }

    func testApostropheNamesAreFoundWithoutTypingTheApostrophe() {
        let result = makeSearch().search(CatalogQuery(text: "nurses calling"))

        XCTAssertEqual(result.first?.id, "a_nurses_calling")
    }

    // MARK: Ranking

    func testRankingPutsPrefixBeforeWordPrefixBeforeSubstring() {
        let names = makeSearch().search(CatalogQuery(text: "nurse")).map(\.name)

        XCTAssertEqual(Array(names.prefix(3)), ["Nurse Extra", "A Nurse's Calling", "Ghost Nurse Bell"])
    }

    func testDescriptionMatchesComeLastAndOnlyWhenEnabled() {
        let search = makeSearch()

        XCTAssertFalse(search.search(CatalogQuery(text: "healing")).contains { $0.id == "rusty" })
        let withDescriptions = search.search(CatalogQuery(text: "healing", includeDescriptions: true)).map(\.id)
        XCTAssertEqual(Set(withDescriptions), ["a_nurses_calling", "rusty"])
    }

    func testEmptyQueryReturnsEverythingSortedByName() {
        let names = makeSearch().search(CatalogQuery()).map(\.name)

        XCTAssertEqual(names.count, 7)
        XCTAssertEqual(names, names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    // MARK: Filters

    func testKindFilterSeparatesPerksFromAddons() {
        let search = makeSearch()

        XCTAssertEqual(search.search(CatalogQuery(kind: .perk)).count, 4)
        XCTAssertEqual(search.search(CatalogQuery(kind: .addon)).count, 3)
    }

    func testRoleRarityAndOwnerFilters() {
        let search = makeSearch()

        XCTAssertEqual(search.search(CatalogQuery(role: .killer, kind: .perk)).map(\.id), ["hex_ruin"])
        XCTAssertEqual(search.search(CatalogQuery(rarity: .veryRare)).map(\.id), ["ghost_nurse_bell"])
        XCTAssertEqual(search.search(CatalogQuery(owner: "The Wraith")).map(\.id), ["ghost_nurse_bell"])
    }

    func testOwnersListIsSortedAndUnique() {
        XCTAssertEqual(makeSearch().owners, ["The Hag", "The Trapper", "The Wraith"])
    }

    // MARK: Performance

    func testSearchOverTheRealCatalogSizeIsFast() {
        let perks = (0..<330).map { perk("p\($0)", "Perk Number \($0)", description: String(repeating: "word ", count: 50)) }
        let addons = (0..<950).map { addon("a\($0)", "Add-on Number \($0)", description: String(repeating: "text ", count: 50)) }
        let search = CatalogSearch(perks: perks, addons: addons)

        measure {
            _ = search.search(CatalogQuery(text: "number 42", includeDescriptions: true))
        }
    }
}

final class AddonRepositoryTests: XCTestCase {

    private func addon(_ id: String, stem: String) -> AddonInfo {
        AddonInfo(id: id, name: id, role: .killer, kind: .power, parent: "", ownerName: "", rarity: .rare,
                  description: "d", iconStem: stem, iconUrl: nil)
    }

    func testLabelsResolveToEveryAddonSharingTheIcon() {
        let repository = BundledAddonRepository(addons: [addon("one", stem: "s1"), addon("two", stem: "s1"), addon("three", stem: "s2")])

        XCTAssertEqual(repository.addons(forIconStem: "s1").map(\.id), ["one", "two"])
        XCTAssertTrue(repository.addons(forIconStem: "unknown").isEmpty)
        XCTAssertEqual(repository.addon(id: "three")?.iconStem, "s2")
    }

    func testBundledJSONDecodesAndEveryAddonHasAnIconStem() throws {
        let repository = try BundledAddonRepository(bundle: Bundle(for: AddonRepositoryTests.self).bundleForApp)

        XCTAssertGreaterThan(repository.allAddons.count, 900)
        XCTAssertTrue(repository.allAddons.allSatisfy { !$0.iconStem.isEmpty && !$0.description.isEmpty })
    }
}

final class AddonIconStoreTests: XCTestCase {

    func testEveryBundledAddonHasAnIconWhenTheIconsAreInstalled() throws {
        let repository = try BundledAddonRepository(bundle: .main)
        try XCTSkipIf(AddonIconStore.image(forIconStem: "iconAddon_honingStone") == nil,
                      "Icons are git-ignored: run tools/export_addon_icons_for_app.py first")

        let missing = repository.allAddons.filter { AddonIconStore.image(forIconStem: $0.iconStem) == nil }.map(\.iconStem)

        XCTAssertEqual(missing, [])
    }

    func testEveryBundledPerkHasAnIconWhenTheIconsAreInstalled() throws {
        let perks = try BundledPerkRepository().allPerks
        try XCTSkipIf(PerkIconStore.image(forPerkID: perks[0].id) == nil,
                      "Icons are git-ignored: run tools/export_addon_icons_for_app.py --target perks first")

        let missing = perks.filter { PerkIconStore.image(forPerkID: $0.id) == nil }.map(\.id)

        XCTAssertEqual(missing, [])
    }

    func testUnknownStemHasNoIcon() {
        XCTAssertNil(AddonIconStore.image(forIconStem: "does_not_exist"))
    }
}

private extension Bundle {
    /// The unit tests are hosted in the app, so the app's resources are in `Bundle.main`.
    var bundleForApp: Bundle { .main }
}

final class ModelCatalogTests: XCTestCase {

    private func perk(_ id: String) -> PerkInfo {
        PerkInfo(id: id, name: id, role: .survivor, owner: "", iconUrl: nil, description: "d", flavor: "",
                 descriptionPatch: nil, wikiUrl: URL(string: "https://x.test/\(id)")!)
    }

    func testBackgroundIsNotAPerkLabel() {
        XCTAssertEqual(ModelLabels.perkIDs(fromClassLabels: ["__background__", "adrenaline", "ruin"]), ["adrenaline", "ruin"])
    }

    func testCatalogKeepsOnlyPerksTheModelKnows() {
        let kept = CatalogViewModel.perks(["a", "b", "c"].map(perk), knownTo: ["a", "c"])

        XCTAssertEqual(kept.map(\.id), ["a", "c"])
    }

    func testCatalogKeepsEveryPerkWhenTheModelIsUnavailable() {
        XCTAssertEqual(CatalogViewModel.perks(["a", "b"].map(perk), knownTo: nil).count, 2)
    }

    func testTheBundledModelCoversNearlyAllBundledPerks() throws {
        let labels = try XCTUnwrap(ModelLabels.perkIDs())
        let perks = try BundledPerkRepository().allPerks

        let unknown = perks.filter { !labels.contains($0.id) }

        XCTAssertGreaterThan(labels.count, 300)
        XCTAssertLessThanOrEqual(unknown.count, 3, "Only the 3 known wiki leftovers may be missing: \(unknown.map(\.id))")
    }
}
