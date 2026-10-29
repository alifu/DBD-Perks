//
//  PredictionView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import SwiftUI

struct PredictionView: View {

    let crops: [UIImage]
    @State private var viewModel = PredictionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                } else if crops.isEmpty {
                    Text("No image captured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.results) { result in
                        PerkCardView(
                            result: result,
                            perk: result.chosen.flatMap { viewModel.perk(id: $0.perkID) },
                            crop: crops.indices.contains(result.slot) ? crops[result.slot] : nil,
                            alternativeName: { viewModel.perk(id: $0.perkID)?.name ?? $0.perkID },
                            onSelect: { viewModel.select($0, inSlot: result.slot) }
                        )
                    }
                }

                Text("Perk data and icons: Dead by Daylight Wiki (CC BY-SA 3.0). Icons belong to Behaviour Interactive. Educational use only.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .onAppear { viewModel.analyze(crops: crops) }
    }
}

#Preview {
    PredictionView(crops: [UIImage(named: "hex-no-one-escapes-death")].compactMap { $0 })
}
