//
//  AddonScoring.swift
//  DBD Perks
//

import UIKit
import CoreML

enum AddonScanError: LocalizedError {
    case modelMissing

    var errorDescription: String? {
        "The add-on model is not part of this build."
    }
}

/// Core ML scorer for the add-on classifier. The model is loaded by name, so builds without
/// `DBDAddonClassifierV1.mlpackage` still compile; the Add-on scan mode is then hidden.
final class CoreMLAddonScorer: SlotScoring, @unchecked Sendable {
    static let modelName = "DBDAddonClassifierV1"
    private static let inputName = "input_1"
    private static let outputName = "classLabel_probs"

    static func isModelBundled(in bundle: Bundle = .main) -> Bool {
        bundle.url(forResource: modelName, withExtension: "mlmodelc") != nil
    }

    private let model: MLModel
    private let processor: PerkImageProcessor

    init(bundle: Bundle = .main, processor: PerkImageProcessor? = nil) throws {
        guard let url = bundle.url(forResource: Self.modelName, withExtension: "mlmodelc") else {
            throw AddonScanError.modelMissing
        }
        self.model = try MLModel(contentsOf: url)
        self.processor = processor ?? PerkImageProcessor()
    }

    func labelScores(for crop: UIImage) throws -> [String: Double] {
        guard let buffer = processor.preprocess(crop) else { throw SlotScoringError.preprocessFailed }
        let input = try MLDictionaryFeatureProvider(dictionary: [Self.inputName: MLFeatureValue(pixelBuffer: buffer)])
        let output = try model.prediction(from: input)
        return output.featureValue(for: Self.outputName)?.dictionaryValue as? [String: Double] ?? [:]
    }
}
