//
//  SuggestView.swift
//  DBD Perks
//

import SwiftUI

/// Perk and add-on combinations that support each other, worked out on the device from the bundled data.
struct SuggestView: View {
    @State private var viewModel = SuggestViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.loadError {
                    ContentUnavailableView("Suggestions unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if viewModel.isSearching {
                    searchResults
                } else {
                    suggestion
                }
            }
            .navigationTitle("Suggest")
            .searchable(text: $viewModel.typedText, prompt: viewModel.mode == .perks ? "Pick a perk to build around" : "Pick an add-on to build around")
            .onChange(of: viewModel.typedText) { viewModel.updateSearch() }
            .onChange(of: viewModel.mode) { viewModel.modeChanged() }
        }
    }

    private var searchResults: some View {
        List(viewModel.searchResults) { entry in
            Button { viewModel.select(entry) } label: { CatalogCardView(entry: entry, showsDescription: false) }
                .buttonStyle(.plain)
        }
        .overlay {
            if viewModel.searchResults.isEmpty { ContentUnavailableView.search(text: viewModel.typedText) }
        }
    }

    private var suggestion: some View {
        List {
            Section {
                Picker("Suggest", selection: $viewModel.mode) {
                    ForEach(SuggestViewModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            if let seed = viewModel.seed {
                Section {
                    Button("Stop building around \(seed.name)", systemImage: "xmark.circle") { viewModel.clearSeed() }
                }
            }
            if viewModel.picks.isEmpty {
                ContentUnavailableView("No match found", systemImage: "sparkles",
                                       description: Text("Nothing pairs with this one yet. Try another pick."))
            } else {
                Section {
                    ForEach(viewModel.picks) { entry in
                        CatalogCardView(entry: entry)
                            .listRowBackground(entry.id == viewModel.seed?.id ? Color.accentColor.opacity(0.15) : nil)
                    }
                } header: {
                    Text(viewModel.seed == nil ? "Random suggestion" : "Built around \(viewModel.seed?.name ?? "")")
                }
                Section("Why they work together") {
                    if viewModel.reasons.isEmpty {
                        Text("No direct link between them; these only share a general theme.").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.reasons, id: \.self) { Label($0, systemImage: "link") }
                }
            }
            Section {
                Button { viewModel.shuffle() } label: {
                    Label("Shuffle", systemImage: "dice").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            } footer: {
                Text("Suggestions are worked out on this device from perk and add-on descriptions. No internet needed.")
            }
        }
    }
}

#Preview {
    SuggestView()
}
