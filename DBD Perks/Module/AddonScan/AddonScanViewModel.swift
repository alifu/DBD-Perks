//
//  AddonScanViewModel.swift
//  DBD Perks
//

import Foundation
import Observation
import UIKit

/// Scans one add-on crop: scores it (averaging a few shifted views), picks the best add-on, and lets the tester
/// file wrong answers for later training.
@MainActor
@Observable
final class AddonScanViewModel {
    private(set) var result: SlotResult?
    private(set) var errorMessage: String?
    private(set) var hasAnalyzed = false

    @ObservationIgnored private let scorer: SlotScoring?
    @ObservationIgnored private let resolver: AddonResolver?
    @ObservationIgnored private let recorder: ScanRecorder?
    @ObservationIgnored private var lastScanID: String?
    @ObservationIgnored private var crop: UIImage?

    init() {
        var loadedScorer: SlotScoring?
        var loadedResolver: AddonResolver?
        do {
            loadedScorer = TestTimeAugmentingScorer(base: try CoreMLAddonScorer())
            loadedResolver = AddonResolver(repository: try BundledAddonRepository())
        } catch {
            errorMessage = error.localizedDescription
        }
        scorer = loadedScorer
        resolver = loadedResolver
#if DEBUG
        recorder = ScanRecorder.inDocuments()
#else
        recorder = nil
#endif
    }

    init(scorer: SlotScoring, resolver: AddonResolver, recorder: ScanRecorder? = nil) {
        self.scorer = scorer
        self.resolver = resolver
        self.recorder = recorder
    }

    var canReportWrong: Bool { recorder != nil }

    var allAddons: [AddonInfo] { resolver?.repository.allAddons ?? [] }

    func addons(forLabel label: String) -> [AddonInfo] { resolver?.addons(forLabel: label) ?? [] }

    func analyze(crop: UIImage) {
        guard let scorer, let resolver else { return }
        errorMessage = nil
        do {
            let resolved = resolver.resolve(from: try scorer.labelScores(for: crop))
            result = resolved
            self.crop = crop
            lastScanID = recorder?.recordScan(source: "addon", crops: [crop], results: [resolved])
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
        hasAnalyzed = true
    }

    /// Lets the user switch to another candidate.
    func select(_ candidate: PerkCandidate) {
        guard let result, result.candidates.contains(candidate) else { return }
        self.result = SlotResult(slot: 0, candidates: result.candidates, chosen: candidate, isLowConfidence: false)
    }

    /// Files the crop under the add-on it really is (`corrections/addons/<icon label>/`).
    @discardableResult
    func reportWrong(correctAddon: AddonInfo) -> Bool {
        guard let recorder, let lastScanID, let crop, let result else { return false }
        let correction = CorrectionRecord(scanID: lastScanID, slot: 0, correctPerkID: correctAddon.iconStem.lowercased(),
                                          predictedPerkID: result.chosen?.perkID, topCandidates: result.candidates)
        return recorder.saveCorrection(correction, crop: crop, group: "addons")
    }
}
