//
//  ModelLabels.swift
//  DBD Perks
//

import CoreML

/// The perk ids the bundled classifier can recognise, read from the model's own class list.
enum ModelLabels {
    /// nil when the model cannot be loaded; callers then fall back to the full perks.json.
    static func perkIDs() -> Set<String>? {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        guard let model = try? DBDPerkClassifierV2(configuration: configuration).model,
              let labels = model.modelDescription.classLabels as? [String] else { return nil }
        return perkIDs(fromClassLabels: labels)
    }

    static func perkIDs(fromClassLabels labels: [String]) -> Set<String> {
        Set(labels).subtracting([ModelLabel.background])
    }
}
