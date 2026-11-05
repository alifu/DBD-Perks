//
//  PredictionView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import SwiftUI
import NukeUI

struct PredictionView: View {

    /// The whole photo (auto mode). Ignored when `guideCrops` are given.
    let photo: UIImage?
    let guideCrops: [UIImage]
    @State private var viewModel = PredictionViewModel()
    @State private var reportingSlot: Int?
    @State private var savedMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content
                Text("Perk data and icons: Dead by Daylight Wiki (CC BY-SA 3.0). Icons belong to Behaviour Interactive. Educational use only.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .task { await analyze() }
        .sheet(item: $reportingSlot) { slot in
            CorrectionPickerView(perks: viewModel.allPerks) { perk in
                let saved = viewModel.reportWrong(slot: slot, correctPerkID: perk.id)
                savedMessage = saved ? "Saved as \(perk.name)" : "Could not save"
                reportingSlot = nil
            }
        }
        .overlay(alignment: .bottom) {
            if let savedMessage {
                Text(savedMessage)
                    .font(.footnote.weight(.semibold))
                    .padding(10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        self.savedMessage = nil
                    }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.callout)
        } else if viewModel.isAnalyzing {
            ProgressView("Looking for perks…")
                .padding(.vertical, 24)
        } else if viewModel.hasAnalyzed && viewModel.results.isEmpty {
            Text("No perks found. Move closer so the icons are sharp, or switch to Diamond/Row and line them up.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            if let photo, !viewModel.regions.isEmpty {
                AnnotatedPhotoView(photo: photo, regions: viewModel.regions)
            }
            ForEach(viewModel.results) { result in
                PerkCardView(
                    result: result,
                    perk: result.chosen.flatMap { viewModel.perk(id: $0.perkID) },
                    crop: viewModel.slotImages.indices.contains(result.slot) ? viewModel.slotImages[result.slot] : nil,
                    alternativeName: { viewModel.perk(id: $0.perkID)?.name ?? $0.perkID },
                    onSelect: { viewModel.select($0, inSlot: result.slot) },
                    onReportWrong: viewModel.canReportWrongPerk ? { reportingSlot = result.slot } : nil
                )
            }
        }
    }

    private func analyze() async {
        if !guideCrops.isEmpty {
            await viewModel.analyze(crops: guideCrops)
        } else if let photo {
            await viewModel.analyze(photo: photo)
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

/// Debug builds only: a searchable list of every perk, to say which one a crop really shows.
struct CorrectionPickerView: View {
    let perks: [PerkInfo]
    let onPick: (PerkInfo) -> Void
    @State private var query = ""

    private var matches: [PerkInfo] {
        query.isEmpty ? perks : perks.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(matches, id: \.id) { perk in
                Button { onPick(perk) } label: {
                    HStack(spacing: 12) {
                        Group {
                            if let bundled = PerkIconStore.image(forPerkID: perk.id) {
                                Image(uiImage: bundled).resizable().scaledToFit()
                            } else {
                                LazyImage(url: perk.iconUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFit()
                                    } else {
                                        Color.gray.opacity(0.2)
                                    }
                                }
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(perk.name).foregroundStyle(.primary)
                            Text(perk.owner.isEmpty ? perk.role.rawValue.capitalized : "\(perk.role.rawValue.capitalized) · \(perk.owner)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Which perk is it?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The photo with a numbered outline on every perk that was found, so cards can be matched to icons.
struct AnnotatedPhotoView: View {
    let photo: UIImage
    let regions: [CGRect]

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 240)
            .overlay {
                GeometryReader { geometry in
                    ForEach(regions.indices, id: \.self) { index in
                        let region = regions[index]
                        ZStack {
                            DiamondShape().stroke(Color.yellow, lineWidth: 2)
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .padding(3)
                                .background(.black.opacity(0.7), in: Circle())
                                .foregroundStyle(.yellow)
                                .offset(y: -region.height * geometry.size.height / 2 - 8)
                        }
                        .frame(width: region.width * geometry.size.width, height: region.height * geometry.size.height)
                        .position(x: region.midX * geometry.size.width, y: region.midY * geometry.size.height)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Photo with \(regions.count) detected perks")
    }
}

#Preview {
    PredictionView(photo: UIImage(named: "hex-no-one-escapes-death"), guideCrops: [])
}
