//
//  SlotScoring.swift
//  DBD Perks
//

import UIKit
import CoreML

/// The label the model uses for "this window is not a perk icon".
enum ModelLabel {
    static let background = "__background__"
}

/// Produces a probability per model label for one cropped perk icon.
protocol SlotScoring: Sendable {
    func labelScores(for crop: UIImage) throws -> [String: Double]
}

enum SlotScoringError: LocalizedError {
    case preprocessFailed

    var errorDescription: String? {
        "The photo could not be prepared for recognition."
    }
}

/// Core ML implementation. The model is loaded once and reused for every slot.
/// `MLModel.prediction` and `CIContext` rendering are thread-safe, so it can run off the main thread.
final class CoreMLPerkScorer: SlotScoring, @unchecked Sendable {
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
