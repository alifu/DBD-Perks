//
//  SlotScoring.swift
//  DBD Perks
//

import UIKit
import CoreML

/// Produces a probability per model label for one cropped perk icon.
@MainActor
protocol SlotScoring {
    func labelScores(for crop: UIImage) throws -> [String: Double]
}

enum SlotScoringError: LocalizedError {
    case preprocessFailed

    var errorDescription: String? {
        "The photo could not be prepared for recognition."
    }
}

/// Core ML implementation. The model is loaded once and reused for every slot.
@MainActor
final class CoreMLPerkScorer: SlotScoring {
    private let model: DBDPerkClassifierV2
    private let processor: PerkImageProcessor

    init(processor: PerkImageProcessor? = nil) throws {
        self.model = try DBDPerkClassifierV2(configuration: MLModelConfiguration())
        self.processor = processor ?? PerkImageProcessor()
    }

    func labelScores(for crop: UIImage) throws -> [String: Double] {
        guard let buffer = processor.preprocess(crop) else { throw SlotScoringError.preprocessFailed }
        return try model.prediction(input_1: buffer).classLabel_probs
    }
}
