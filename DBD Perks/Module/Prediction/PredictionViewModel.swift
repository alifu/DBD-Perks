//
//  PredictionViewModel.swift
//  DBD Perks
//
//  Created by Alif on 30/10/25.
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PredictionViewModel {

    private(set) var results: [SlotResult] = []
    private(set) var errorMessage: String?
    private(set) var isAnalyzing = false
    private(set) var hasAnalyzed = false
    /// Where each slot was found, in 0...1 photo coordinates. Empty when the user framed the perks with a guide.
    private(set) var regions: [CGRect] = []
    /// A picture of each slot, shown when the wiki icon has not loaded.
    private(set) var slotImages: [UIImage] = []

    @ObservationIgnored private let scorer: SlotScoring?
    /// Scores the few guide crops; averages several shifted views of each. The locator keeps the plain `scorer`.
    @ObservationIgnored private let guideScorer: SlotScoring?
    @ObservationIgnored private let repository: PerkRepository?
    @ObservationIgnored private let recorder: ScanRecorder?
    @ObservationIgnored private var lastScanID: String?

    /// Production wiring: bundled data + Core ML model. Failures are shown instead of swallowed.
    init() {
        do {
            let live = try Self.makeLiveDependencies()
            scorer = live.scorer
            guideScorer = TestTimeAugmentingScorer(base: live.scorer)
            repository = live.repository
        } catch {
            scorer = nil
            guideScorer = nil
            repository = nil
            errorMessage = error.localizedDescription
        }
#if DEBUG
        recorder = ScanRecorder.inDocuments()
#else
        recorder = nil
#endif
    }

    private static func makeLiveDependencies() throws -> (scorer: SlotScoring, repository: PerkRepository) {
        (try CoreMLPerkScorer(), try BundledPerkRepository())
    }

    init(scorer: SlotScoring, repository: PerkRepository, guideScorer: SlotScoring? = nil, recorder: ScanRecorder? = nil) {
        self.scorer = scorer
        self.guideScorer = guideScorer ?? scorer
        self.repository = repository
        self.recorder = recorder
    }

    func perk(id: String) -> PerkInfo? { repository?.perk(id: id) }

    var allPerks: [PerkInfo] { repository?.allPerks ?? [] }

    /// Debug builds only: a log exists to collect wrong answers.
    var canReportWrongPerk: Bool { recorder != nil }

    /// Guide mode: the user lined the perks up, so every crop is one slot.
    func analyze(crops: [UIImage]) {
        guard let guideScorer, let repository else { return }
        errorMessage = nil
        let resolver = LoadoutResolver(repository: repository)
        let slotCrops = Array(crops.prefix(PerkSlotLayout.maxSlots))
        do {
            let slotCandidates = try slotCrops.map { resolver.candidates(from: try guideScorer.labelScores(for: $0)) }
            results = resolver.resolve(slotCandidates)
            slotImages = slotCrops
            regions = []
            lastScanID = recorder?.recordScan(source: "guide", crops: slotCrops, results: results)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
        hasAnalyzed = true
    }

    /// Auto mode: find the perks anywhere in the photo (off the main thread), then resolve duplicates.
    func analyze(photo: UIImage) async {
        guard let scorer, let repository else { return }
        isAnalyzing = true
        errorMessage = nil
        let locator = PerkLocator(scorer: scorer, repository: repository)
        let found = await Task.detached(priority: .userInitiated) { locator.locate(in: photo) }.value

        results = LoadoutResolver(repository: repository).resolve(found.map(\.candidates))
        regions = found.map(\.region)
        slotImages = found.map { photo.cropped(toNormalizedRect: $0.region) ?? UIImage() }
        lastScanID = recorder?.recordScan(source: "auto", crops: slotImages, results: results)
        isAnalyzing = false
        hasAnalyzed = true
    }

    /// Lets the user correct a guess by picking another candidate of the same slot.
    func select(_ candidate: PerkCandidate, inSlot slot: Int) {
        results = results.map { result in
            guard result.slot == slot, result.candidates.contains(candidate) else { return result }
            return SlotResult(slot: slot, candidates: result.candidates, chosen: candidate, isLowConfidence: false)
        }
    }

    /// Files the slot's crop under the perk it really is. Returns false when logging is off or the write failed.
    @discardableResult
    func reportWrong(slot: Int, correctPerkID: String) -> Bool {
        guard let recorder, let lastScanID, let result = results.first(where: { $0.slot == slot }),
              slotImages.indices.contains(slot) else { return false }
        let correction = CorrectionRecord(scanID: lastScanID, slot: slot, correctPerkID: correctPerkID,
                                          predictedPerkID: result.chosen?.perkID, topCandidates: result.candidates)
        return recorder.saveCorrection(correction, crop: slotImages[slot])
    }
}
