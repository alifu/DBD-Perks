//
//  AddonCardView.swift
//  DBD Perks
//

import SwiftUI

/// One scanned add-on: the add-on(s) found, how sure the model is, and the description.
/// An icon shared by two killers' add-ons lists both.
struct AddonCardView: View {
    let result: SlotResult
    let addons: [AddonInfo]
    let crop: UIImage?
    let alternativeName: (PerkCandidate) -> String
    let onSelect: (PerkCandidate) -> Void
    var onReportWrong: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if addons.isEmpty {
                notRecognised
            } else {
                ForEach(addons) { addon in
                    CatalogCardView(entry: .addon(addon))
                }
                if let chosen = result.chosen {
                    Text(String(format: "%.0f%% match", chosen.probability * 100))
                        .font(.caption2.monospaced())
                        .foregroundStyle(result.isLowConfidence ? .orange : .secondary)
                }
            }
            if result.isLowConfidence, !result.alternatives.isEmpty {
                Menu {
                    ForEach(result.alternatives, id: \.perkID) { candidate in
                        Button("\(alternativeName(candidate)) (\(Int(candidate.probability * 100))%)") { onSelect(candidate) }
                    }
                } label: {
                    Label(result.chosen == nil ? "Pick the closest guess" : "Not right? Pick another", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote.weight(.semibold))
                }
            }
            if let onReportWrong {
                Button(action: onReportWrong) {
                    Label("Wrong? Tell me the real add-on", systemImage: "exclamationmark.bubble")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var notRecognised: some View {
        HStack(alignment: .top, spacing: 12) {
            if let crop {
                Image(uiImage: crop).resizable().scaledToFit().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Not recognised").font(.headline)
                Text("The model is not sure what this is. Frame the add-on tile inside the square, or pick the closest guess below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
