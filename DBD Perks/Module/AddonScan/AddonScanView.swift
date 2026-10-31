//
//  AddonScanView.swift
//  DBD Perks
//

import SwiftUI

/// Result sheet for the Add-on guide: the add-on found in the framed crop, with its description.
struct AddonScanView: View {
    let crop: UIImage?
    @State private var viewModel = AddonScanViewModel()
    @State private var isReporting = false
    @State private var savedMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content
                Text("Add-on data and icons: game data. Icons belong to Behaviour Interactive. Educational use only.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .task { if let crop { viewModel.analyze(crop: crop) } }
        .sheet(isPresented: $isReporting) {
            AddonCorrectionPickerView(addons: viewModel.allAddons) { addon in
                savedMessage = viewModel.reportWrong(correctAddon: addon) ? "Saved as \(addon.name)" : "Could not save"
                isReporting = false
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
        } else if let result = viewModel.result {
            AddonCardView(
                result: result,
                addons: result.chosen.map { viewModel.addons(forLabel: $0.perkID) } ?? [],
                crop: crop,
                alternativeName: { viewModel.addons(forLabel: $0.perkID).map(\.name).joined(separator: " / ") },
                onSelect: viewModel.select,
                onReportWrong: viewModel.canReportWrong ? { isReporting = true } : nil
            )
        } else {
            ProgressView().padding(.vertical, 24)
        }
    }
}

/// Debug builds only: a searchable list of every add-on, to say which one a crop really shows.
struct AddonCorrectionPickerView: View {
    let addons: [AddonInfo]
    let onPick: (AddonInfo) -> Void
    @State private var query = ""

    private var matches: [AddonInfo] {
        let needle = CatalogSearch.fold(query)
        return needle.isEmpty ? addons : addons.filter { CatalogSearch.fold($0.name).contains(needle) }
    }

    var body: some View {
        NavigationStack {
            List(matches) { addon in
                Button { onPick(addon) } label: {
                    HStack(spacing: 12) {
                        CatalogCardView(entry: .addon(addon), showsDescription: false)
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Which add-on is it?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
