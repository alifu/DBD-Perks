//
//  SynergyEngineTests.swift
//  DBD PerksTests
//

import XCTest
@testable import DBD_Perks

final class SynergyEngineTests: XCTestCase {

    private func item(_ id: String, kind: SynergyItem.Kind = .perk, role: PerkInfo.Role = .killer, group: String = "",
                      produces: [String] = [], consumes: [String] = [], themes: [String] = [],
                      embedding: [Float] = [1, 0]) -> SynergyItem {
        SynergyItem(id: id, kind: kind, name: id, role: role, group: group, produces: produces,
                    consumes: consumes, themes: themes, embedding: embedding)
    }

    private lazy var engine = SynergyEngine(items: [
        item("exposer", produces: ["Exposed"], embedding: [1, 0]),
        item("exploiter", consumes: ["Exposed"], embedding: [0, 1]),
        item("unrelated", themes: ["Healing"], embedding: [-1, 0]),
        item("twin", produces: ["Exposed"], embedding: [1, 0]),
        item("surv_a", role: .survivor, produces: ["Haste"]),
        item("surv_b", role: .survivor, consumes: ["Haste"], embedding: [0, 1]),
        item("addon_a", kind: .addon, group: "Trap", produces: ["Hindered"]),
        item("addon_b", kind: .addon, group: "Trap", consumes: ["Hindered"], embedding: [0, 1]),
        item("addon_c", kind: .addon, group: "Trap", themes: ["Healing"], embedding: [0, -1]),
        item("addon_other", kind: .addon, group: "Bell", consumes: ["Hindered"], embedding: [0, 1]),
    ])

    func testProducerAndConsumerOutscoreUnrelatedPair() {
        let linked = engine.pairScore(engine.item("exposer")!, engine.item("exploiter")!)
        let unrelated = engine.pairScore(engine.item("exposer")!, engine.item("unrelated")!)
        XCTAssertGreaterThan(linked.score, unrelated.score)
        XCTAssertEqual(linked.reasons.first, "exposer applies Exposed, which exploiter uses")
    }

    func testIdenticalItemsAreRedundantNotSynergistic() {
        let twins = engine.pairScore(engine.item("exposer")!, engine.item("twin")!)
        let linked = engine.pairScore(engine.item("exposer")!, engine.item("exploiter")!)
        XCTAssertLessThan(twins.score, linked.score)
    }

    func testCompletingAPerkKeepsRoleAndExcludesTheSeed() {
        var rng = SeededGenerator(seed: 1)
        let suggestion = engine.completePerk(seedID: "exposer", count: 2, using: &rng)
        XCTAssertEqual(suggestion?.items.first?.id, "exposer")
        XCTAssertEqual(suggestion?.items.count, 3)
        XCTAssertEqual(Set(suggestion?.items.map(\.id) ?? []).count, 3)
        XCTAssertTrue(suggestion?.items.allSatisfy { $0.role == .killer && $0.kind == .perk } ?? false)
    }

    func testCompletingPerkPrefersItsConsumer() {
        var rng = SeededGenerator(seed: 3)
        let suggestion = engine.completePerk(seedID: "exposer", count: 1, using: &rng)
        XCTAssertEqual(suggestion?.items.last?.id, "exploiter")
    }

    func testAddonPairsShareOneParent() {
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let pair = engine.randomAddonPair(using: &rng)
            XCTAssertEqual(pair?.items.count, 2)
            XCTAssertEqual(Set(pair?.items.map(\.group) ?? []).count, 1)
            XCTAssertNotEqual(pair?.items.first?.id, pair?.items.last?.id)
        }
    }

    func testCompletingAnAddonStaysOnTheSameParent() {
        var rng = SeededGenerator(seed: 5)
        let suggestion = engine.completeAddon(seedID: "addon_a", using: &rng)
        XCTAssertEqual(suggestion?.items.last?.id, "addon_b")
        XCTAssertEqual(suggestion?.items.last?.group, "Trap")
    }

    func testRandomPerkSetHasNoDuplicatesAndOneRole() {
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let set = engine.randomPerkSet(count: 2, using: &rng)
            XCTAssertEqual(set?.items.count, 2)
            XCTAssertEqual(Set(set?.items.map(\.role) ?? []).count, 1)
            XCTAssertEqual(Set(set?.items.map(\.id) ?? []).count, 2)
        }
    }

    func testSameSeedGivesSameSuggestion() {
        var first = SeededGenerator(seed: 9), second = SeededGenerator(seed: 9)
        XCTAssertEqual(engine.randomPerkSet(count: 2, using: &first)?.items.map(\.id),
                       engine.randomPerkSet(count: 2, using: &second)?.items.map(\.id))
    }

    func testUnknownSeedOrTooSmallPoolGivesNil() {
        var rng = SeededGenerator(seed: 1)
        XCTAssertNil(engine.completePerk(seedID: "nope", count: 3, using: &rng))
        XCTAssertNil(engine.completePerk(seedID: "surv_a", count: 3, using: &rng))
        XCTAssertNil(engine.completeAddon(seedID: "addon_other", using: &rng))
    }

    func testDecodesTheBundledData() throws {
        let data = try BundledSynergyRepository(bundle: Bundle(for: CoreMLPerkScorer.self))
        XCTAssertGreaterThan(data.items.count, 1000)
        XCTAssertTrue(data.items.allSatisfy { $0.embedding.count == data.dimensions })
    }

    func testEveryBundledPerkAndAddonCanBeCompleted() throws {
        let data = try BundledSynergyRepository(bundle: Bundle(for: CoreMLPerkScorer.self))
        let real = SynergyEngine(items: data.items)
        var rng = SeededGenerator(seed: 42)
        for seed in data.items {
            switch seed.kind {
            case .perk:
                let set = real.completePerk(seedID: seed.id, count: 3, using: &rng)
                XCTAssertEqual(set?.items.count, 4, seed.name)
                XCTAssertTrue(set?.items.allSatisfy { $0.role == seed.role } ?? false, seed.name)
            case .addon:
                guard let pair = real.completeAddon(seedID: seed.id, using: &rng) else { continue }
                XCTAssertEqual(pair.items.map(\.group), [seed.group, seed.group], seed.name)
            }
        }
    }
}
