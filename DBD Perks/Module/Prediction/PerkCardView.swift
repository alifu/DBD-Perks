//
//  PerkCardView.swift
//  DBD Perks
//

import SwiftUI
import NukeUI

struct PerkCardView: View {
    let result: SlotResult
    let perk: PerkInfo?
    let crop: UIImage?
    let alternativeName: (PerkCandidate) -> String
    let onSelect: (PerkCandidate) -> Void

    private let iconSize: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 4) {
                    Text(perk?.name ?? "Unknown perk")
                        .font(.headline)
                    if let perk {
                        Text(subtitle(for: perk))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let chosen = result.chosen {
                        Text(String(format: "%.0f%% match", chosen.probability * 100))
                            .font(.caption2.monospaced())
                            .foregroundStyle(result.isLowConfidence ? .orange : .secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if let perk {
                Text(perk.description)
                    .font(.callout)
                if !perk.flavor.isEmpty {
                    Text(perk.flavor)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                if let patch = perk.descriptionPatch {
                    Label("Describes upcoming patch \(patch)", systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No matching perk found for this slot. Try framing the icon inside the diamond.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if result.isLowConfidence, !result.alternatives.isEmpty {
                Menu {
                    ForEach(result.alternatives, id: \.perkID) { candidate in
                        Button("\(alternativeName(candidate)) (\(Int(candidate.probability * 100))%)") {
                            onSelect(candidate)
                        }
                    }
                } label: {
                    Label("Not right? Pick another", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        Group {
            if let perk {
                LazyImage(url: perk.iconUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        cropFallback
                    }
                }
            } else {
                cropFallback
            }
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var cropFallback: some View {
        if let crop {
            Image(uiImage: crop).resizable().scaledToFit()
        } else {
            Color.gray.opacity(0.3)
        }
    }

    private func subtitle(for perk: PerkInfo) -> String {
        let role = perk.role.rawValue.capitalized
        return perk.owner.isEmpty ? "\(role) · Generic" : "\(role) · \(perk.owner)"
    }
}
