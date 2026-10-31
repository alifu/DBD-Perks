//
//  SharedFixtureTests.swift
//  DBD PerksTests
//
//  Runs the cases in Fixtures/shared/*.json. The web app's Vitest suite runs the same files
//  (DBD-Perks-Web/fixtures), so the Swift and TypeScript implementations cannot drift apart.
//

import XCTest
@testable import DBD_Perks

final class SharedFixtureTests: XCTestCase {

    private struct SearchFixture: Decodable {
        struct PerkRow: Decodable { let id, name, role, owner, description: String }
        struct AddonRow: Decodable { let id, name, ownerName, rarity, description: String }
        struct Query: Decodable {
            var text: String?
            var includeDescriptions: Bool?
            var role: String?
            var kind: String?
            var rarity: String?
            var owner: String?
        }
        struct Case: Decodable { let name: String; let query: Query; let expected: [String] }
        let perks: [PerkRow]
        let addons: [AddonRow]
        let cases: [Case]
    }

    private struct ResolverFixture: Decodable {
        struct Case: Decodable {
            let name: String
            let slots: [[Entry]]
            let chosen: [String?]
            let lowConfidence: [Bool]
        }
        let cases: [Case]
    }

    /// `["perk", 0.9]` as written in the JSON.
    private struct Entry: Decodable {
        let id: String
        let probability: Double
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            id = try container.decode(String.self)
            probability = try container.decode(Double.self)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "\(name).json is not in the test bundle")
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    func testCatalogSearchMatchesSharedCases() throws {
        let fixture = try load(SearchFixture.self, "catalog_search_cases")
        let perks = fixture.perks.map {
            PerkInfo(id: $0.id, name: $0.name, role: PerkInfo.Role(rawValue: $0.role)!, owner: $0.owner, iconUrl: nil,
                     description: $0.description, flavor: "", descriptionPatch: nil, wikiUrl: URL(string: "https://x.test")!)
        }
        let addons = fixture.addons.map {
            AddonInfo(id: $0.id, name: $0.name, role: .killer, kind: .power, parent: "p", ownerName: $0.ownerName,
                      rarity: AddonInfo.Rarity(rawValue: $0.rarity)!, description: $0.description, iconStem: "icon_\($0.id)", iconUrl: nil)
        }
        let search = CatalogSearch(perks: perks, addons: addons)

        for testCase in fixture.cases {
            let query = CatalogQuery(
                text: testCase.query.text ?? "",
                includeDescriptions: testCase.query.includeDescriptions ?? false,
                role: testCase.query.role.flatMap(PerkInfo.Role.init(rawValue:)),
                kind: testCase.query.kind.map { $0 == "perk" ? CatalogKind.perk : CatalogKind.addon },
                rarity: testCase.query.rarity.flatMap(AddonInfo.Rarity.init(rawValue:)),
                owner: testCase.query.owner
            )
            XCTAssertEqual(search.search(query).map(\.id), testCase.expected, testCase.name)
        }
    }

    func testLoadoutResolverMatchesSharedCases() throws {
        let fixture = try load(ResolverFixture.self, "loadout_resolver_cases")
        let resolver = LoadoutResolver(repository: BundledPerkRepository(perks: []))

        for testCase in fixture.cases {
            let slots = testCase.slots.map { $0.map { PerkCandidate(perkID: $0.id, probability: $0.probability) } }
            let results = resolver.resolve(slots)
            XCTAssertEqual(results.map { $0.chosen?.perkID }, testCase.chosen, testCase.name)
            XCTAssertEqual(results.map(\.isLowConfidence), testCase.lowConfidence, testCase.name)
        }
    }
}
