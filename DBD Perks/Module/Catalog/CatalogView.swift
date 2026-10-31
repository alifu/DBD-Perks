//
//  CatalogView.swift
//  DBD Perks
//

import SwiftUI

/// Browse and search every perk and add-on, without scanning.
struct CatalogView: View {
    @State private var viewModel = CatalogViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.loadError {
                    ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    list
                }
            }
            .navigationTitle("Catalog")
            .searchable(text: $viewModel.typedText, prompt: "Search perks and add-ons")
            .task { await viewModel.load() }
            .task(id: viewModel.typedText) { await viewModel.applyTypedText() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { filterMenu } }
        }
    }

    private var list: some View {
        List {
            Section {
                Picker("Show", selection: kindBinding) {
                    Text("All").tag(CatalogKind?.none)
                    Text("Perks").tag(CatalogKind?.some(.perk))
                    Text("Add-ons").tag(CatalogKind?.some(.addon))
                }
                .pickerStyle(.segmented)
            }
            Section {
                ForEach(viewModel.results) { entry in
                    CatalogCardView(entry: entry)
                }
            } header: {
                Text("\(viewModel.results.count) results")
            } footer: {
                if !viewModel.scopeNote.isEmpty { Text(viewModel.scopeNote) }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.results.isEmpty {
                ContentUnavailableView.search(text: viewModel.query.text)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Role", selection: binding(\.role)) {
                Text("Any role").tag(PerkInfo.Role?.none)
                Text("Survivor").tag(PerkInfo.Role?.some(.survivor))
                Text("Killer").tag(PerkInfo.Role?.some(.killer))
            }
            Picker("Rarity (add-ons)", selection: binding(\.rarity)) {
                Text("Any rarity").tag(AddonInfo.Rarity?.none)
                ForEach(AddonInfo.Rarity.allCases.filter { $0 != .none }, id: \.self) { rarity in
                    Text(rarity.title).tag(AddonInfo.Rarity?.some(rarity))
                }
            }
            Picker("Owner", selection: binding(\.owner)) {
                Text("Anyone").tag(String?.none)
                ForEach(viewModel.owners, id: \.self) { owner in
                    Text(owner).tag(String?.some(owner))
                }
            }
            Toggle("Search descriptions", isOn: binding(\.includeDescriptions))
            if viewModel.hasActiveFilters {
                Button("Clear filters", role: .destructive) { viewModel.clearFilters() }
            }
        } label: {
            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filters")
    }

    private var kindBinding: Binding<CatalogKind?> { binding(\.kind) }

    /// Writes one field of the query and searches again.
    private func binding<Value>(_ keyPath: WritableKeyPath<CatalogQuery, Value>) -> Binding<Value> {
        Binding(get: { viewModel.query[keyPath: keyPath] },
                set: { viewModel.query[keyPath: keyPath] = $0; viewModel.refresh() })
    }
}

#Preview {
    CatalogView()
}
